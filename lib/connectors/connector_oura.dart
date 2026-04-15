import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/biometric_records.dart';
import '../models/normalized_record.dart';
import '../models/oura_daily.dart';
import '../models/sleep_record.dart';
import 'connector_base.dart';

/// Oura Ring v2 REST API connector.
///
/// Uses Personal Access Token (PAT) auth for now. Full OAuth2 Authorization
/// Code flow will be added when deep linking is wired up.
class OuraConnector implements BioVoltConnector {
  static const _baseUrl = 'https://api.ouraring.com';
  // ignore: unused_field
  static const _authUrl = 'https://cloud.ouraring.com/oauth/authorize';
  // ignore: unused_field
  static const _tokenUrl = 'https://api.ouraring.com/oauth/token';

  static const _keyAccessToken = 'oura_access_token';
  static const _keyRefreshToken = 'oura_refresh_token';
  static const _keyTokenExpiry = 'oura_token_expiry';

  final _secureStorage = const FlutterSecureStorage();
  final http.Client _httpClient;

  ConnectorStatus _status = ConnectorStatus.disconnected;
  DateTime? _lastSync;
  String? _cachedToken;
  String _errorMessage = '';

  OuraConnector({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  // ---------------------------------------------------------------------------
  // Identity
  // ---------------------------------------------------------------------------

  @override
  String get connectorId => 'oura_ring_4';

  @override
  String get displayName => 'Oura Ring 4';

  @override
  String get deviceDescription =>
      'Oura Ring Gen 4 — overnight sleep, readiness, HRV, SpO2, '
      'stress, and resilience via REST API v2';

  @override
  ConnectorType get type => ConnectorType.restApi;

  @override
  List<DataType> get supportedDataTypes => const [
        DataType.heartRate,
        DataType.hrv,
        DataType.sleep,
        DataType.readiness,
        DataType.stress,
        DataType.spO2,
      ];

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  /// Authenticate using a Personal Access Token.
  ///
  /// For now this stores a PAT directly. The user obtains it from
  /// https://cloud.ouraring.com/personal-access-tokens.
  ///
  /// TODO: Replace with full OAuth2 Authorization Code flow when deep linking
  /// is configured. The flow would:
  ///   1. Open _authUrl in browser via url_launcher
  ///   2. Handle redirect callback with auth code
  ///   3. Exchange code for access+refresh tokens at _tokenUrl
  ///   4. Store tokens in secure storage
  @override
  Future<void> authenticate() async {
    // Check if a token is already stored
    final existing = await _secureStorage.read(key: _keyAccessToken);
    if (existing != null && existing.isNotEmpty) {
      _cachedToken = existing;
      _status = ConnectorStatus.connected;
      return;
    }
    // No token — status stays disconnected until setPersonalAccessToken() is called
  }

  /// Store a Personal Access Token obtained from the Oura developer portal.
  ///
  /// Call this from the settings UI when the user pastes their PAT.
  Future<void> setPersonalAccessToken(String token) async {
    await _secureStorage.write(key: _keyAccessToken, value: token);
    // PATs don't expire via refresh — clear any stale refresh/expiry keys
    await _secureStorage.delete(key: _keyRefreshToken);
    await _secureStorage.delete(key: _keyTokenExpiry);
    _cachedToken = token;
    _status = ConnectorStatus.connected;
  }

  /// Refresh the access token using the stored refresh token.
  ///
  /// Only applicable when full OAuth2 is implemented. PATs don't refresh.
  Future<bool> refreshAuth() async {
    final refreshToken = await _secureStorage.read(key: _keyRefreshToken);
    if (refreshToken == null) return false;

    // TODO: Implement OAuth2 token refresh:
    // POST _tokenUrl with grant_type=refresh_token, refresh_token, client_id, client_secret
    // On success: store new access_token, refresh_token, expiry
    // On failure: return false

    return false;
  }

  /// Returns a valid access token, refreshing if needed.
  Future<String?> _getValidToken() async {
    if (_cachedToken != null) {
      // Check expiry (only relevant for OAuth2 tokens, not PATs)
      final expiryStr = await _secureStorage.read(key: _keyTokenExpiry);
      if (expiryStr != null) {
        final expiry = DateTime.tryParse(expiryStr);
        if (expiry != null && DateTime.now().isAfter(expiry)) {
          final refreshed = await refreshAuth();
          if (!refreshed) {
            _cachedToken = null;
            _status = ConnectorStatus.unauthorized;
            return null;
          }
          _cachedToken = await _secureStorage.read(key: _keyAccessToken);
        }
      }
      return _cachedToken;
    }

    final stored = await _secureStorage.read(key: _keyAccessToken);
    if (stored != null && stored.isNotEmpty) {
      _cachedToken = stored;
      return stored;
    }
    return null;
  }

  @override
  Future<void> revokeAuth() async {
    await _secureStorage.delete(key: _keyAccessToken);
    await _secureStorage.delete(key: _keyRefreshToken);
    await _secureStorage.delete(key: _keyTokenExpiry);
    _cachedToken = null;
    _status = ConnectorStatus.disconnected;
  }

  @override
  bool get isAuthenticated =>
      _cachedToken != null || _status == ConnectorStatus.connected;

  // ---------------------------------------------------------------------------
  // HTTP helpers
  // ---------------------------------------------------------------------------

  /// Make an authenticated GET request to the Oura v2 API.
  ///
  /// Handles 401 (retry after refresh) and 429 (exponential backoff).
  Future<Map<String, dynamic>?> _apiGet(
    String path, {
    Map<String, String>? queryParams,
    int retryCount = 0,
  }) async {
    final token = await _getValidToken();
    if (token == null) {
      _status = ConnectorStatus.unauthorized;
      return null;
    }

    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: queryParams);

    try {
      final response = await _httpClient.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      switch (response.statusCode) {
        case 200:
          _status = ConnectorStatus.connected;
          return json.decode(response.body) as Map<String, dynamic>;

        case 401:
          if (retryCount == 0) {
            final refreshed = await refreshAuth();
            if (refreshed) {
              return _apiGet(path,
                  queryParams: queryParams, retryCount: retryCount + 1);
            }
          }
          // Still 401 after refresh — clear tokens
          await revokeAuth();
          _status = ConnectorStatus.unauthorized;
          _errorMessage = 'Authentication expired. Please re-authenticate.';
          return null;

        case 429:
          // Rate limited — respect Retry-After header with exponential backoff
          final retryAfter = int.tryParse(
                  response.headers['retry-after'] ?? '') ??
              (2 << retryCount).clamp(1, 60);
          if (retryCount < 3) {
            await Future.delayed(Duration(seconds: retryAfter));
            return _apiGet(path,
                queryParams: queryParams, retryCount: retryCount + 1);
          }
          _errorMessage = 'Rate limited by Oura API. Try again later.';
          _status = ConnectorStatus.error;
          return null;

        default:
          _errorMessage =
              'Oura API error: ${response.statusCode} ${response.reasonPhrase}';
          _status = ConnectorStatus.error;
          return null;
      }
    } catch (e) {
      _errorMessage = 'Network error: $e';
      _status = ConnectorStatus.error;
      return null;
    }
  }

  /// Helper to format a DateTime as YYYY-MM-DD for Oura query params.
  String _dateParam(DateTime dt) => dt.toIso8601String().substring(0, 10);

  // ---------------------------------------------------------------------------
  // Data — pullHistorical
  // ---------------------------------------------------------------------------

  @override
  Future<List<NormalizedRecord>> pullHistorical(
      DateTime from, DateTime to) async {
    if (!isAuthenticated) return [];

    _status = ConnectorStatus.syncing;

    final params = {'start_date': _dateParam(from), 'end_date': _dateParam(to)};

    // Pull all endpoints
    final results = await Future.wait([
      _apiGet('/v2/usercollection/daily_sleep', queryParams: params),
      _apiGet('/v2/usercollection/sleep', queryParams: params),
      _apiGet('/v2/usercollection/daily_readiness', queryParams: params),
      _apiGet('/v2/usercollection/daily_spo2', queryParams: params),
      _apiGet('/v2/usercollection/daily_stress', queryParams: params),
      _apiGet('/v2/usercollection/daily_resilience', queryParams: params),
      _apiGet('/v2/usercollection/heartrate', queryParams: params),
    ]);

    final dailySleepData = results[0];
    final sleepData = results[1];
    // results[2] (readiness), results[4] (stress), results[5] (resilience)
    // are merged into OuraDailyRecord by OuraSyncService, not mapped here.
    final spo2Data = results[3];
    final heartRateData = results[6];

    final records = <NormalizedRecord>[];

    // --- Map sleep records ---
    records.addAll(_mapSleepRecords(
      dailySleepData?['data'] as List<dynamic>?,
      sleepData?['data'] as List<dynamic>?,
    ));

    // --- Map SpO2 readings ---
    records.addAll(_mapSpo2Records(spo2Data?['data'] as List<dynamic>?));

    // --- Map heart rate readings ---
    records.addAll(_mapHeartRateRecords(
      heartRateData?['data'] as List<dynamic>?,
      sleepData?['data'] as List<dynamic>?,
    ));

    _lastSync = DateTime.now();
    if (_status == ConnectorStatus.syncing) {
      _status = ConnectorStatus.connected;
    }

    records.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return records;
  }

  /// Build an [OuraDailyRecord] by merging data from all daily endpoints
  /// for a single calendar day. Used by [OuraSyncService].
  OuraDailyRecord buildDailyRecord({
    required String day,
    Map<String, dynamic>? dailySleep,
    Map<String, dynamic>? readiness,
    Map<String, dynamic>? spo2,
    Map<String, dynamic>? stress,
    Map<String, dynamic>? resilience,
    Map<String, dynamic>? heartRate,
  }) {
    return OuraDailyRecord(
      date: DateTime.parse(day),
      syncedAt: DateTime.now(),
      sleepScore: dailySleep?['score'] as int?,
      sleepContributors: dailySleep?['contributors'] != null
          ? SleepContributors(
              deepSleep: dailySleep!['contributors']['deep_sleep'] as int?,
              efficiency: dailySleep['contributors']['efficiency'] as int?,
              latency: dailySleep['contributors']['latency'] as int?,
              remSleep: dailySleep['contributors']['rem_sleep'] as int?,
              restfulness: dailySleep['contributors']['restfulness'] as int?,
              timing: dailySleep['contributors']['timing'] as int?,
              totalSleep: dailySleep['contributors']['total_sleep'] as int?,
            )
          : null,
      readinessScore: readiness?['score'] as int?,
      readinessContributors: readiness?['contributors'] != null
          ? ReadinessContributors(
              activityBalance:
                  readiness!['contributors']['activity_balance'] as int?,
              bodyTemperature:
                  readiness['contributors']['body_temperature'] as int?,
              hrvBalance:
                  readiness['contributors']['hrv_balance'] as int?,
              previousDayActivity:
                  readiness['contributors']['previous_day_activity'] as int?,
              previousNight:
                  readiness['contributors']['previous_night'] as int?,
              recoveryIndex:
                  readiness['contributors']['recovery_index'] as int?,
              restingHeartRate:
                  readiness['contributors']['resting_heart_rate'] as int?,
              sleepBalance:
                  readiness['contributors']['sleep_balance'] as int?,
            )
          : null,
      temperatureDeviationC:
          (readiness?['temperature_deviation'] as num?)?.toDouble(),
      temperatureTrendDeviationC:
          (readiness?['temperature_trend_deviation'] as num?)?.toDouble(),
      spo2AveragePercent:
          (spo2?['spo2_percentage']?['average'] as num?)?.toDouble(),
      breathingDisturbanceIndex:
          (spo2?['breathing_disturbance_index'] as num?)?.toDouble(),
      highStressSeconds: stress?['stress_high'] as int?,
      highRecoverySeconds: stress?['recovery_high'] as int?,
      stressDaySummary: stress?['day_summary'] as String?,
      resilienceLevel: resilience?['level'] as String?,
    );
  }

  /// Pull raw data from a single endpoint. Exposed for [OuraSyncService].
  Future<List<dynamic>?> fetchEndpoint(
      String path, DateTime from, DateTime to) async {
    final params = {'start_date': _dateParam(from), 'end_date': _dateParam(to)};
    final result = await _apiGet(path, queryParams: params);
    return result?['data'] as List<dynamic>?;
  }

  // ---------------------------------------------------------------------------
  // Mappers
  // ---------------------------------------------------------------------------

  List<SleepRecord> _mapSleepRecords(
    List<dynamic>? dailySleepList,
    List<dynamic>? detailedSleepList,
  ) {
    if (detailedSleepList == null) return [];

    // Index daily scores by day for merging
    final dailyScores = <String, int>{};
    if (dailySleepList != null) {
      for (final d in dailySleepList) {
        final day = d['day'] as String?;
        final score = d['score'] as int?;
        if (day != null && score != null) {
          dailyScores[day] = score;
        }
      }
    }

    return detailedSleepList.map<SleepRecord?>((s) {
      try {
        final day = s['day'] as String?;
        final bedtimeStart = s['bedtime_start'] as String?;
        final bedtimeEnd = s['bedtime_end'] as String?;
        if (bedtimeStart == null || bedtimeEnd == null) return null;

        return SleepRecord(
          bedtimeStart: DateTime.parse(bedtimeStart),
          bedtimeEnd: DateTime.parse(bedtimeEnd),
          totalSleepSeconds: s['total_sleep_duration'] as int? ?? 0,
          deepSleepSeconds: s['deep_sleep_duration'] as int? ?? 0,
          remSleepSeconds: s['rem_sleep_duration'] as int? ?? 0,
          lightSleepSeconds: s['light_sleep_duration'] as int? ?? 0,
          timeInBedSeconds: s['time_in_bed'] as int? ?? 0,
          latencySeconds: s['latency'] as int?,
          efficiency: (s['efficiency'] as num?)?.toDouble(),
          lowestHrBpm: s['lowest_heart_rate'] as int?,
          restlessPeriods: s['restless_periods'] as int?,
          sleepPhaseSequence: s['sleep_phase_5_min'] as String?,
          sleepScore: day != null ? dailyScores[day] : null,
          connectorId: connectorId,
          timestamp: DateTime.parse(bedtimeStart),
          quality: DataQuality.consumer,
        );
      } catch (_) {
        return null;
      }
    }).whereType<SleepRecord>().toList();
  }

  List<SpO2Reading> _mapSpo2Records(List<dynamic>? spo2List) {
    if (spo2List == null) return [];

    return spo2List.map<SpO2Reading?>((s) {
      try {
        final avg =
            (s['spo2_percentage']?['average'] as num?)?.toDouble();
        if (avg == null) return null;

        final day = s['day'] as String? ?? DateTime.now().toIso8601String();

        return SpO2Reading(
          percent: avg,
          connectorId: connectorId,
          timestamp: DateTime.parse(day),
          quality: DataQuality.consumer,
        );
      } catch (_) {
        return null;
      }
    }).whereType<SpO2Reading>().toList();
  }

  List<HeartRateReading> _mapHeartRateRecords(
    List<dynamic>? hrList,
    List<dynamic>? sleepList,
  ) {
    if (hrList == null) return [];

    // Build sleep windows to filter HR samples to overnight only
    final sleepWindows = <({DateTime start, DateTime end})>[];
    if (sleepList != null) {
      for (final s in sleepList) {
        final startStr = s['bedtime_start'] as String?;
        final endStr = s['bedtime_end'] as String?;
        if (startStr != null && endStr != null) {
          sleepWindows.add((
            start: DateTime.parse(startStr),
            end: DateTime.parse(endStr),
          ));
        }
      }
    }

    bool inSleepWindow(DateTime ts) {
      if (sleepWindows.isEmpty) return true; // no filter if no sleep data
      for (final w in sleepWindows) {
        if (!ts.isBefore(w.start) && !ts.isAfter(w.end)) return true;
      }
      return false;
    }

    return hrList.map<HeartRateReading?>((hr) {
      try {
        final bpm = (hr['bpm'] as num?)?.toDouble();
        final tsStr = hr['timestamp'] as String?;
        if (bpm == null || tsStr == null) return null;

        final ts = DateTime.parse(tsStr);
        if (!inSleepWindow(ts)) return null;

        return HeartRateReading(
          bpm: bpm,
          source: DataSource.overnightRing,
          quality: DataQuality.consumer,
          connectorId: connectorId,
          timestamp: ts,
        );
      } catch (_) {
        return null;
      }
    }).whereType<HeartRateReading>().toList();
  }

  // ---------------------------------------------------------------------------
  // Live stream — not supported for REST connectors
  // ---------------------------------------------------------------------------

  @override
  Stream<NormalizedRecord>? get liveStream => null;

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  @override
  ConnectorStatus get status => _status;

  /// Human-readable error message from the last failed operation.
  String get errorMessage => _errorMessage;

  @override
  DateTime? get lastSync => _lastSync;

  @override
  Future<void> disconnect() async {
    _status = ConnectorStatus.disconnected;
  }
}
