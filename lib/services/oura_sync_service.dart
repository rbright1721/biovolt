import '../connectors/connector_oura.dart';
import 'storage_service.dart';

/// Orchestrates Oura Ring data sync lifecycle.
///
/// Pulls data from the Oura v2 API via [OuraConnector], merges daily
/// endpoint responses into [OuraDailyRecord] objects, and persists
/// everything via [StorageService].
class OuraSyncService {
  final OuraConnector _connector;
  final StorageService _storage;

  OuraSyncService({
    required OuraConnector connector,
    required StorageService storage,
  })  : _connector = connector,
        _storage = storage;

  /// Called on app open — pulls any days missing from local storage.
  ///
  /// Finds the last synced date, pulls from there to today, and saves
  /// all records. Runs silently — network errors are logged on the
  /// connector status, never thrown.
  Future<void> syncMissingDays() async {
    if (!_connector.isAuthenticated) return;

    try {
      // Find the most recent OuraDailyRecord in storage
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Check last 90 days to find the most recent record
      final lookback = today.subtract(const Duration(days: 90));
      final existing = _storage.getOuraRecordsInRange(lookback, today);

      // Start from the day after the last record, or 7 days back if no records
      final from = existing.isNotEmpty
          ? existing.last.date.add(const Duration(days: 1))
          : today.subtract(const Duration(days: 7));

      if (!from.isBefore(today)) return; // already up to date

      await _syncRange(from, today);
    } catch (_) {
      // Errors are surfaced via connector.status / connector.errorMessage
    }
  }

  /// Force re-pull the last [days] days, overwriting existing records.
  Future<void> forceSync({int days = 7}) async {
    if (!_connector.isAuthenticated) return;

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final from = today.subtract(Duration(days: days));
      await _syncRange(from, today);
    } catch (_) {
      // Errors surfaced via connector status
    }
  }

  /// Pull all endpoints for a date range and save daily records + normalized records.
  Future<void> _syncRange(DateTime from, DateTime to) async {
    // Pull normalized records (SleepRecords, SpO2Readings, HeartRateReadings)
    final normalizedRecords = await _connector.pullHistorical(from, to);

    // Save SleepRecords as sessions (optional — they're also in OuraDailyRecords)
    // For now, we focus on building and saving OuraDailyRecords.

    // Pull raw daily data for building OuraDailyRecords
    final dailySleepList =
        await _connector.fetchEndpoint('/v2/usercollection/daily_sleep', from, to);
    final readinessList =
        await _connector.fetchEndpoint('/v2/usercollection/daily_readiness', from, to);
    final spo2List =
        await _connector.fetchEndpoint('/v2/usercollection/daily_spo2', from, to);
    final stressList =
        await _connector.fetchEndpoint('/v2/usercollection/daily_stress', from, to);
    final resilienceList =
        await _connector.fetchEndpoint('/v2/usercollection/daily_resilience', from, to);

    // Index each endpoint's data by day
    final dailySleepByDay = _indexByDay(dailySleepList);
    final readinessByDay = _indexByDay(readinessList);
    final spo2ByDay = _indexByDay(spo2List);
    final stressByDay = _indexByDay(stressList);
    final resilienceByDay = _indexByDay(resilienceList);

    // Collect all days across all endpoints
    final allDays = <String>{
      ...dailySleepByDay.keys,
      ...readinessByDay.keys,
      ...spo2ByDay.keys,
      ...stressByDay.keys,
      ...resilienceByDay.keys,
    };

    // Build and save an OuraDailyRecord for each day
    for (final day in allDays) {
      final record = _connector.buildDailyRecord(
        day: day,
        dailySleep: dailySleepByDay[day],
        readiness: readinessByDay[day],
        spo2: spo2ByDay[day],
        stress: stressByDay[day],
        resilience: resilienceByDay[day],
      );
      await _storage.saveOuraDailyRecord(record);
    }

    // pullHistorical also produces individual NormalizedRecords
    // (HeartRateReadings, SpO2Readings, SleepRecords). For now the
    // OuraDailyRecord is the primary storage unit; individual records
    // can be persisted to the biometric_records box in a future pass.
    normalizedRecords; // intentionally unused for now
  }

  /// Index a list of Oura API response items by their 'day' field.
  Map<String, Map<String, dynamic>> _indexByDay(List<dynamic>? items) {
    final map = <String, Map<String, dynamic>>{};
    if (items == null) return map;
    for (final item in items) {
      if (item is Map<String, dynamic>) {
        final day = item['day'] as String?;
        if (day != null) map[day] = item;
      }
    }
    return map;
  }
}
