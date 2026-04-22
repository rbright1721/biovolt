import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/session/session_bloc.dart';
import '../../../config/theme.dart';
import '../../../models/session.dart';
import '../../../models/session_type.dart';
import '../../../services/storage_service.dart';
import '../../analysis_screen.dart';
import '../timeline_item.dart';
import 'timeline_row.dart';

class TimelineSessionTile extends StatelessWidget {
  final TimelineSession item;
  const TimelineSessionTile({required this.item, super.key});

  @override
  Widget build(BuildContext context) {
    final s = item.session;
    final type = _typeFor(s);
    return TimelineRow(
      time: s.createdAt,
      iconWidget: const TimelineLeadingIcon(
        icon: Icons.timer_rounded,
        color: BioVoltColors.teal,
      ),
      primary: '${type?.displayName ?? 'Session'} · '
          '${_formatDuration(s.durationSeconds)}',
      secondary: _summary(s),
      onTap: () => _open(context, s),
    );
  }

  SessionType? _typeFor(Session s) {
    final name = s.context?.activities.isNotEmpty == true
        ? s.context!.activities.first.type
        : null;
    if (name == null) return null;
    for (final t in SessionType.values) {
      if (t.name == name) return t;
    }
    return null;
  }

  String _formatDuration(int? seconds) {
    if (seconds == null) return '--:--';
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final r = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  String? _summary(Session s) {
    final c = s.biometrics?.computed;
    if (c == null) return null;
    final parts = <String>[];
    if (c.hrvRmssdMs != null) {
      parts.add('HRV ${c.hrvRmssdMs!.toStringAsFixed(0)}ms');
    }
    if (c.heartRateMeanBpm != null) {
      parts.add('HR ${c.heartRateMeanBpm!.toStringAsFixed(0)}bpm');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  void _open(BuildContext context, Session s) {
    final analysis = StorageService().getAiAnalysis(s.sessionId);
    final sessionBloc = context.read<SessionBloc>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: sessionBloc,
          child: AnalysisScreen(session: s, analysis: analysis),
        ),
      ),
    );
  }
}
