import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/session_type.dart';
import '../models/signal_info.dart';

/// Collapsible guidance panel shown during active sessions.
///
/// Displays what to watch for based on the current session type, pulling
/// per-signal guidance from [SignalInfoRegistry].
class SessionGuidancePanel extends StatefulWidget {
  final SessionType sessionType;
  final bool initiallyExpanded;

  const SessionGuidancePanel({
    super.key,
    required this.sessionType,
    this.initiallyExpanded = true,
  });

  @override
  State<SessionGuidancePanel> createState() => _SessionGuidancePanelState();
}

class _SessionGuidancePanelState extends State<SessionGuidancePanel>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late final AnimationController _animController;
  late final Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: _expanded ? 1.0 : 0.0,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.sessionType;
    final guidanceItems = _buildGuidanceItems(type);
    final summary = _sessionSummary(type);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: BioVoltColors.surface.withAlpha(230),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: BioVoltColors.teal.withAlpha(35),
        ),
        boxShadow: [
          BoxShadow(
            color: BioVoltColors.teal.withAlpha(8),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tap header to expand/collapse
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: BioVoltColors.teal,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'GUIDANCE',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: BioVoltColors.teal,
                        letterSpacing: 1.5,
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
            ),
          ),

          // Expandable content
          SizeTransition(
            sizeFactor: _expandAnimation,
            axisAlignment: -1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary tip
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: BioVoltColors.teal.withAlpha(12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      summary,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: BioVoltColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Per-signal guidance
                  ...guidanceItems,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// High-level session tip.
  String _sessionSummary(SessionType type) {
    return switch (type) {
      SessionType.breathwork =>
        'Watch your GSR \u2014 it should be trending downward. HRV should be '
            'rising. If GSR spikes, return focus to breath.',
      SessionType.coldExposure =>
        'Temperature will drop and HR will spike initially. Focus on '
            'controlled breathing. Track how quickly metrics recover after.',
      SessionType.meditation =>
        'GSR is your depth indicator \u2014 look for a steady downward slope. '
            'Coherence builds slowly, give it 10+ minutes.',
      SessionType.grounding =>
        'Watch for gradual GSR decline and temperature warming over '
            '10-20 minutes. Subtle shifts are normal.',
      SessionType.fastingCheck =>
        'Capturing baseline snapshot. Compare these values to previous '
            'fed-state readings for fasting impact.',
    };
  }

  /// Build per-signal guidance rows for the given session type.
  List<Widget> _buildGuidanceItems(SessionType type) {
    final items = <Widget>[];

    for (final signal in SignalInfoRegistry.all) {
      final guidance = signal.guidanceFor(type);
      if (guidance == null) continue;

      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 5),
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: BioVoltColors.textSecondary,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${signal.name}: ',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: BioVoltColors.textPrimary,
                        ),
                      ),
                      TextSpan(
                        text: guidance.description,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: BioVoltColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return items;
  }
}
