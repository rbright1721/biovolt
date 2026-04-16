import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';

import '../models/ai_analysis.dart';
import 'storage_service.dart';

// ---------------------------------------------------------------------------
// Exceptions
// ---------------------------------------------------------------------------

class AiAuthException implements Exception {
  final String message;
  AiAuthException([this.message = 'AI proxy authentication error']);
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
// AiService — Firebase Cloud Functions proxy (no client-side API key)
// ---------------------------------------------------------------------------

class AiService {
  static const _claudeModel = 'claude-sonnet-4-5';

  final FirebaseFunctions _functions;

  AiService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  // ---------------------------------------------------------------------------
  // Key management (retained for API compatibility — always returns true)
  // ---------------------------------------------------------------------------

  /// Always returns true — Cloud Functions manage API keys server-side.
  Future<bool> hasValidKey() async => true;

  /// Returns the provider string. Always 'anthropic' for analysis.
  Future<String?> getProvider() async => 'anthropic';

  // ---------------------------------------------------------------------------
  // Core API calls
  // ---------------------------------------------------------------------------

  /// Full post-session analysis. Calls the Cloud Function, parses structured
  /// JSON response into [AiAnalysis], saves to [StorageService], and returns it.
  Future<AiAnalysis> analyzeSession(String sessionId, String prompt,
      {required String systemPrompt, bool ouraContextUsed = false}) async {
    final responseText = await _callClaude(
      systemPrompt: systemPrompt,
      userPrompt: prompt,
      maxTokens: 2000,
    );

    try {
      final parsed = _parseAnalysisJson(responseText);
      final analysis = AiAnalysis(
        sessionId: sessionId,
        generatedAt: DateTime.now(),
        provider: 'anthropic',
        model: _claudeModel,
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
        provider: 'anthropic',
        model: _claudeModel,
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

  /// Lightweight real-time coaching call via Gemini 2.0 Flash.
  /// Returns a single sentence. Timeout: 8 seconds.
  Future<String> quickCoach(String prompt,
      {required String systemPrompt}) async {
    final geminiPayload = {
      'contents': [
        {
          'parts': [
            {'text': '$systemPrompt\n\n$prompt'}
          ]
        }
      ],
      'generationConfig': {
        'maxOutputTokens': 150,
        'temperature': 0.4,
      },
    };

    try {
      final callable = _functions.httpsCallable(
        'quickCoach',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 8)),
      );

      final result = await callable.call<Map<String, dynamic>>({
        'model': 'gemini-2.0-flash',
        'payload': geminiPayload,
      });

      final data = result.data;
      final text = ((data['candidates'] as List<dynamic>?)?.firstOrNull
              as Map<String, dynamic>?)?['content']?['parts']?[0]?['text']
          as String? ?? '';
      return text;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unauthenticated') throw AiAuthException();
      if (e.code == 'resource-exhausted') throw AiRateLimitException();
      throw Exception('quickCoach error: ${e.message}');
    } on TimeoutException {
      throw AiTimeoutException();
    }
  }

  // ---------------------------------------------------------------------------
  // Internal — Claude call via Cloud Function
  // ---------------------------------------------------------------------------

  Future<String> _callClaude({
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 2000,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'analyzeSession',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
      );

      final result = await callable.call<Map<String, dynamic>>({
        'model': _claudeModel,
        'max_tokens': maxTokens,
        'system': systemPrompt,
        'messages': [
          {'role': 'user', 'content': userPrompt}
        ],
      });

      final data = result.data;

      // Handle Anthropic errors forwarded by the function
      if (data.containsKey('error')) {
        throw Exception('AI API error: ${data['error']}');
      }

      final content = data['content'] as List<dynamic>?;
      if (content != null && content.isNotEmpty) {
        return (content.first as Map<String, dynamic>)['text'] as String? ??
            '';
      }
      return '';
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unauthenticated') throw AiAuthException();
      if (e.code == 'resource-exhausted') throw AiRateLimitException();
      throw Exception('analyzeSession error: ${e.message}');
    } on TimeoutException {
      throw AiTimeoutException();
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
}
