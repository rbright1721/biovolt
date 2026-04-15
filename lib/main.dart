import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'connectors/connector_esp32.dart';
import 'connectors/connector_oura.dart';
import 'connectors/connector_polar.dart';
import 'connectors/connector_registry.dart';
import 'services/ai_service.dart';
import 'services/ble_service.dart';
import 'services/oura_sync_service.dart';
import 'services/prompt_builder.dart';
import 'services/session_recorder.dart';
import 'services/session_storage.dart';
import 'services/storage_service.dart';
import 'services/trend_analyst.dart';

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

  final storageService = StorageService();
  await storageService.init();

  final sessionStorage = SessionStorage(storageService);

  // Create BleService and register ESP32 connector
  final bleService = BleService();
  final registry = ConnectorRegistry.instance;
  registry.register(Esp32Connector(bleService: bleService));

  // Register Polar H10 connector
  final polarConnector = PolarConnector();
  registry.register(polarConnector);
  // Auto-reconnect if previously paired
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

  runApp(BioVoltApp(
    sessionStorage: sessionStorage,
    bleService: bleService,
    sessionRecorder: sessionRecorder,
    trendAnalyst: trendAnalyst,
  ));
}
