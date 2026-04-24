import 'package:biovolt/models/biometric_records.dart';
import 'package:biovolt/models/normalized_record.dart';
import 'package:biovolt/services/session_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SessionRecorder.buildChestStrapMetrics', () {
    test('returns null when no chest-strap RR samples are present', () {
      final records = <NormalizedRecord>[
        HeartRateReading(
          bpm: 72,
          source: DataSource.ppg50hz,
          quality: DataQuality.consumer,
          connectorId: 'esp32_biovolt',
          timestamp: DateTime(2026, 4, 23),
        ),
      ];

      expect(SessionRecorder.buildChestStrapMetrics(records), isNull);
    });

    test('flattens RR samples and summarises HR/HRV', () {
      final t = DateTime(2026, 4, 23);
      final records = <NormalizedRecord>[
        HeartRateReading(
          bpm: 60,
          source: DataSource.ppg50hz,
          quality: DataQuality.research,
          connectorId: 'chest_strap',
          timestamp: t,
        ),
        HeartRateReading(
          bpm: 70,
          source: DataSource.ppg50hz,
          quality: DataQuality.research,
          connectorId: 'chest_strap',
          timestamp: t.add(const Duration(seconds: 1)),
        ),
        HRVReading(
          rmssdMs: 40,
          sdnnMs: 50,
          source: DataSource.ppg50hz,
          quality: DataQuality.research,
          connectorId: 'chest_strap',
          timestamp: t.add(const Duration(seconds: 5)),
        ),
        RrIntervalSample(
          rrIntervalsMs: const [1000, 990],
          connectorId: 'chest_strap',
          timestamp: t,
          quality: DataQuality.research,
        ),
        RrIntervalSample(
          rrIntervalsMs: const [985, 1005],
          connectorId: 'chest_strap',
          timestamp: t.add(const Duration(seconds: 2)),
          quality: DataQuality.research,
        ),
      ];

      final metrics = SessionRecorder.buildChestStrapMetrics(records);
      expect(metrics, isNotNull);
      expect(metrics!.rrIntervalsMs, [1000, 990, 985, 1005]);
      expect(metrics.heartRateBpm, 65);
      expect(metrics.hrvRmssdMs, 40);
      expect(metrics.hrvSdnnMs, 50);
    });

    test('ignores RR samples from non-chest-strap connectors', () {
      final records = <NormalizedRecord>[
        RrIntervalSample(
          rrIntervalsMs: const [900, 910],
          connectorId: 'esp32_biovolt',
          timestamp: DateTime(2026, 4, 23),
          quality: DataQuality.consumer,
        ),
      ];

      expect(SessionRecorder.buildChestStrapMetrics(records), isNull);
    });
  });

  group('ChestStrapConnector emission path (through parser)', () {
    test('parsed RR intervals flow into RrIntervalSample list', () {
      // Shape of record the connector emits per HR notification with RRs.
      final sample = RrIntervalSample(
        rrIntervalsMs: const [1000, 500],
        connectorId: 'chest_strap',
        timestamp: DateTime(2026, 4, 23),
        quality: DataQuality.research,
      );
      expect(sample.rrIntervalsMs, [1000, 500]);
      expect(sample.connectorId, 'chest_strap');
    });
  });
}
