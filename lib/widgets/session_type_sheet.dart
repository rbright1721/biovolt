import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/session.dart';

/// Bottom sheet for selecting a session type.
class SessionTypeSheet extends StatelessWidget {
  final void Function(SessionType) onSelected;

  const SessionTypeSheet({super.key, required this.onSelected});

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
          // Handle bar
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
            'START SESSION',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: BioVoltColors.teal,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 20),
          ...SessionType.values.map((type) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SessionTypeCard(
                  type: type,
                  onTap: () {
                    Navigator.of(context).pop();
                    onSelected(type);
                  },
                ),
              )),
        ],
      ),
    ),
    );
  }
}

class _SessionTypeCard extends StatelessWidget {
  final SessionType type;
  final VoidCallback onTap;

  const _SessionTypeCard({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BioVoltTheme.glassCard(glowColor: BioVoltColors.teal),
        child: Row(
          children: [
            // Icon area
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: BioVoltColors.teal.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: BioVoltColors.teal.withAlpha(30),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                type.iconChar,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.displayName,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: BioVoltColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    type.description,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: BioVoltColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Duration + signals
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  type.estimatedDuration,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: BioVoltColors.teal,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  type.focusSignals,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    color: BioVoltColors.textSecondary,
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
