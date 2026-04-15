import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/session/session_bloc.dart';
import '../bloc/session/session_state.dart';
import '../config/theme.dart';
import '../models/session.dart';
import '../models/session_type.dart';
import '../services/storage_service.dart';
import 'analysis_screen.dart';

class SessionHistoryScreen extends StatelessWidget {
  const SessionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: BioVoltColors.background,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    'SESSIONS',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: BioVoltColors.teal,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '${state.history.length} recorded sessions',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: state.history.isEmpty
                      ? _buildEmptyState()
                      : _buildSessionList(context, state.history),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timeline_rounded,
            size: 48,
            color: BioVoltColors.textSecondary.withAlpha(80),
          ),
          const SizedBox(height: 16),
          Text(
            'No sessions yet',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              color: BioVoltColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Start a session from the dashboard',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: BioVoltColors.textSecondary.withAlpha(120),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionList(BuildContext context, List<Session> sessions) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final session = sessions[index];
        return _SessionListCard(
          session: session,
          onTap: () => _showSessionDetail(context, session),
        );
      },
    );
  }

  void _showSessionDetail(BuildContext context, Session session) {
    final analysis = StorageService().getAiAnalysis(session.sessionId);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<SessionBloc>(),
          child: AnalysisScreen(
            session: session,
            analysis: analysis,
          ),
        ),
      ),
    );
  }
}

/// Resolve a [SessionType] from the first activity in a [Session]'s context.
SessionType? _sessionTypeFrom(Session session) {
  final typeName = session.context?.activities.firstOrNull?.type;
  if (typeName == null) return null;
  for (final t in SessionType.values) {
    if (t.name == typeName) return t;
  }
  return null;
}

String _formatDuration(int? seconds) {
  if (seconds == null) return '--:--';
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

class _SessionListCard extends StatelessWidget {
  final Session session;
  final VoidCallback onTap;

  const _SessionListCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateTime = session.createdAt;
    final dateStr = '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    final timeStr =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    final type = _sessionTypeFrom(session);
    final summary = _buildSummary(type);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BioVoltTheme.glassCard(glowColor: BioVoltColors.teal),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: BioVoltColors.teal.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                type?.iconChar ?? '\u{2753}',
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type?.displayName ?? 'Session',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: BioVoltColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$dateStr  $timeStr  \u2022  ${_formatDuration(session.durationSeconds)}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: BioVoltColors.textSecondary,
                    ),
                  ),
                  if (summary != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      summary,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: BioVoltColors.teal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: BioVoltColors.textSecondary.withAlpha(80),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String? _buildSummary(SessionType? type) {
    final computed = session.biometrics?.computed;
    if (computed == null) return null;

    return switch (type) {
      SessionType.breathwork => computed.hrvRmssdMs != null
          ? 'HRV ${computed.hrvRmssdMs!.toStringAsFixed(1)} ms avg'
          : null,
      SessionType.coldExposure => computed.heartRateMinBpm != null
          ? 'Min HR ${computed.heartRateMinBpm!.toStringAsFixed(0)} BPM'
          : null,
      SessionType.meditation => computed.coherenceScore != null
          ? 'Coherence ${computed.coherenceScore!.toStringAsFixed(0)} avg'
          : null,
      SessionType.fastingCheck => computed.heartRateMeanBpm != null
          ? 'Avg HR ${computed.heartRateMeanBpm!.toStringAsFixed(0)} BPM'
          : null,
      SessionType.grounding => computed.lfHfProxy != null
          ? 'LF/HF ${computed.lfHfProxy!.toStringAsFixed(2)}'
          : null,
      null => null,
    };
  }
}

