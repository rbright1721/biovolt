import 'package:biovolt/models/biovolt_event.dart';
import 'package:biovolt/services/event_types.dart';
import 'package:biovolt/ui/timeline/renderers/timeline_entry_classified_renderer.dart';
import 'package:biovolt/ui/timeline/renderers/timeline_entry_reclassified_renderer.dart';
import 'package:biovolt/ui/timeline/timeline_event_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const classified = TimelineEntryClassifiedRenderer();
  const reclassified = TimelineEntryReclassifiedRenderer();

  BiovoltEvent ev(String type, Map<String, dynamic> payload) => BiovoltEvent(
        id: 'evt-${payload.hashCode}',
        timestamp: DateTime(2026, 4, 20, 10),
        deviceId: 'dev-1',
        type: type,
        payload: payload,
        schemaVersion: 1,
      );

  group('TimelineEntryClassifiedRenderer', () {
    test('eventType matches timeline.entry_classified', () {
      expect(classified.eventType, 'timeline.entry_classified');
    });

    test('default registry resolves the classified event to this renderer',
        () {
      final resolved = TimelineRendererRegistry.defaultRegistry
          .getRegistered(EventTypes.entryClassified);
      expect(resolved, isA<TimelineEntryClassifiedRenderer>());
    });

    test('buildSummary returns truncated rawText for long text', () {
      final summary = classified.buildSummary(ev(
        EventTypes.entryClassified,
        {'rawText': 'a' * 120, 'type': 'dose', 'confidence': 0.9},
      ));
      expect(summary.endsWith('…'), isTrue);
      expect(summary.length, lessThanOrEqualTo(60));
    });

    test('buildSummary falls back to "Vitals snapshot" when rawText is empty',
        () {
      expect(
        classified.buildSummary(ev(EventTypes.entryClassified, {
          'rawText': '',
          'type': 'bookmark',
          'confidence': 1.0,
        })),
        'Vitals snapshot',
      );
    });

    testWidgets('buildRow passes the uppercased type as summary', (tester) async {
      final row = classified.buildRow(
        _StubContext(),
        ev(EventTypes.entryClassified, {
          'rawText': 'took 500mg NAC',
          'type': 'dose',
          'confidence': 0.92,
        }),
      ) as TimelineRow;
      expect(row.title, 'took 500mg NAC');
      expect(row.summary, 'DOSE');
    });

    testWidgets('buildRow appends a low-confidence annotation when '
        'confidence < 0.7', (tester) async {
      final row = classified.buildRow(
        _StubContext(),
        ev(EventTypes.entryClassified, {
          'rawText': 'maybe meal',
          'type': 'meal',
          'confidence': 0.55,
        }),
      ) as TimelineRow;
      expect(row.summary, contains('MEAL'));
      expect(row.summary, contains('low confidence'));
    });

    testWidgets('buildRow omits the low-confidence annotation when '
        'confidence is null (event predates payload extension)',
        (tester) async {
      final row = classified.buildRow(
        _StubContext(),
        ev(EventTypes.entryClassified, {
          'rawText': 'legacy event',
          'type': 'note',
          // confidence key intentionally absent.
        }),
      ) as TimelineRow;
      expect(row.summary, 'NOTE');
    });
  });

  group('TimelineEntryReclassifiedRenderer', () {
    test('eventType matches timeline.entry_reclassified', () {
      expect(reclassified.eventType, 'timeline.entry_reclassified');
    });

    test('default registry resolves the reclassified event to this renderer',
        () {
      final resolved = TimelineRendererRegistry.defaultRegistry
          .getRegistered(EventTypes.entryReclassified);
      expect(resolved, isA<TimelineEntryReclassifiedRenderer>());
    });

    testWidgets('buildRow prefixes the summary with "Re-classified as"',
        (tester) async {
      final row = reclassified.buildRow(
        _StubContext(),
        ev(EventTypes.entryReclassified, {
          'rawText': 'earlier dose, now meal',
          'type': 'meal',
          'confidence': 0.88,
        }),
      ) as TimelineRow;
      expect(row.summary, 'Re-classified as MEAL');
    });

    testWidgets('low-confidence annotation applies on reclassification too',
        (tester) async {
      final row = reclassified.buildRow(
        _StubContext(),
        ev(EventTypes.entryReclassified, {
          'rawText': 'uncertain',
          'type': 'mood',
          'confidence': 0.4,
        }),
      ) as TimelineRow;
      expect(row.summary, contains('Re-classified as MOOD'));
      expect(row.summary, contains('low confidence'));
    });
  });
}

class _StubContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
