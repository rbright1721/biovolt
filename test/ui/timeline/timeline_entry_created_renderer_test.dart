import 'package:biovolt/models/biovolt_event.dart';
import 'package:biovolt/services/event_types.dart';
import 'package:biovolt/ui/timeline/renderers/timeline_entry_created_renderer.dart';
import 'package:biovolt/ui/timeline/timeline_event_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const renderer = TimelineEntryCreatedRenderer();

  BiovoltEvent ev(Map<String, dynamic> payload) => BiovoltEvent(
        id: 'evt-${payload.hashCode}',
        timestamp: DateTime(2026, 4, 20, 10),
        deviceId: 'dev-1',
        type: EventTypes.entryCreated,
        payload: payload,
        schemaVersion: 1,
      );

  test('eventType matches timeline.entry_created', () {
    expect(renderer.eventType, 'timeline.entry_created');
  });

  test('buildSummary returns the truncated rawText for long text', () {
    final summary = renderer.buildSummary(ev({
      'rawText': 'a' * 120,
      'type': 'other',
    }));
    // Contains an ellipsis and is capped at about 60 chars.
    expect(summary.endsWith('…'), isTrue);
    expect(summary.length, lessThanOrEqualTo(60));
  });

  test('buildSummary returns "Vitals snapshot" when rawText is empty', () {
    expect(
      renderer.buildSummary(ev({'rawText': '', 'type': 'other'})),
      'Vitals snapshot',
    );
    expect(
      renderer.buildSummary(ev({'rawText': '   ', 'type': 'other'})),
      'Vitals snapshot',
    );
  });

  testWidgets('buildRow renders a TimelineRow with rawText as title',
      (tester) async {
    final widget = renderer.buildRow(
      _StubContext(),
      ev({
        'rawText': 'took 500mg NAC',
        'type': 'other',
      }),
    );
    expect(widget, isA<TimelineRow>());
    final row = widget as TimelineRow;
    expect(row.title, 'took 500mg NAC');
    // 'other' renders as 'log' in the secondary line.
    expect(row.summary, 'log');
  });

  testWidgets(
      'buildRow preserves concrete classifier types (e.g. "dose") verbatim',
      (tester) async {
    final row = renderer.buildRow(
      _StubContext(),
      ev({
        'rawText': 'took 250mcg BPC-157',
        'type': 'dose',
      }),
    ) as TimelineRow;
    expect(row.summary, 'dose');
  });
}

// buildRow only needs a BuildContext to satisfy the signature — it
// doesn't actually look anything up via InheritedWidgets for the
// TimelineEntryCreatedRenderer. A stub context is enough for the
// assertions we make on the returned widget tree.
class _StubContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
