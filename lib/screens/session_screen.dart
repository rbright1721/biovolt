import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/session/session_bloc.dart';
import '../bloc/session/session_event.dart';
import '../bloc/session/session_state.dart';
import '../config/theme.dart';
import '../models/breathwork_pattern.dart';
import '../models/session.dart';
import '../services/mock_data_service.dart';
import '../widgets/breathing_pacer.dart';
import '../widgets/live_waveform.dart';
import '../widgets/session_guidance.dart';
import '../widgets/signal_card.dart';
import '../widgets/spo2_safety_monitor.dart';
import '../widgets/wim_hof_pacer.dart';

class SessionScreen extends StatelessWidget {
  final MockDataService mockDataService;

  const SessionScreen({super.key, required this.mockDataService});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, state) {
        if (state.activeSession == null) {
          return const Scaffold(
            backgroundColor: BioVoltColors.background,
            body: Center(child: Text('No active session')),
          );
        }

        final patternInfo = state.breathworkPatternId != null
            ? BreathworkPatterns.byId(state.breathworkPatternId!)
            : null;
        final isAlteredState = patternInfo?.isAlteredState ?? false;

        return Scaffold(
          backgroundColor: BioVoltColors.background,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, state),
                SessionGuidancePanel(
                  sessionType: state.activeSession!.type,
                  initiallyExpanded: true,
                ),
                if (isAlteredState)
                  Spo2SafetyMonitor(spo2Stream: mockDataService.spo2Stream),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        _buildMainContent(context, state),
                        if (_showsEcgWaveform(state.activeSession!.type)) ...[
                          const SizedBox(height: 16),
                          _buildSessionEcgStrip(),
                        ],
                        const SizedBox(height: 24),
                        _buildFocusCards(state),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
                _buildControls(context, state),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, SessionState state) {
    final session = state.activeSession!;
    final elapsed = state.elapsed;
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');

    final patternInfo = state.breathworkPatternId != null
        ? BreathworkPatterns.byId(state.breathworkPatternId!)
        : null;
    final accentColor = patternInfo?.accentColor ?? BioVoltColors.teal;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: BioVoltColors.textSecondary),
            onPressed: () {
              context.read<SessionBloc>().add(SessionStopped());
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patternInfo?.name.toUpperCase() ??
                      session.type.displayName.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                    letterSpacing: 2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  session.type.focusSignals,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Elapsed timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: BioVoltColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: BioVoltColors.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: state.status == SessionStatus.active
                        ? BioVoltColors.coral
                        : BioVoltColors.amber,
                    boxShadow: [
                      if (state.status == SessionStatus.active)
                        BoxShadow(
                          color: BioVoltColors.coral.withAlpha(120),
                          blurRadius: 6,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$minutes:$seconds',
                  style: BioVoltTheme.valueStyle(18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, SessionState state) {
    final type = state.activeSession!.type;

    switch (type) {
      case SessionType.breathwork:
        return _buildBreathworkContent(state);
      case SessionType.coldExposure:
        return _buildColdExposureContent();
      case SessionType.meditation:
        return _buildMeditationContent();
      case SessionType.fastingCheck:
        return _buildFastingContent();
      case SessionType.grounding:
        return _buildGroundingContent();
    }
  }

  Widget _buildBreathworkContent(SessionState state) {
    final patternId = state.breathworkPatternId ?? 'box4';

    return switch (patternId) {
      'wimHof' => _buildWimHofContent(state),
      'holotropic' => _buildHolotropicContent(state),
      'tummo' => _buildTummoContent(),
      'relaxing478' => _buildFoundationContent(
          BreathingPattern.relaxing478, 'RELAXING  4-7-8'),
      'coherence' => _buildFoundationContent(
          BreathingPattern.coherence, 'COHERENCE  5-5'),
      _ => _buildFoundationContent(
          BreathingPattern.box4, 'BOX BREATHING  4-4-4-4'),
    };
  }

  Widget _buildFoundationContent(BreathingPattern pattern, String label) {
    return Column(
      children: [
        const SizedBox(height: 20),
        BreathingPacer(
          pattern: pattern,
          size: 240,
        ),
        const SizedBox(height: 16),
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: BioVoltColors.textSecondary,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildWimHofContent(SessionState state) {
    return Column(
      children: [
        const SizedBox(height: 10),
        WimHofPacer(
          size: 240,
          totalRounds: 3,
          rapidCycles: 30,
          spo2Stream: mockDataService.spo2Stream,
        ),
      ],
    );
  }

  Widget _buildHolotropicContent(SessionState state) {
    return Column(
      children: [
        const SizedBox(height: 10),
        HolotropicPacer(
          size: 240,
          sessionElapsed: state.elapsed,
          totalDuration: const Duration(minutes: 25),
          slowdownMinutes: 5,
        ),
        const SizedBox(height: 12),
        Text(
          'HOLOTROPIC BREATHWORK',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: BioVoltColors.textSecondary,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildTummoContent() {
    return Column(
      children: [
        const SizedBox(height: 20),
        BreathingPacer(
          pattern: BreathingPattern.tummo,
          size: 240,
          accentColor: BioVoltColors.amber,
          subtitleLabel: 'NOSE IN \u2022 MOUTH OUT \u2022 ENGAGE CORE',
        ),
        const SizedBox(height: 16),
        Text(
          'TUMMO BREATHING  2-2',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: BioVoltColors.amber.withAlpha(160),
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildColdExposureContent() {
    return _LargeMetricDisplay(
      stream: mockDataService.temperatureStream,
      label: 'BODY TEMPERATURE',
      unit: '\u00B0F',
      color: BioVoltColors.coral,
      format: (v) => v.toStringAsFixed(1),
    );
  }

  Widget _buildMeditationContent() {
    return _LargeMetricDisplay(
      stream: mockDataService.gsrStream,
      label: 'SKIN CONDUCTANCE',
      unit: '\u00B5S',
      color: BioVoltColors.amber,
      format: (v) => v.toStringAsFixed(2),
    );
  }

  Widget _buildFastingContent() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BioVoltTheme.glassCard(glowColor: BioVoltColors.teal),
          child: Column(
            children: [
              Text(
                'CAPTURING BASELINE',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: BioVoltColors.teal,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Recording all signals for comparison',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: BioVoltColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGroundingContent() {
    return _LargeMetricDisplay(
      stream: mockDataService.gsrStream,
      label: 'GSR TRACKING',
      unit: '\u00B5S',
      color: BioVoltColors.amber,
      format: (v) => v.toStringAsFixed(2),
    );
  }

  bool _showsEcgWaveform(SessionType type) {
    return type == SessionType.breathwork ||
        type == SessionType.coldExposure ||
        type == SessionType.meditation;
  }

  Widget _buildSessionEcgStrip() {
    return Container(
      height: 120,
      decoration: BioVoltTheme.glassCard(glowColor: BioVoltColors.teal),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'ECG',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: BioVoltColors.teal,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'LEAD I',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 8,
                  color: BioVoltColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: LiveWaveform(
              dataStream: mockDataService.ecgStream,
              lineColor: BioVoltColors.teal,
              strokeWidth: 1.5,
              maxPoints: 200,
              minY: -0.4,
              maxY: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusCards(SessionState state) {
    final type = state.activeSession!.type;

    final cards = switch (type) {
      SessionType.breathwork => [
          _focusCard('HRV RMSSD', 'ms', mockDataService.hrvStream,
              BioVoltColors.teal, (v) => v.toStringAsFixed(1)),
          _focusCard('GSR', '\u00B5S', mockDataService.gsrStream,
              BioVoltColors.amber, (v) => v.toStringAsFixed(2)),
        ],
      SessionType.coldExposure => [
          _focusCard('Temperature', '\u00B0F', mockDataService.temperatureStream,
              BioVoltColors.coral, (v) => v.toStringAsFixed(1)),
          _focusCard('HRV RMSSD', 'ms', mockDataService.hrvStream,
              BioVoltColors.teal, (v) => v.toStringAsFixed(1)),
        ],
      SessionType.meditation => [
          _focusCard('GSR', '\u00B5S', mockDataService.gsrStream,
              BioVoltColors.amber, (v) => v.toStringAsFixed(2)),
          _focusCard('Coherence', 'score', mockDataService.coherenceStream,
              BioVoltColors.teal, (v) => v.toStringAsFixed(0)),
        ],
      SessionType.fastingCheck => [
          _focusCard('Heart Rate', 'BPM', mockDataService.heartRateStream,
              BioVoltColors.teal, (v) => v.toStringAsFixed(0)),
          _focusCard('HRV RMSSD', 'ms', mockDataService.hrvStream,
              BioVoltColors.teal, (v) => v.toStringAsFixed(1)),
        ],
      SessionType.grounding => [
          _focusCard('GSR', '\u00B5S', mockDataService.gsrStream,
              BioVoltColors.amber, (v) => v.toStringAsFixed(2)),
          _focusCard('Temperature', '\u00B0F', mockDataService.temperatureStream,
              BioVoltColors.coral, (v) => v.toStringAsFixed(1)),
        ],
    };

    return Row(
      children: [
        Expanded(child: SizedBox(height: 160, child: cards[0])),
        const SizedBox(width: 12),
        Expanded(child: SizedBox(height: 160, child: cards[1])),
      ],
    );
  }

  Widget _focusCard(String label, String unit, Stream<double> stream,
      Color color, String Function(double) format) {
    return SignalCard(
      label: label,
      unit: unit,
      valueStream: stream,
      accentColor: color,
      formatValue: format,
    );
  }

  Widget _buildControls(BuildContext context, SessionState state) {
    final bloc = context.read<SessionBloc>();
    final isActive = state.status == SessionStatus.active;
    final isPaused = state.status == SessionStatus.paused;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: BioVoltColors.surface,
        border: Border(
          top: BorderSide(color: BioVoltColors.cardBorder),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Pause / Resume
          _ControlButton(
            icon: isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
            label: isActive ? 'PAUSE' : 'RESUME',
            color: BioVoltColors.amber,
            onTap: () {
              if (isActive) {
                bloc.add(SessionPaused());
              } else if (isPaused) {
                bloc.add(SessionResumed());
              }
            },
          ),
          const SizedBox(width: 32),
          // Stop
          _ControlButton(
            icon: Icons.stop_rounded,
            label: 'STOP',
            color: BioVoltColors.coral,
            onTap: () {
              bloc.add(SessionStopped());
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withAlpha(25),
              border: Border.all(color: color.withAlpha(80), width: 2),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _LargeMetricDisplay extends StatefulWidget {
  final Stream<double> stream;
  final String label;
  final String unit;
  final Color color;
  final String Function(double) format;

  const _LargeMetricDisplay({
    required this.stream,
    required this.label,
    required this.unit,
    required this.color,
    required this.format,
  });

  @override
  State<_LargeMetricDisplay> createState() => _LargeMetricDisplayState();
}

class _LargeMetricDisplayState extends State<_LargeMetricDisplay> {
  double _value = 0;
  late final _sub = widget.stream.listen((v) => setState(() => _value = v));

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 30),
        Text(
          widget.label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: BioVoltColors.textSecondary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.format(_value),
          style: BioVoltTheme.valueStyle(64, color: widget.color),
        ),
        Text(
          widget.unit,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 16,
            color: BioVoltColors.textSecondary,
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}
