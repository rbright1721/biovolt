import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/breathwork_pattern.dart';

/// Bottom sheet for selecting a breathwork pattern.
///
/// Displays foundation patterns and altered-state patterns in separate
/// sections, with visual distinction (amber border for altered state).
class PatternSelector extends StatelessWidget {
  final void Function(BreathworkPatternInfo pattern) onSelected;

  const PatternSelector({super.key, required this.onSelected});

  static Future<BreathworkPatternInfo?> show(BuildContext context) {
    return showModalBottomSheet<BreathworkPatternInfo>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PatternSelector(
        onSelected: (p) => Navigator.of(context).pop(p),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: BoxDecoration(
          color: BioVoltColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: BioVoltColors.cardBorder, width: 1),
        ),
        foregroundDecoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: BioVoltColors.teal, width: 1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: BioVoltColors.textSecondary.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'BREATHWORK PATTERN',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: BioVoltColors.teal,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'SELECT YOUR PRACTICE',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                color: BioVoltColors.textSecondary,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 20),

            // Foundation section
            _buildSectionHeader('FOUNDATION', BioVoltColors.teal),
            const SizedBox(height: 10),
            ...BreathworkPatterns.foundation.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PatternCard(
                    pattern: p,
                    onTap: () => onSelected(p),
                  ),
                )),

            const SizedBox(height: 16),

            // Altered State section
            _buildSectionHeader(
              'ALTERED STATE',
              BioVoltColors.amber,
              showWarningIcon: true,
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: BioVoltColors.amber.withAlpha(30),
                ),
              ),
              padding: const EdgeInsets.all(6),
              child: Column(
                children: BreathworkPatterns.alteredState.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _PatternCard(
                        pattern: p,
                        onTap: () => _handleAlteredStateTap(context, p),
                      ),
                    )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color,
      {bool showWarningIcon = false}) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 2,
          ),
        ),
        if (showWarningIcon) ...[
          const SizedBox(width: 6),
          Icon(Icons.warning_amber_rounded, size: 12, color: color),
        ],
      ],
    );
  }

  void _handleAlteredStateTap(
      BuildContext context, BreathworkPatternInfo pattern) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _SafetyWarningDialog(
        onContinue: () {
          Navigator.of(dialogContext).pop();
          onSelected(pattern);
        },
      ),
    );
  }
}

class _PatternCard extends StatelessWidget {
  final BreathworkPatternInfo pattern;
  final VoidCallback onTap;

  const _PatternCard({required this.pattern, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = pattern.accentColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BioVoltTheme.glassCard(glowColor: color),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        pattern.name,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: BioVoltColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _DifficultyDots(
                        difficulty: pattern.difficulty,
                        color: color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pattern.description,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      color: BioVoltColors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: color.withAlpha(60)),
                  ),
                  child: Text(
                    pattern.label.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                      color: color,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  pattern.estimatedDuration,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyDots extends StatelessWidget {
  final BreathworkDifficulty difficulty;
  final Color color;

  const _DifficultyDots({required this.difficulty, required this.color});

  @override
  Widget build(BuildContext context) {
    final filled = switch (difficulty) {
      BreathworkDifficulty.beginner => 1,
      BreathworkDifficulty.intermediate => 2,
      BreathworkDifficulty.advanced => 3,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < filled ? color : color.withAlpha(30),
          ),
        );
      }),
    );
  }
}

class _SafetyWarningDialog extends StatelessWidget {
  final VoidCallback onContinue;

  const _SafetyWarningDialog({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: BioVoltColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: BioVoltColors.amber.withAlpha(60)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 32,
              color: BioVoltColors.amber,
            ),
            const SizedBox(height: 12),
            Text(
              'ALTERED STATE BREATHWORK',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: BioVoltColors.amber,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 20),
            _warningItem(
              'Advanced breathwork can cause tingling, lightheadedness, '
              'visual changes, and temporary SpO2 drops to 85-90%. '
              'This is normal and temporary.',
            ),
            const SizedBox(height: 12),
            _warningItem(
              'Do this lying down. Do not practice while driving, '
              'in water, or standing.',
            ),
            const SizedBox(height: 12),
            _warningItem(
              'Not recommended for your first time alone. If you feel '
              'distressed, return to normal breathing immediately.',
            ),
            const SizedBox(height: 12),
            _warningItem(
              'If you have epilepsy, cardiovascular conditions, or are '
              'pregnant, do not use altered state breathwork.',
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: BioVoltColors.textSecondary.withAlpha(60),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'CANCEL',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: BioVoltColors.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: onContinue,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: BioVoltColors.amber.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: BioVoltColors.amber.withAlpha(80),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'I UNDERSTAND',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: BioVoltColors.amber,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _warningItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: BioVoltColors.amber.withAlpha(160),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: BioVoltColors.textPrimary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
