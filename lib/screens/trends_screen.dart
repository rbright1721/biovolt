import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/trend_data.dart';
import '../services/trend_analyst.dart';
import '../ui/timeline/protocol_timeline_view.dart';

enum _TrendsMode { trends, timeline }

class TrendsScreen extends StatefulWidget {
  final TrendAnalyst trendAnalyst;

  const TrendsScreen({super.key, required this.trendAnalyst});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  // Minimum session count before trend charts become statistically meaningful.
  // Matches the existing 5-data-point threshold already used for the
  // subjective-trends subsection (see _buildSubjectiveSection).
  static const int _minSessionsForTrends = 5;

  int _selectedDays = 30;
  TrendData? _trendData;
  bool _loading = true;
  String? _weeklyReport;
  DateTime? _weeklyReportDate;
  bool _weeklyLoading = false;
  String? _filterType;
  _TrendsMode _mode = _TrendsMode.trends;

  @override
  void initState() {
    super.initState();
    _loadTrends();
    _loadWeeklySummary();
  }

  Future<void> _loadTrends() async {
    setState(() => _loading = true);
    final data = await widget.trendAnalyst.computeTrends(_selectedDays);
    if (mounted) setState(() { _trendData = data; _loading = false; });
  }

  Future<void> _loadWeeklySummary() async {
    final result = await widget.trendAnalyst.getLatestWeeklySummary();
    if (result != null && mounted) {
      setState(() {
        _weeklyReport = result.$1;
        _weeklyReportDate = result.$2;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BioVoltColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                _mode == _TrendsMode.trends ? 'TRENDS' : 'TIMELINE',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: BioVoltColors.teal,
                  letterSpacing: 3,
                ),
              ),
            ),
            _buildModeSelector(),
            if (_mode == _TrendsMode.trends) ...[
              _buildPeriodSelector(),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: BioVoltColors.teal, strokeWidth: 2))
                    : _buildContent(),
              ),
            ] else
              const Expanded(child: ProtocolTimelineView()),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          for (final (mode, label) in const [
            (_TrendsMode.trends, 'TRENDS'),
            (_TrendsMode.timeline, 'TIMELINE'),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _ModeChip(
                label: label,
                selected: _mode == mode,
                onTap: () => setState(() => _mode = mode),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          for (final days in [30, 60, 90])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _PeriodChip(
                label: '$days days',
                selected: _selectedDays == days,
                onTap: () {
                  setState(() => _selectedDays = days);
                  _loadTrends();
                },
              ),
            ),
          const Spacer(),
          if (_filterType != null)
            GestureDetector(
              onTap: () { setState(() => _filterType = null); },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: BioVoltColors.coral.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: BioVoltColors.coral.withAlpha(60)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _filterType!,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        color: BioVoltColors.coral,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.close, size: 12, color: BioVoltColors.coral),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final data = _trendData;
    final sessionCount = data?.totalSessions ?? 0;
    if (data == null || sessionCount < _minSessionsForTrends) {
      return _buildInsufficientDataState(sessionCount, _minSessionsForTrends);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildHrvSection(data),
        const SizedBox(height: 20),
        _buildGsrSection(data),
        const SizedBox(height: 20),
        _buildSleepSection(data),
        const SizedBox(height: 20),
        _buildSubjectiveSection(data),
        const SizedBox(height: 20),
        _buildSessionBreakdown(data),
        const SizedBox(height: 20),
        _buildWeeklyAiSection(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildInsufficientDataState(int sessionCount, int needed) {
    final progress = (sessionCount / needed).clamp(0.0, 1.0);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.show_chart_rounded,
              size: 48,
              color: BioVoltColors.textSecondary.withAlpha(80),
            ),
            const SizedBox(height: 20),
            Text(
              'Building your baseline',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: BioVoltColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete $needed sessions to unlock\ntrend analysis and charts',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: BioVoltColors.textSecondary,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: BioVoltColors.surface,
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: BioVoltColors.teal,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$sessionCount of $needed sessions',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: BioVoltColors.teal,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Each session adds to your biological\nbaseline. Run breathwork, cold plunge,\nor meditation sessions to build data.',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: BioVoltColors.textSecondary.withAlpha(180),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 1 — HRV Trend
  // ---------------------------------------------------------------------------

  Widget _buildHrvSection(TrendData data) {
    final series = data.hrvTimeSeries;
    if (series.isEmpty) return const SizedBox.shrink();

    final trendPct = (data.hrvBaseline != null &&
            data.hrvCurrent != null &&
            data.hrvBaseline! > 0)
        ? ((data.hrvCurrent! - data.hrvBaseline!) / data.hrvBaseline! * 100)
        : null;

    return _ChartCard(
      title: 'HRV TREND',
      subtitle: 'RMSSD (ms)',
      trendBadge: trendPct != null
          ? _TrendBadge(
              value: trendPct,
              label: 'vs baseline',
              higherIsBetter: true,
            )
          : null,
      child: _buildLineChart(
        series: series,
        color: BioVoltColors.teal,
        baselineValue: data.hrvBaseline,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 2 — GSR Trend
  // ---------------------------------------------------------------------------

  Widget _buildGsrSection(TrendData data) {
    final series = data.gsrTimeSeries;
    if (series.isEmpty) return const SizedBox.shrink();

    final trendDelta =
        (data.gsrBaseline != null && data.gsrCurrent != null)
            ? data.gsrCurrent! - data.gsrBaseline!
            : null;

    return _ChartCard(
      title: 'GSR BASELINE',
      subtitle: '\u00B5S (lower = calmer)',
      trendBadge: trendDelta != null
          ? _TrendBadge(
              value: trendDelta,
              label: '\u00B5S vs baseline',
              higherIsBetter: false,
              isAbsolute: true,
            )
          : null,
      child: _buildLineChart(
        series: series,
        color: BioVoltColors.amber,
        baselineValue: data.gsrBaseline,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 3 — Sleep & Recovery
  // ---------------------------------------------------------------------------

  Widget _buildSleepSection(TrendData data) {
    if (data.sleepScoreTimeSeries.isEmpty &&
        data.readinessTimeSeries.isEmpty) {
      return _ChartCard(
        title: 'SLEEP & RECOVERY',
        subtitle: 'Oura Ring',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Connect Oura Ring in Settings\nto see sleep trends',
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: BioVoltColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ),
      );
    }

    return _ChartCard(
      title: 'SLEEP & RECOVERY',
      subtitle: data.avgSleepScore != null
          ? 'Avg sleep ${data.avgSleepScore!.toStringAsFixed(0)} \u2022 '
              'Avg readiness ${data.avgReadiness?.toStringAsFixed(0) ?? '--'}'
          : 'Oura Ring',
      child: _buildDualLineChart(
        series1: data.sleepScoreTimeSeries,
        color1: const Color(0xFF60A5FA),
        label1: 'Sleep',
        series2: data.readinessTimeSeries,
        color2: const Color(0xFFA78BFA),
        label2: 'Readiness',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 4 — Subjective Trends
  // ---------------------------------------------------------------------------

  Widget _buildSubjectiveSection(TrendData data) {
    final total = data.energyTimeSeries.length +
        data.moodTimeSeries.length +
        data.focusTimeSeries.length;

    if (total < 5) {
      return _ChartCard(
        title: 'SUBJECTIVE TRENDS',
        subtitle: 'Self-reported scores',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Keep logging sessions to see\nsubjective trends ($total/5 data points)',
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: BioVoltColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ),
      );
    }

    return _ChartCard(
      title: 'SUBJECTIVE TRENDS',
      subtitle: 'Energy \u2022 Mood \u2022 Focus',
      child: _buildTripleLineChart(
        energy: data.energyTimeSeries,
        mood: data.moodTimeSeries,
        focus: data.focusTimeSeries,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 5 — Session Breakdown
  // ---------------------------------------------------------------------------

  Widget _buildSessionBreakdown(TrendData data) {
    final entries = data.sessionCountByType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) return const SizedBox.shrink();

    return _ChartCard(
      title: 'SESSION BREAKDOWN',
      subtitle: '${data.totalSessions} total sessions',
      child: SizedBox(
        height: 160,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: (entries.first.value + 2).toDouble(),
            barTouchData: BarTouchData(
              touchCallback: (event, response) {
                if (event.isInterestedForInteractions &&
                    response?.spot != null) {
                  final idx = response!.spot!.touchedBarGroupIndex;
                  if (idx < entries.length) {
                    setState(() => _filterType = entries[idx].key);
                  }
                }
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, _) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= entries.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _abbreviate(entries[idx].key),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          color: BioVoltColors.textSecondary,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(show: false),
            barGroups: entries.asMap().entries.map((e) {
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.value.toDouble(),
                    color: BioVoltColors.teal,
                    width: 28,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
                showingTooltipIndicators: [0],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _abbreviate(String type) {
    const map = {
      'breathwork': 'BW',
      'coldExposure': 'CE',
      'meditation': 'MED',
      'fastingCheck': 'FC',
      'grounding': 'GND',
    };
    return map[type] ?? type.substring(0, (type.length).clamp(0, 3)).toUpperCase();
  }

  // ---------------------------------------------------------------------------
  // Section 6 — Weekly AI Analysis
  // ---------------------------------------------------------------------------

  Widget _buildWeeklyAiSection() {
    final isStale = _weeklyReportDate == null ||
        DateTime.now().difference(_weeklyReportDate!).inDays >= 7;

    return _ChartCard(
      title: 'WEEKLY AI ANALYSIS',
      subtitle: _weeklyReportDate != null
          ? 'Generated ${_weeklyReportDate!.month}/${_weeklyReportDate!.day}/${_weeklyReportDate!.year}'
          : 'Not yet generated',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_weeklyReport != null && !isStale)
            Text(
              _weeklyReport!,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: BioVoltColors.textPrimary,
                height: 1.6,
              ),
            ),
          if (_weeklyReport != null && isStale) ...[
            Text(
              _weeklyReport!,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: BioVoltColors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This report is over 7 days old.',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: BioVoltColors.amber,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _weeklyLoading
              ? Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: BioVoltColors.teal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Analyzing your last 30 days...',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: BioVoltColors.teal,
                      ),
                    ),
                  ],
                )
              : GestureDetector(
                  onTap: _runWeeklyAnalysis,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: BioVoltColors.teal.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: BioVoltColors.teal.withAlpha(80)),
                    ),
                    child: Text(
                      'RUN WEEKLY AI ANALYSIS',
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

  Future<void> _runWeeklyAnalysis() async {
    setState(() => _weeklyLoading = true);
    final result = await widget.trendAnalyst.runWeeklyAnalysis();
    if (mounted) {
      setState(() {
        _weeklyLoading = false;
        if (result != null) {
          _weeklyReport = result;
          _weeklyReportDate = DateTime.now();
        }
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Chart builders
  // ---------------------------------------------------------------------------

  Widget _buildLineChart({
    required List<DatedValue> series,
    required Color color,
    double? baselineValue,
  }) {
    if (series.isEmpty) {
      return const SizedBox(height: 160);
    }

    final spots = series.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();

    final values = series.map((d) => d.value).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final range = maxY - minY;
    final padding = range == 0 ? 5.0 : range * 0.15;

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          minY: minY - padding,
          maxY: maxY + padding,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: range == 0 ? 5 : range / 3,
            getDrawingHorizontalLine: (_) => FlLine(
              color: BioVoltColors.gridLine,
              strokeWidth: 0.5,
            ),
          ),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          extraLinesData: baselineValue != null
              ? ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: baselineValue,
                    color: color.withAlpha(60),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ])
              : null,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: color,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: series.length < 20,
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                  radius: 2,
                  color: color,
                  strokeWidth: 0,
                ),
              ),
              belowBarData:
                  BarAreaData(show: true, color: color.withAlpha(15)),
            ),
          ],
          lineTouchData: const LineTouchData(enabled: false),
        ),
      ),
    );
  }

  Widget _buildDualLineChart({
    required List<DatedValue> series1,
    required Color color1,
    required String label1,
    required List<DatedValue> series2,
    required Color color2,
    required String label2,
  }) {
    final allValues = [
      ...series1.map((d) => d.value),
      ...series2.map((d) => d.value),
    ];
    if (allValues.isEmpty) return const SizedBox(height: 160);

    final minY = allValues.reduce((a, b) => a < b ? a : b);
    final maxY = allValues.reduce((a, b) => a > b ? a : b);
    final range = maxY - minY;
    final padding = range == 0 ? 5.0 : range * 0.15;

    final spots1 = series1
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();
    final spots2 = series2
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          minY: minY - padding,
          maxY: maxY + padding,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: BioVoltColors.gridLine,
              strokeWidth: 0.5,
            ),
          ),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            if (spots1.isNotEmpty)
              LineChartBarData(
                spots: spots1,
                isCurved: true,
                color: color1,
                barWidth: 2,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                    show: true, color: color1.withAlpha(12)),
              ),
            if (spots2.isNotEmpty)
              LineChartBarData(
                spots: spots2,
                isCurved: true,
                color: color2,
                barWidth: 2,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                    show: true, color: color2.withAlpha(12)),
              ),
          ],
          lineTouchData: const LineTouchData(enabled: false),
        ),
      ),
    );
  }

  Widget _buildTripleLineChart({
    required List<DatedValue> energy,
    required List<DatedValue> mood,
    required List<DatedValue> focus,
  }) {
    List<FlSpot> toSpots(List<DatedValue> s) => s
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 10,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 2,
            getDrawingHorizontalLine: (_) => FlLine(
              color: BioVoltColors.gridLine,
              strokeWidth: 0.5,
            ),
          ),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            if (energy.isNotEmpty)
              LineChartBarData(
                spots: toSpots(energy),
                isCurved: true,
                color: const Color(0xFFFBBF24),
                barWidth: 2,
                dotData: const FlDotData(show: false),
              ),
            if (mood.isNotEmpty)
              LineChartBarData(
                spots: toSpots(mood),
                isCurved: true,
                color: const Color(0xFF60A5FA),
                barWidth: 2,
                dotData: const FlDotData(show: false),
              ),
            if (focus.isNotEmpty)
              LineChartBarData(
                spots: toSpots(focus),
                isCurved: true,
                color: const Color(0xFF34D399),
                barWidth: 2,
                dotData: const FlDotData(show: false),
              ),
          ],
          lineTouchData: const LineTouchData(enabled: false),
        ),
      ),
    );
  }
}

