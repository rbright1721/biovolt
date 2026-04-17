import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'connectors/connector_esp32.dart';
import 'connectors/connector_oura.dart';
import 'connectors/connector_polar.dart';
import 'connectors/connector_registry.dart';
import 'screens/journal_screen.dart';
import 'screens/pre_session_screen.dart';
import 'services/ai_service.dart';
import 'services/background_service.dart';
import 'services/ble_service.dart';
import 'services/oura_sync_service.dart';
import 'services/prompt_builder.dart';
import 'services/session_recorder.dart';
import 'services/session_storage.dart';
import 'services/storage_service.dart';
import 'services/trend_analyst.dart';
import 'services/widget_service.dart';

/// Global navigator key so the home-screen widget's MethodChannel
/// handler can push new routes without a BuildContext.
final GlobalKey<NavigatorState> appNavigatorKey =
    GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFF0A0E17),
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0A0E17),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final storageService = StorageService();
  await storageService.init();

  // Background WorkManager for periodic home-screen widget refresh.
  // Must run after storage init so the first scheduled run has data.
  await BackgroundService.init();
  await BackgroundService.scheduleWidgetRefresh();

  // Refresh the home-screen widget on cold start (fire-and-forget).
  unawaited(WidgetService.updateWidget());

  final sessionStorage = SessionStorage(storageService);

  // Create BleService and register ESP32 connector
  final bleService = BleService();
  final registry = ConnectorRegistry.instance;
  registry.register(Esp32Connector(bleService: bleService));

  // Register Polar H10 connector
  final polarConnector = PolarConnector();
  registry.register(polarConnector);
  polarConnector.authenticate().catchError((_) {});

  // Register Oura Ring connector
  final ouraConnector = OuraConnector();
  registry.register(ouraConnector);

  // Trigger background Oura sync (non-blocking)
  final ouraSync = OuraSyncService(
    connector: ouraConnector,
    storage: storageService,
  );
  ouraConnector.authenticate().then((_) => ouraSync.syncMissingDays());

  // AI services
  final aiService = AiService();
  final promptBuilder = PromptBuilder(storage: storageService);

  // Session recorder
  final sessionRecorder = SessionRecorder(
    storage: storageService,
    aiService: aiService,
    promptBuilder: promptBuilder,
    connectorRegistry: registry,
  );

  // Trend analyst
  final trendAnalyst = TrendAnalyst(
    storage: storageService,
    aiService: aiService,
    promptBuilder: promptBuilder,
  );

  // First-launch detection
  final profile = storageService.getUserProfile();
  final firstLaunch = profile == null;

  // ── Widget action channel ──────────────────────────────────────────
  // Android MainActivity forwards widget taps here. Use the global
  // navigator key since this runs outside any widget tree.
  const widgetChannel = MethodChannel('com.biovolt.app/widget');
  widgetChannel.setMethodCallHandler((call) async {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    switch (call.method) {
      case 'openVoiceNote':
        navigator.push(MaterialPageRoute(
          builder: (_) => JournalScreen(
            bleService: bleService,
            autoStartVoice: true,
          ),
        ));
        break;
      case 'openSessionLauncher':
        navigator.push(MaterialPageRoute(
          builder: (_) => PreSessionScreen(bleService: bleService),
        ));
        break;
    }
  });

  runApp(BioVoltApp(
    sessionStorage: sessionStorage,
    bleService: bleService,
    sessionRecorder: sessionRecorder,
    trendAnalyst: trendAnalyst,
    firstLaunch: firstLaunch,
  ));
}
