import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/ai_analysis.dart';
import 'storage_service.dart';

// ---------------------------------------------------------------------------
// Exceptions
// ---------------------------------------------------------------------------

class AiAuthException implements Exception {
  final String message;
  AiAuthException([this.message = 'Invalid or expired API key']);
  @override
  String toString() => 'AiAuthException: $message';
}

class AiRateLimitException implements Exception {
  final String message;
  AiRateLimitException([this.message = 'API rate limit exceeded']);
  @override
  String toString() => 'AiRateLimitException: $message';
}

class AiTimeoutException implements Exception {
  final String message;
  AiTimeoutException([this.message = 'API request timed out']);
  @override
  String toString() => 'AiTimeoutException: $message';
}

// ---------------------------------------------------------------------------
// AiService — BYOK (Bring Your Own Key) AI analysis
// ---------------------------------------------------------------------------

class AiService {
  static const _claudeUrl = 'https://api.anthropic.com/v1/messages';
  static const _openAiUrl = 'https://api.openai.com/v1/chat/completions';

  static const _keyProvider = 'ai_provider';
  static const _keyApiKey = 'ai_api_key';

  static const _claudeModel = 'claude-sonnet-4-6';
  static const _openAiModel = 'gpt-4o';

  final FlutterSecureStorage _secureStorage;
  final http.Client _http;

