import 'package:biovolt/connectors/chest_strap_known_devices.dart';
import 'package:biovolt/connectors/connector_chest_strap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChestStrapConnector.parseHrMeasurement (BLE 0x2A37)', () {
    test('uint8 HR format, no RR intervals', () {
      // flags=0x00 (bit0=0 → uint8 HR, bit4=0 → no RR), hr=72
      final parsed = ChestStrapConnector.parseHrMeasurement([0x00, 72]);
      expect(parsed, isNotNull);
      expect(parsed!.bpm, 72);
      expect(parsed.rrIntervalsMs, isEmpty);
    });

    test('uint16 HR format, no RR intervals', () {
      // flags=0x01 (bit0=1 → uint16 HR, bit4=0 → no RR), hr=300 (0x012C)
      final parsed =
          ChestStrapConnector.parseHrMeasurement([0x01, 0x2C, 0x01]);
      expect(parsed, isNotNull);
      expect(parsed!.bpm, 300);
      expect(parsed.rrIntervalsMs, isEmpty);
    });

    test('uint8 HR format with RR intervals (1/1024 s → ms)', () {
      // flags=0x10 (bit4=1 → RR present, bit0=0 → uint8 HR)
      // hr=60, rr=[1024, 512] ticks → 1000 ms, 500 ms
      final parsed = ChestStrapConnector.parseHrMeasurement([
        0x10,
        60,
        0x00, 0x04, // 1024 LE
        0x00, 0x02, // 512 LE
      ]);
      expect(parsed, isNotNull);
      expect(parsed!.bpm, 60);
      expect(parsed.rrIntervalsMs, [1000, 500]);
    });

    test('uint16 HR format with RR intervals', () {
      // flags=0x11 (bit0=1 uint16, bit4=1 RR), hr=150, rr=[820 ticks]
      // 820 * 1000/1024 ≈ 800.78 → rounds to 801
      final parsed = ChestStrapConnector.parseHrMeasurement([
        0x11,
        0x96, 0x00, // 150 LE
        0x34, 0x03, // 820 LE
      ]);
      expect(parsed, isNotNull);
      expect(parsed!.bpm, 150);
      expect(parsed.rrIntervalsMs.length, 1);
      expect(parsed.rrIntervalsMs.first, 801);
    });

    test('energy-expended field (bit 3) is skipped correctly', () {
      // flags=0x18 (bit3=1 energy, bit4=1 RR, uint8 HR), hr=70,
      // energy=500 (0x01F4 LE), rr=[1024] → 1000 ms
      final parsed = ChestStrapConnector.parseHrMeasurement([
        0x18,
        70,
        0xF4, 0x01, // energy 500 LE (skipped)
        0x00, 0x04, // rr 1024 LE
      ]);
      expect(parsed, isNotNull);
      expect(parsed!.bpm, 70);
      expect(parsed.rrIntervalsMs, [1000]);
    });

    test('payload too short → null', () {
      expect(ChestStrapConnector.parseHrMeasurement([]), isNull);
      expect(ChestStrapConnector.parseHrMeasurement([0x00]), isNull);
      // uint16 HR flag but only 2 bytes total
      expect(
        ChestStrapConnector.parseHrMeasurement([0x01, 0x2C]),
        isNull,
      );
    });

    test('RR parsing tolerates odd trailing byte (drops it)', () {
      // flags=0x10 RR present, hr=80, then 3 trailing bytes → only
      // the first uint16 LE parses, the lone byte is ignored.
      final parsed = ChestStrapConnector.parseHrMeasurement([
        0x10,
        80,
        0x00, 0x04, // 1024 → 1000 ms
        0x99, // orphan byte
      ]);
      expect(parsed, isNotNull);
      expect(parsed!.rrIntervalsMs, [1000]);
    });
  });

  group('resolveChestStrapProfile', () {
    test('Polar H10 advertised name resolves to known profile', () {
      final p = resolveChestStrapProfile('Polar H10 ABC123');
      expect(p.label, 'Polar H10');
      expect(p.supportsEcg, isFalse);
    });

    test('H10 match is case-insensitive', () {
      final p = resolveChestStrapProfile('polar h10');
      expect(p.label, 'Polar H10');
    });

    test('Coospo H9Z resolves to known profile', () {
      final p = resolveChestStrapProfile('H9Z_1234');
      expect(p.label, 'Coospo H9Z');
      expect(p.supportsEcg, isFalse);
    });

    test('unknown device falls back to advertised name with no ECG', () {
      final p = resolveChestStrapProfile('Garmin HRM 987');
      expect(p.label, 'Garmin HRM 987');
      expect(p.supportsEcg, isFalse);
    });

    test('empty advertised name falls back to a generic label', () {
      final p = resolveChestStrapProfile('');
      expect(p.label, 'Chest Strap');
      expect(p.supportsEcg, isFalse);
    });
  });
}
