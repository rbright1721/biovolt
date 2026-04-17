import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/session/session_bloc.dart';
import '../bloc/session/session_event.dart';
import '../bloc/session/session_state.dart';
import '../config/theme.dart';
import '../models/session.dart';
import '../models/session_type.dart';
import '../models/vitals_bookmark.dart';
import '../services/storage_service.dart';
import 'analysis_screen.dart';

class SessionHistoryScreen extends StatelessWidget {
  const SessionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, state) {
        final bookmarks = StorageService().getAllBookmarks();
        final timeline = <({String type, dynamic item, DateTime time})>[
          ...state.history.map(
              (s) => (type: 'session', item: s as dynamic, time: s.createdAt)),
          ...bookmarks.map((b) =>
              (type: 'bookmark', item: b as dynamic, time: b.timestamp)),
        ];
        timeline.sort((a, b) => b.time.compareTo(a.time));

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
                    '${state.history.length} sessions \u2022 ${bookmarks.length} bookmarks',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: timeline.isEmpty
                      ? _buildEmptyState()
                      : _buildTimeline(context, timeline),
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

  Widget _buildTimeline(
      BuildContext context,
      List<({String type, dynamic item, DateTime time})> timeline) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: timeline.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final entry = timeline[index];
        if (entry.type == 'bookmark') {
          return _BookmarkListCard(bookmark: entry.item as VitalsBookmark);
        }
        final session = entry.item as Session;
        return Dismissible(
          key: Key(session.sessionId),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.transparent,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFA32D2D).withAlpha(200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'DELETE',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFF09595),
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          confirmDismiss: (direction) =>
              _confirmDeleteDialog(context),
          onDismissed: (direction) => _deleteSession(context, session),
          child: _SessionListCard(
            session: session,
            onTap: () => _showSessionDetail(context, session),
          ),
        );
      },
    );
  }

  Future<bool> _confirmDeleteDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BioVoltColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: BioVoltColors.cardBorder),
        ),
        title: Text(
          'Delete session?',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: BioVoltColors.textPrimary,
          ),
        ),
        content: Text(
          'This session and its AI analysis will be permanently removed.',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            color: BioVoltColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                color: BioVoltColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                color: const Color(0xFFE24B4A),
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteSession(
      BuildContext context, Session session) async {
    final storage = StorageService();
    await storage.deleteSession(session.sessionId);
    await storage.deleteAiAnalysis(session.sessionId);
    if (context.mounted) {
      context.read<SessionBloc>().add(SessionHistoryLoaded());
    }
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

class _BookmarkListCard extends StatelessWidget {
  final VitalsBookmark bookmark;
  const _BookmarkListCard({required this.bookmark});

  @override
  Widget build(BuildContext context) {
    final dt = bookmark.timestamp;
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour < 12 ? 'am' : 'pm';
    final min = dt.minute.toString().padLeft(2, '0');
    final timeStr = '${dt.month}/${dt.day}  $h:$min $period';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: BioVoltColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BioVoltColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: BioVoltColors.teal.withAlpha(15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: BioVoltColors.teal.withAlpha(60)),
            ),
            child: const Icon(Icons.bookmark_rounded,
                size: 16, color: BioVoltColors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bookmark.note ?? 'Vitals snapshot',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: BioVoltColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (bookmark.hrBpm != null)
                        _miniChip(
                            'HR', bookmark.hrBpm!.toStringAsFixed(0)),
                      if (bookmark.hrvMs != null)
                        _miniChip(
                            'HRV', '${bookmark.hrvMs!.toStringAsFixed(0)}ms'),
                      if (bookmark.gsrUs != null)
                        _miniChip(
                            'GSR', '${bookmark.gsrUs!.toStringAsFixed(1)}\u00B5S'),
                      if (bookmark.spo2Percent != null)
                        _miniChip('SpO2',
                            '${bookmark.spo2Percent!.toStringAsFixed(0)}%'),
                      Text(
                        timeStr,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          color: BioVoltColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniChip(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: BioVoltColors.background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: BioVoltColors.cardBorder),
      ),
      child: Text(
        '$label $value',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9,
          color: BioVoltColors.textSecondary,
        ),
      ),
    );
  }
}