  AiService({
    FlutterSecureStorage? secureStorage,
    http.Client? httpClient,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _http = httpClient ?? http.Client();

  // ---------------------------------------------------------------------------
  // Key management
  // ---------------------------------------------------------------------------

  /// Validate and store an API key.
  ///
  /// Claude keys start with `sk-ant-`, OpenAI keys start with `sk-`.
  Future<void> saveApiKey(String provider, String key) async {
    if (provider == 'anthropic') {
      if (!key.startsWith('sk-ant-')) {
        throw AiAuthException(
            'Invalid Claude key format — must start with sk-ant-');
      }
    } else if (provider == 'openai') {
      if (!key.startsWith('sk-')) {
        throw AiAuthException(
            'Invalid OpenAI key format — must start with sk-');
      }
    } else {
      throw AiAuthException('Unknown provider: $provider');
    }

    await _secureStorage.write(key: _keyProvider, value: provider);
    await _secureStorage.write(key: _keyApiKey, value: key);
  }

  /// Returns true if a valid API key is stored.
  Future<bool> hasValidKey() async {
    final key = await _secureStorage.read(key: _keyApiKey);
    return key != null && key.isNotEmpty;
  }

  /// Returns the stored provider string ('anthropic' or 'openai'), or null.
  Future<String?> getProvider() async {
    return _secureStorage.read(key: _keyProvider);
  }

  /// Returns the model name for the stored provider.
  Future<String> _getModel() async {
    final provider = await getProvider();
    return provider == 'openai' ? _openAiModel : _claudeModel;
  }

  /// Clear stored key and provider.
  Future<void> clearKey() async {
    await _secureStorage.delete(key: _keyApiKey);
    await _secureStorage.delete(key: _keyProvider);
  }

  // ---------------------------------------------------------------------------
  // Core API calls
  // ---------------------------------------------------------------------------

  /// Full post-session analysis. Calls the AI, parses structured JSON response
  /// into [AiAnalysis], saves to [StorageService], and returns it.
  Future<AiAnalysis> analyzeSession(String sessionId, String prompt,
      {required String systemPrompt, bool ouraContextUsed = false}) async {
    final provider = await getProvider();
    final model = await _getModel();
    final responseText = await _callApi(
      systemPrompt: systemPrompt,
      userPrompt: prompt,
      maxTokens: 2000,
    );

    try {
      final parsed = _parseAnalysisJson(responseText);
      final analysis = AiAnalysis(
        sessionId: sessionId,
        generatedAt: DateTime.now(),
        provider: provider ?? 'unknown',
        model: model,
        promptVersion: '1.0.0',
        insights: _toStringList(parsed['insights']),
        anomalies: _toStringList(parsed['anomalies']),
        correlationsDetected: _toStringList(parsed['correlations_detected']),
        protocolRecommendations:
            _toStringList(parsed['protocol_recommendations']),
        flags: _toStringList(parsed['flags']),
        trendSummary: parsed['trend_summary'] as String?,
        confidence:
            (parsed['confidence'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.5,
        ouraContextUsed: ouraContextUsed,
      );

      await StorageService().saveAiAnalysis(analysis);
      return analysis;
    } catch (_) {
      // Parse failure — return partial AiAnalysis with raw text
      final analysis = AiAnalysis(
        sessionId: sessionId,
        generatedAt: DateTime.now(),
        provider: provider ?? 'unknown',
        model: model,
        promptVersion: '1.0.0',
        insights: const [],
        anomalies: const [],
        correlationsDetected: const [],
        protocolRecommendations: const [],
        flags: ['AI response could not be parsed as structured JSON'],
        trendSummary: responseText,
        confidence: 0.0,
        ouraContextUsed: ouraContextUsed,
      );

      await StorageService().saveAiAnalysis(analysis);
      return analysis;
    }
  }

  /// Lightweight real-time coaching call. Returns a single sentence.
  /// Timeout: 8 seconds.
  Future<String> quickCoach(String prompt,
      {required String systemPrompt}) async {
    return _callApi(
      systemPrompt: systemPrompt,
      userPrompt: prompt,
      maxTokens: 150,
      timeout: const Duration(seconds: 8),
    );
  }

  /// Streaming version of [analyzeSession]. Yields text chunks as they
  /// arrive from the API.
  Stream<String> analyzeSessionStreaming(String sessionId, String prompt,
      {required String systemPrompt}) async* {
    final provider = await getProvider();
    final key = await _secureStorage.read(key: _keyApiKey);
    if (key == null || key.isEmpty) throw AiAuthException('No API key stored');

    final isClaude = provider == 'anthropic';

    final uri = Uri.parse(isClaude ? _claudeUrl : _openAiUrl);
    final headers = isClaude
        ? {
            'x-api-key': key,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          }
        : {
            'Authorization': 'Bearer $key',
            'content-type': 'application/json',
          };

    final body = isClaude
        ? jsonEncode({
            'model': _claudeModel,
            'max_tokens': 2000,
            'system': systemPrompt,
            'messages': [
              {'role': 'user', 'content': prompt}
            ],
            'stream': true,
          })
        : jsonEncode({
            'model': _openAiModel,
            'max_tokens': 2000,
            'stream': true,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': prompt},
            ],
          });

    final request = http.Request('POST', uri)
      ..headers.addAll(headers)
      ..body = body;

    final streamedResponse = await _http.send(request);

    if (streamedResponse.statusCode == 401) throw AiAuthException();
    if (streamedResponse.statusCode == 429) throw AiRateLimitException();
    if (streamedResponse.statusCode != 200) {
      throw Exception('AI API error: ${streamedResponse.statusCode}');
    }

    // Parse SSE stream
    await for (final chunk
        in streamedResponse.stream.transform(utf8.decoder)) {
      for (final line in chunk.split('\n')) {
        if (!line.startsWith('data: ')) continue;
        final data = line.substring(6).trim();
        if (data == '[DONE]') return;

        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final text = isClaude
              ? _extractClaudeStreamDelta(json)
              : _extractOpenAiStreamDelta(json);
          if (text != null && text.isNotEmpty) yield text;
        } catch (_) {
          // Skip malformed SSE chunks
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<String> _callApi({
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 2000,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final provider = await getProvider();
    final key = await _secureStorage.read(key: _keyApiKey);
    if (key == null || key.isEmpty) throw AiAuthException('No API key stored');

    final isClaude = provider == 'anthropic';
    final uri = Uri.parse(isClaude ? _claudeUrl : _openAiUrl);

    final headers = isClaude
        ? {
            'x-api-key': key,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          }
        : {
            'Authorization': 'Bearer $key',
            'content-type': 'application/json',
          };

    final body = isClaude
        ? jsonEncode({
            'model': _claudeModel,
            'max_tokens': maxTokens,
            'system': systemPrompt,
            'messages': [
              {'role': 'user', 'content': userPrompt}
            ],
            'stream': false,
          })
        : jsonEncode({
            'model': _openAiModel,
            'max_tokens': maxTokens,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userPrompt},
            ],
          });

    http.Response response;
    try {
      response = await _http
          .post(uri, headers: headers, body: body)
          .timeout(timeout);
    } on TimeoutException {
      throw AiTimeoutException();
    }

    if (response.statusCode == 401) throw AiAuthException();
    if (response.statusCode == 429) throw AiRateLimitException();
    if (response.statusCode != 200) {
      throw Exception(
          'AI API error: ${response.statusCode} ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (isClaude) {
      final content = json['content'] as List<dynamic>?;
      if (content != null && content.isNotEmpty) {
        return content.first['text'] as String? ?? '';
      }
      return '';
    } else {
      final choices = json['choices'] as List<dynamic>?;
      if (choices != null && choices.isNotEmpty) {
        return choices.first['message']?['content'] as String? ?? '';
      }
      return '';
    }
  }

  /// Parse the AI's JSON response, stripping any markdown fences.
  Map<String, dynamic> _parseAnalysisJson(String raw) {
    var text = raw.trim();
    // Strip markdown code fences if present
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      text = text.replaceFirst(RegExp(r'\s*```$'), '');
    }
    return jsonDecode(text) as Map<String, dynamic>;
  }

  List<String> _toStringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return const [];
  }

  String? _extractClaudeStreamDelta(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    if (type == 'content_block_delta') {
      return json['delta']?['text'] as String?;
    }
    return null;
  }

  String? _extractOpenAiStreamDelta(Map<String, dynamic> json) {
    final choices = json['choices'] as List<dynamic>?;
    if (choices != null && choices.isNotEmpty) {
      return choices.first['delta']?['content'] as String?;
    }
    return null;
  }
}
