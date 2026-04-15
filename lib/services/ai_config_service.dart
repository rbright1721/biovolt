import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ai_service.dart';

/// Current AI configuration state.
class AiConfig {
  final String? provider;
  final String? model;
  final bool hasKey;
  final bool keyTested;

  const AiConfig({
    this.provider,
    this.model,
    this.hasKey = false,
    this.keyTested = false,
  });
}

/// Service for managing AI provider settings in the UI.
class AiConfigService {
  final AiService _aiService;
  final FlutterSecureStorage _secureStorage;

  bool _keyTested = false;

  AiConfigService({
    required AiService aiService,
    FlutterSecureStorage? secureStorage,
  })  : _aiService = aiService,
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Returns the current AI configuration.
  Future<AiConfig> getConfig() async {
    final provider = await _aiService.getProvider();
    final hasKey = await _aiService.hasValidKey();

    String? model;
    if (provider == 'anthropic') {
      model = 'claude-sonnet-4-6';
    } else if (provider == 'openai') {
      model = 'gpt-4o';
    }

    return AiConfig(
      provider: provider,
      model: model,
      hasKey: hasKey,
      keyTested: _keyTested,
    );
  }

  /// Set the AI provider ('anthropic' or 'openai').
  Future<void> setProvider(String provider) async {
    await _secureStorage.write(key: 'ai_provider', value: provider);
    _keyTested = false;
  }

  /// Set the API key — validates format via [AiService.saveApiKey].
  Future<void> setApiKey(String key) async {
    final provider = await _aiService.getProvider() ?? 'anthropic';
    await _aiService.saveApiKey(provider, key);
    _keyTested = false;
  }

  /// Clear the stored API key.
  Future<void> clearKey() async {
    await _aiService.clearKey();
    _keyTested = false;
  }

  /// Make a minimal API call to verify the stored key works.
  ///
  /// Sends "Say OK" with max_tokens=5. Returns true if the API responds
  /// with a 200 status.
  Future<bool> testKey() async {
    try {
      final result = await _aiService.quickCoach(
        'Say OK',
        systemPrompt: 'Respond with only the word OK.',
      );
      _keyTested = result.isNotEmpty;
      return _keyTested;
    } on AiAuthException {
      _keyTested = false;
      return false;
    } catch (_) {
      _keyTested = false;
      return false;
    }
  }
}
