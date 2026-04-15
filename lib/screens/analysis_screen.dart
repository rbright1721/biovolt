import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/session/session_bloc.dart';
import '../bloc/session/session_state.dart';
import '../config/theme.dart';
import '../models/ai_analysis.dart';
import '../models/session.dart';
import '../models/session_type.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';

class AnalysisScreen extends StatefulWidget {
  final Session session;
  final AiAnalysis? analysis;

  const AnalysisScreen({
    super.key,
    required this.session,
    this.analysis,
  });

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  AiAnalysis? _analysis;
  bool _hasKey = false;

  @override
  void initState() {
    super.initState();
    _analysis = widget.analysis;
    _checkKeyAndLoadAnalysis();
  }

  Future<void> _checkKeyAndLoadAnalysis() async {
    final hasKey = await AiService().hasValidKey();
    if (mounted) setState(() => _hasKey = hasKey);

    // Try loading from storage if not provided
    if (_analysis == null) {
      final stored =
          StorageService().getAiAnalysis(widget.session.sessionId);
      if (stored != null && mounted) {
        setState(() => _analysis = stored);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SessionBloc, SessionState>(
      listenWhen: (prev, curr) =>
          curr.analysis != null &&
          curr.analysis!.sessionId == widget.session.sessionId,
      listener: (context, state) {
        if (state.analysis != null) {
          setState(() => _analysis = state.analysis);
        }
      },
      child: Scaffold(
        backgroundColor: BioVoltColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    const SizedBox(height: 16),
                    _buildMetricsSummary(),
                    const SizedBox(height: 20),
                    _buildAnalysisSection(),
                    const SizedBox(height: 20),
                    _buildSubjectiveSection(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    final session = widget.session;
    final type = _sessionTypeFrom(session);
    final dt = session.createdAt;
    final dateStr =
        '${dt.month}/${dt.day}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final durationStr = _formatDuration(session.durationSeconds);
    final hrSource = session.biometrics?.computed?.hrSource ?? 'PPG';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: BioVoltColors.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          if (type != null) ...[
            Text(type.iconChar, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${(type?.displayName ?? 'Session').toUpperCase()} ANALYSIS',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: BioVoltColors.teal,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  '$dateStr  \u2022  $durationStr  \u2022  $hrSource',
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
    );
  }

  // ---------------------------------------------------------------------------
  // Metrics summary
  // ---------------------------------------------------------------------------

  Widget _buildMetricsSummary() {
    final computed = widget.session.biometrics?.computed;
    final esp32 = widget.session.biometrics?.esp32;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _MetricChip(
            label: 'HRV',
            value: computed?.hrvRmssdMs != null
                ? '${computed!.hrvRmssdMs!.toStringAsFixed(1)} ms'
                : '--',
            color: BioVoltColors.teal,
            badge: computed?.hrvSource,
          ),
          _MetricChip(
            label: 'HR',
            value: computed?.heartRateMeanBpm != null
                ? '${computed!.heartRateMeanBpm!.toStringAsFixed(0)} bpm'
                : '--',
            color: BioVoltColors.teal,
          ),
          _MetricChip(
            label: 'GSR',
            value: esp32?.gsrMeanUs != null
                ? '${esp32!.gsrMeanUs!.toStringAsFixed(1)} \u00B5S'
                : '--',
            color: BioVoltColors.amber,
          ),
          _MetricChip(
            label: 'SpO2',
            value: esp32?.spo2Percent != null
                ? '${esp32!.spo2Percent!.toStringAsFixed(0)}%'
                : '--',
            color: BioVoltColors.teal,
          ),
          _MetricChip(
            label: 'Temp',
            value: esp32?.skinTempC != null
                ? '${esp32!.skinTempC!.toStringAsFixed(1)} \u00B0C'
                : '--',
            color: BioVoltColors.coral,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AI Analysis
  // ---------------------------------------------------------------------------

  Widget _buildAnalysisSection() {
    if (_analysis != null) {
      return _buildAnalysisCards(_analysis!);
    }

    if (_hasKey) {
      return _buildAnalysisLoading();
    }

    return _buildNoKeyPrompt();
  }

  Widget _buildAnalysisCards(AiAnalysis analysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('AI ANALYSIS'),
        const SizedBox(height: 10),
        if (analysis.insights.isNotEmpty)
          _AnalysisCard(
            icon: Icons.lightbulb_outline_rounded,
            title: 'Insights',
            items: analysis.insights,
            tintColor: BioVoltColors.teal,
          ),
        if (analysis.anomalies.isNotEmpty)
          _AnalysisCard(
            icon: Icons.warning_amber_rounded,
            title: 'Anomalies',
            items: analysis.anomalies,
            tintColor: BioVoltColors.amber,
          ),
        if (analysis.correlationsDetected.isNotEmpty)
          _AnalysisCard(
            icon: Icons.link_rounded,
            title: 'Correlations',
            items: analysis.correlationsDetected,
            tintColor: BioVoltColors.teal,
          ),
        if (analysis.protocolRecommendations.isNotEmpty)
          _AnalysisCard(
            icon: Icons.assignment_outlined,
            title: 'Recommendations',
            items: analysis.protocolRecommendations,
            tintColor: BioVoltColors.teal,
          ),
        if (analysis.flags.isNotEmpty)
          _AnalysisCard(
            icon: Icons.flag_rounded,
            title: 'Flags',
            items: analysis.flags,
            tintColor: BioVoltColors.coral,
          ),
        if (analysis.trendSummary != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BioVoltTheme.glassCard(glowColor: BioVoltColors.teal),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.show_chart_rounded,
                        size: 16, color: BioVoltColors.teal),
                    const SizedBox(width: 6),
                    Text(
                      'TREND SUMMARY',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: BioVoltColors.teal,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  analysis.trendSummary!,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: BioVoltColors.textPrimary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
        // Confidence bar
        _buildConfidenceBar(analysis.confidence),
      ],
    );
  }

  Widget _buildConfidenceBar(double confidence) {
    final pct = (confidence * 100).round();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text(
            'Analysis confidence:',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: BioVoltColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: confidence,
                minHeight: 6,
                backgroundColor: BioVoltColors.surface,
                valueColor:
                    AlwaysStoppedAnimation(BioVoltColors.teal),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$pct%',
            style: BioVoltTheme.valueStyle(12, color: BioVoltColors.teal),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisLoading() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BioVoltTheme.glassCard(glowColor: BioVoltColors.teal),
      child: Column(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: BioVoltColors.teal,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Analyzing session...',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              color: BioVoltColors.teal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Analysis runs in the background. Check back in a moment.',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: BioVoltColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoKeyPrompt() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BioVoltTheme.glassCard(glowColor: BioVoltColors.surface),
      child: Column(
        children: [
          Icon(
            Icons.vpn_key_rounded,
            size: 32,
            color: BioVoltColors.textSecondary.withAlpha(120),
          ),
          const SizedBox(height: 12),
          Text(
            'Add your API key in Settings\nto unlock AI analysis.',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              color: BioVoltColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              // Navigate to settings tab — go back to main shell
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: BioVoltColors.teal.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: BioVoltColors.teal.withAlpha(80)),
              ),
              child: Text(
                'GO TO SETTINGS',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: BioVoltColors.teal,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Subjective scores
  // ---------------------------------------------------------------------------

  Widget _buildSubjectiveSection() {
    final subj = widget.session.subjective;
    if (subj == null ||
        (subj.preSession == null && subj.postSession == null)) {
      return const SizedBox.shrink();
    }

    final pre = subj.preSession;
    final post = subj.postSession;
    final hasBoth = pre != null && post != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('SUBJECTIVE SCORES'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BioVoltTheme.glassCard(glowColor: BioVoltColors.surface),
          child: hasBoth
              ? _buildComparisonTable(pre, post)
              : _buildSingleScores(pre ?? post!),
        ),
      ],
    );
  }

  Widget _buildComparisonTable(SubjectiveScores pre, SubjectiveScores post) {
    final fields = <String, (int?, int?)>{
      'Energy': (pre.energy, post.energy),
      'Mood': (pre.mood, post.mood),
      'Focus': (pre.focus, post.focus),
      'Anxiety': (pre.anxiety, post.anxiety),
      'Calm': (pre.calm, post.calm),
      'Motivation': (pre.motivation, post.motivation),
    };

    return Column(
      children: [
        // Header row
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Text('',
                  style: GoogleFonts.jetBrainsMono(fontSize: 10)),
            ),
            _tableHeader('Before'),
            _tableHeader('After'),
            _tableHeader('Change'),
          ],
        ),
        const Divider(color: BioVoltColors.cardBorder, height: 16),
        ...fields.entries.where((e) => e.value.$1 != null || e.value.$2 != null).map(
            (e) => _comparisonRow(e.key, e.value.$1, e.value.$2)),
      ],
    );
  }

  Widget _tableHeader(String text) {
    return SizedBox(
      width: 60,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: BioVoltColors.textSecondary,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _comparisonRow(String label, int? before, int? after) {
    final delta = (before != null && after != null) ? after - before : null;
    String changeStr = '';
    Color changeColor = BioVoltColors.textSecondary;

    if (delta != null) {
      final sign = delta > 0 ? '+' : '';
      final arrow = delta > 0
          ? ' \u2191'
          : delta < 0
              ? ' \u2193'
              : '';
      changeStr = '$sign$delta$arrow';

      // For anxiety, decrease is good
      if (label == 'Anxiety') {
        changeColor =
            delta < 0 ? BioVoltColors.teal : BioVoltColors.coral;
      } else {
        changeColor =
            delta > 0 ? BioVoltColors.teal : BioVoltColors.coral;
      }
      if (delta == 0) changeColor = BioVoltColors.textSecondary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: BioVoltColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              before?.toString() ?? '-',
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: BioVoltColors.textSecondary,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              after?.toString() ?? '-',
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: BioVoltColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              changeStr,
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: changeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleScores(SubjectiveScores scores) {
    final fields = <String, int?>{
      'Energy': scores.energy,
      'Mood': scores.mood,
      'Focus': scores.focus,
      'Anxiety': scores.anxiety,
      'Calm': scores.calm,
      'Motivation': scores.motivation,
      'Session quality': scores.sessionQuality,
    };

    return Column(
      children: fields.entries
          .where((e) => e.value != null)
          .map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.key,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: BioVoltColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${e.value}/10',
                      style: BioVoltTheme.valueStyle(12,
                          color: BioVoltColors.teal),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: BioVoltColors.teal,
        letterSpacing: 2,
      ),
    );
  }

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
}

// =============================================================================
// Shared widgets
// =============================================================================

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String? badge;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.color,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          if (badge != null) ...[
            const SizedBox(height: 2),
            Text(
              badge!,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8,
                color: BioVoltColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> items;
  final Color tintColor;

  const _AnalysisCard({
    required this.icon,
    required this.title,
    required this.items,
    required this.tintColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tintColor.withAlpha(8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tintColor.withAlpha(35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: tintColor),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: tintColor,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tintColor.withAlpha(120),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: BioVoltColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
