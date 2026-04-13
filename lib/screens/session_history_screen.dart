import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../bloc/session/session_bloc.dart';
import '../bloc/session/session_state.dart';
import '../config/theme.dart';
import '../models/session.dart';

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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SessionDetailScreen(session: session),
      ),
    );
  }
}

class _SessionListCard extends StatelessWidget {
  final Session session;
  final VoidCallback onTap;

  const _SessionListCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateTime =
        DateTime.fromMillisecondsSinceEpoch(session.startTimeMs);
    final dateStr =
        '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    final timeStr =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    final summary = _buildSummary();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BioVoltTheme.glassCard(glowColor: BioVoltColors.teal),
        child: Row(
          children: [
            // Type icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: BioVoltColors.teal.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                session.type.iconChar,
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.type.displayName,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: BioVoltColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$dateStr  $timeStr  \u2022  ${session.durationFormatted}',
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

  String? _buildSummary() {
    if (session.snapshots.length < 2) return null;

    return switch (session.type) {
      SessionType.breathwork => _formatChange(
          'HRV', session.metricChange((s) => s.hrv)),
      SessionType.coldExposure => _formatChange(
          'Temp', session.metricChange((s) => s.temperature)),
      SessionType.meditation => _formatChange(
          'GSR', session.metricChange((s) => s.gsr)),
      SessionType.fastingCheck =>
        'Avg HR ${session.avgMetric((s) => s.heartRate).toStringAsFixed(0)} BPM',
      SessionType.grounding => _formatChange(
          'GSR', session.metricChange((s) => s.gsr)),
    };
  }

  String _formatChange(String metric, double change) {
    final sign = change >= 0 ? '+' : '';
    return '$metric $sign${change.toStringAsFixed(1)}% during session';
  }
}

class _SessionDetailScreen extends StatelessWidget {
  final Session session;

  const _SessionDetailScreen({required this.session});

  @override
  Widget build(BuildContext context) {
    final dateTime =
        DateTime.fromMillisecondsSinceEpoch(session.startTimeMs);
    final dateStr =
        '${dateTime.month}/${dateTime.day}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: BioVoltColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: BioVoltColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.type.displayName.toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: BioVoltColors.teal,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        '$dateStr  \u2022  ${session.durationFormatted}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: BioVoltColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: session.snapshots.isEmpty
                  ? Center(
                      child: Text(
                        'No data recorded',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          color: BioVoltColors.textSecondary,
                        ),
                      ),
                    )
                  : _buildCharts(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharts() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Summary stats
          _buildSummaryRow(),
          const SizedBox(height: 20),
          _buildChart(
            'Heart Rate',
            'BPM',
            BioVoltColors.teal,
            session.snapshots.map((s) => s.heartRate).toList(),
          ),
          const SizedBox(height: 16),
          _buildChart(
            'HRV RMSSD',
            'ms',
            BioVoltColors.teal,
            session.snapshots.map((s) => s.hrv).toList(),
          ),
          const SizedBox(height: 16),
          _buildChart(
            'GSR',
            '\u00B5S',
            BioVoltColors.amber,
            session.snapshots.map((s) => s.gsr).toList(),
          ),
          const SizedBox(height: 16),
          _buildChart(
            'Temperature',
            '\u00B0F',
            BioVoltColors.coral,
            session.snapshots.map((s) => s.temperature).toList(),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Row(
      children: [
        _summaryBox(
          'Avg HR',
          '${session.avgMetric((s) => s.heartRate).toStringAsFixed(0)} BPM',
          BioVoltColors.teal,
        ),
        const SizedBox(width: 10),
        _summaryBox(
          'Avg HRV',
          '${session.avgMetric((s) => s.hrv).toStringAsFixed(1)} ms',
          BioVoltColors.teal,
        ),
        const SizedBox(width: 10),
        _summaryBox(
          'Avg GSR',
          '${session.avgMetric((s) => s.gsr).toStringAsFixed(2)} \u00B5S',
          BioVoltColors.amber,
        ),
      ],
    );
  }

  Widget _summaryBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BioVoltTheme.glassCard(glowColor: color),
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: BioVoltColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: BioVoltTheme.valueStyle(14, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(
      String label, String unit, Color color, List<double> data) {
    if (data.isEmpty) return const SizedBox.shrink();

    final spots = data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    final minY = data.reduce((a, b) => a < b ? a : b);
    final maxY = data.reduce((a, b) => a > b ? a : b);
    final range = maxY - minY;
    final padding = range == 0 ? 1.0 : range * 0.15;

    return Container(
      height: 160,
      padding: const EdgeInsets.all(14),
      decoration: BioVoltTheme.glassCard(glowColor: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                unit,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  color: BioVoltColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: range == 0 ? 1 : range / 3,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: BioVoltColors.gridLine,
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minY: minY - padding,
                maxY: maxY + padding,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: color,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withAlpha(20),
                    ),
                  ),
                ],
                lineTouchData: const LineTouchData(enabled: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