// =============================================================================
// Shared chart widgets
// =============================================================================

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? BioVoltColors.teal.withAlpha(20)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? BioVoltColors.teal.withAlpha(100)
                : BioVoltColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color:
                selected ? BioVoltColors.teal : BioVoltColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trendBadge;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    this.trendBadge,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BioVoltTheme.glassCard(glowColor: BioVoltColors.teal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: BioVoltColors.teal,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        color: BioVoltColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              ?trendBadge,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  final double value;
  final String label;
  final bool higherIsBetter;
  final bool isAbsolute;

  const _TrendBadge({
    required this.value,
    required this.label,
    required this.higherIsBetter,
    this.isAbsolute = false,
  });

  @override
  Widget build(BuildContext context) {
    final improving = higherIsBetter ? value > 0 : value < 0;
    final color = improving ? BioVoltColors.teal : BioVoltColors.coral;
    final arrow = value > 0 ? '\u2191' : '\u2193';
    final sign = value > 0 ? '+' : '';
    final formatted = isAbsolute
        ? '$sign${value.toStringAsFixed(1)}'
        : '$sign${value.toStringAsFixed(0)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        '$arrow $formatted $label',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? BioVoltColors.teal.withAlpha(30)
              : BioVoltColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? BioVoltColors.teal.withAlpha(120)
                : BioVoltColors.cardBorder,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? BioVoltColors.teal
                : BioVoltColors.textSecondary,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
