import 'ai_service.dart';

/// Current AI configuration state.
class AiConfig {
  final String? provider;
  final String? model;
  final bool hasKey;
  final bool keyTested;

  const AiConfig({
    this.provider = 'anthropic',
    this.model = 'claude-sonnet-4-5',
    this.hasKey = true,
    this.keyTested = true,
  });
}

/// Service for managing AI provider settings.
/// With the Firebase proxy, keys are managed server-side.
class AiConfigService {
  final AiService _aiService;

  AiConfigService({required AiService aiService}) : _aiService = aiService;

  /// Returns the current AI configuration.
  Future<AiConfig> getConfig() async {
    final provider = await _aiService.getProvider();
    return AiConfig(provider: provider);
  }

  /// No-op — provider is fixed to 'anthropic' via the proxy.
  Future<void> setProvider(String provider) async {}

  /// No-op — keys are managed server-side.
  Future<void> setApiKey(String key) async {}

  /// No-op — keys are managed server-side.
  Future<void> clearKey() async {}

  /// Always returns true — the proxy manages keys.
  Future<bool> testKey() async => true;
}
