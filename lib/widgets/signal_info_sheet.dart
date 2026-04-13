import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/session.dart';
import '../models/signal_info.dart';

/// Modal bottom sheet showing detailed signal reference information.
///
/// Shows current value on a visual range bar, descriptions of what the signal
/// means, healthy/warning/critical ranges, and per-session-type guidance.
class SignalInfoSheet extends StatelessWidget {
  final SignalInfo info;
  final double currentValue;

  const SignalInfoSheet({
    super.key,
    required this.info,
    required this.currentValue,
  });

  /// Show this sheet as a modal bottom sheet.
  static void show(
    BuildContext context, {
    required SignalInfo info,
    required double currentValue,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SignalInfoSheet(info: info, currentValue: currentValue),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rangeColor = info.rangeFor(currentValue)?.color ?? BioVoltColors.textSecondary;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: BioVoltColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(color: BioVoltColors.cardBorder, width: 1),
              left: BorderSide(color: BioVoltColors.cardBorder, width: 1),
              right: BorderSide(color: BioVoltColors.cardBorder, width: 1),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: BioVoltColors.textSecondary.withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Signal name + current value header
              _buildHeader(rangeColor),
              const SizedBox(height: 20),

              // Visual range bar
              _buildRangeBar(),
              const SizedBox(height: 24),

              // What this means
              _buildSection('WHAT THIS MEANS', info.description),
              const SizedBox(height: 20),

              // High / Low interpretation
              _buildDualSection(
                leftTitle: 'HIGH MEANS',
                leftBody: info.highMeans,
                leftColor: info.higherIsBetter == true
                    ? BioVoltColors.teal
                    : BioVoltColors.coral,
                rightTitle: 'LOW MEANS',
                rightBody: info.lowMeans,
                rightColor: info.higherIsBetter == false
                    ? BioVoltColors.teal
                    : BioVoltColors.coral,
              ),
              const SizedBox(height: 20),

              // Ranges table
              _buildRangesTable(),
              const SizedBox(height: 20),

              // Session guidance
              _buildSessionGuidance(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(Color rangeColor) {
    final range = info.rangeFor(currentValue);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info.name.toUpperCase(),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: BioVoltColors.textSecondary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              if (range != null)
                Text(
                  range.label.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: rangeColor,
                    letterSpacing: 1.5,
                  ),
                ),
            ],
          ),
        ),
        Text(
          _formatValue(currentValue),
          style: BioVoltTheme.valueStyle(40, color: rangeColor),
        ),
        const SizedBox(width: 6),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            info.unit,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              color: BioVoltColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRangeBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final allMin = info.displayMin;
        final allMax = info.displayMax;
        final totalRange = allMax - allMin;
        if (totalRange <= 0) return const SizedBox.shrink();

        // Clamp the indicator position
        final clampedValue = currentValue.clamp(allMin, allMax);
        final fraction = (clampedValue - allMin) / totalRange;

        return Column(
          children: [
            // Range bar segments
            SizedBox(
              height: 12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  children: info.ranges.map((r) {
                    final segWidth =
                        ((r.max - r.min) / totalRange) * totalWidth;
                    return Container(
                      width: segWidth.clamp(2, totalWidth),
                      color: r.color.withAlpha(100),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Current value indicator
            SizedBox(
              height: 16,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: (fraction * totalWidth) - 6,
                    top: 0,
                    child: Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: info.rangeFor(currentValue)?.color ??
                                BioVoltColors.textSecondary,
                            boxShadow: [
                              BoxShadow(
                                color: (info.rangeFor(currentValue)?.color ??
                                        BioVoltColors.textSecondary)
                                    .withAlpha(120),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Min / Max labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatValue(allMin),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    color: BioVoltColors.textSecondary,
                  ),
                ),
                Text(
                  _formatValue(allMax),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    color: BioVoltColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSection(String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: BioVoltColors.textSecondary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            color: BioVoltColors.textPrimary,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildDualSection({
    required String leftTitle,
    required String leftBody,
    required Color leftColor,
    required String rightTitle,
    required String rightBody,
    required Color rightColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: leftColor.withAlpha(12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: leftColor.withAlpha(40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.arrow_upward_rounded,
                        size: 12, color: leftColor),
                    const SizedBox(width: 4),
                    Text(
                      leftTitle,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: leftColor,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  leftBody,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: BioVoltColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: rightColor.withAlpha(12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: rightColor.withAlpha(40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.arrow_downward_rounded,
                        size: 12, color: rightColor),
                    const SizedBox(width: 4),
                    Text(
                      rightTitle,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: rightColor,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  rightBody,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: BioVoltColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRangesTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RANGES',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: BioVoltColors.textSecondary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        ...info.ranges.map((r) {
          final isActive = currentValue >= r.min && currentValue <= r.max;
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? r.color.withAlpha(20) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isActive
                  ? Border.all(color: r.color.withAlpha(60))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: r.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    r.label,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? BioVoltColors.textPrimary
                          : BioVoltColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  '${_formatValue(r.min)} \u2013 ${_formatValue(r.max)}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive
                        ? r.color
                        : BioVoltColors.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSessionGuidance() {
    if (info.sessionGuidance.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DURING SESSIONS',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: BioVoltColors.textSecondary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        ...info.sessionGuidance.map((g) {
          return _SessionGuidanceTile(guidance: g);
        }),
      ],
    );
  }

  String _formatValue(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    if (v < 10) return v.toStringAsFixed(2);
    return v.toStringAsFixed(1);
  }
}

class _SessionGuidanceTile extends StatefulWidget {
  final SessionGuidance guidance;
  const _SessionGuidanceTile({required this.guidance});

  @override
  State<_SessionGuidanceTile> createState() => _SessionGuidanceTileState();
}

class _SessionGuidanceTileState extends State<_SessionGuidanceTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final type = widget.guidance.sessionType;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: BioVoltColors.surfaceLight.withAlpha(120),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _expanded
              ? BioVoltColors.teal.withAlpha(40)
              : BioVoltColors.cardBorder,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    type.iconChar,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      type.displayName,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: BioVoltColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: BioVoltColors.textSecondary,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 8),
                Text(
                  widget.guidance.description,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: BioVoltColors.textPrimary,
                    height: 1.6,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
