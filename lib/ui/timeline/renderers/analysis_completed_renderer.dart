import 'package:flutter/widgets.dart';

import '../../../config/theme.dart';
import '../../../models/biovolt_event.dart';
import '../../../services/event_types.dart';
import '../timeline_event_renderer.dart';

class AnalysisCompletedRenderer extends TimelineEventRenderer {
  const AnalysisCompletedRenderer();

  @override
  String get eventType => EventTypes.analysisCompleted;

  @override
  Widget buildRow(BuildContext context, BiovoltEvent event) {
    return TimelineRow(
      title: 'AI analysis completed',
      summary: event.payload['sessionId']?.toString(),
      timestamp: event.timestamp,
      accent: BioVoltColors.teal,
    );
  }

  @override
  String buildSummary(BiovoltEvent event) => 'AI analysis completed';
}
