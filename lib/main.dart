import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'connectors/connector_esp32.dart';
import 'connectors/connector_registry.dart';
import 'services/ble_service.dart';
import 'services/session_storage.dart';
import 'services/storage_service.dart';

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

  runApp(BioVoltApp(
    sessionStorage: sessionStorage,
    bleService: bleService,
  ));
}
