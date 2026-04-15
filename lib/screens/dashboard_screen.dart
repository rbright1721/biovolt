import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/sensors/sensors_bloc.dart';
import '../bloc/sensors/sensors_event.dart';
import '../bloc/sensors/sensors_state.dart';
import '../bloc/session/session_bloc.dart';
import '../bloc/session/session_event.dart';
import '../models/session_type.dart';
import '../widgets/pattern_selector.dart';
import '../config/theme.dart';
import '../services/ble_service.dart';
import '../models/signal_info.dart';
import '../widgets/live_waveform.dart';
import '../widgets/session_type_sheet.dart';
import '../widgets/signal_card.dart';
import '../widgets/signal_info_sheet.dart';
import 'session_screen.dart';

class DashboardScreen extends StatelessWidget {
  final BleService bleService;

  const DashboardScreen({super.key, required this.bleService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BioVoltColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildWaveformStrip(context),
                    const SizedBox(height: 16),
                    _buildVitalCards(context),
                    const SizedBox(height: 16),
                    _buildSecondaryMetrics(context),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSessionSelector(context),
        child: const Icon(Icons.play_arrow_rounded, size: 32),
      ),
    );
  }

  void _showSessionSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SessionTypeSheet(
        onSelected: (type) {
          if (type == SessionType.breathwork) {
            _showPatternSelector(context);
          } else {
            _startSession(context, type);
          }
        },
      ),
    );
  }

  void _showPatternSelector(BuildContext context) async {
    final pattern = await PatternSelector.show(context);
    if (pattern == null || !context.mounted) return;

    final bloc = context.read<SessionBloc>();
    bloc.add(SessionTypeSelected(SessionType.breathwork));
    bloc.add(BreathworkPatternSelected(pattern.id));
    bloc.add(SessionStarted());
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: SessionScreen(bleService: bleService),
        ),
      ),
    );
  }

  void _startSession(BuildContext context, SessionType type) {
    final bloc = context.read<SessionBloc>();
    bloc.add(SessionTypeSelected(type));
    bloc.add(SessionStarted());
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: SessionScreen(bleService: bleService),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return BlocBuilder<SensorsBloc, SensorsState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            children: [
              Text(
                'BIOVOLT',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: BioVoltColors.teal,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: state.isConnected
                      ? BioVoltColors.teal
                      : BioVoltColors.coral,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (state.isConnected
                          ? BioVoltColors.teal
                          : BioVoltColors.coral)
                          .withAlpha(120),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                state.isConnected ? 'LIVE' : 'SCANNING...',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: state.isConnected
                      ? BioVoltColors.teal
                      : BioVoltColors.amber,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.battery_5_bar_rounded,
                color: BioVoltColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                '${state.batteryPercent}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWaveformStrip(BuildContext context) {
    return GestureDetector(
      onTap: () => SignalInfoSheet.show(
        context,
        info: SignalInfoRegistry.ecg,
        currentValue: 0,
      ),
      child: Container(
        height: 200,
        decoration: BioVoltTheme.glassCard(glowColor: BioVoltColors.teal),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'PPG',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: BioVoltColors.teal,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'RED CHANNEL',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: BioVoltColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  'MAX30102',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    color: BioVoltColors.textSecondary.withAlpha(120),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: BioVoltColors.textSecondary.withAlpha(140),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: LiveWaveform(
                dataStream: bleService.ecgStream,
                lineColor: BioVoltColors.teal,
                strokeWidth: 2,
                maxPoints: 300,
                minY: 0,
                maxY: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalCards(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: [
        SignalCard(
          label: 'Heart Rate',
          unit: 'BPM',
          valueStream: bleService.heartRateStream,
          accentColor: BioVoltColors.teal,
          showPulse: true,
          formatValue: (v) => v.toStringAsFixed(0),
          getStatus: (v) {
            if (v < 55 || v > 90) return SignalStatus.warning;
            if (v < 60 || v > 80) return SignalStatus.moderate;
            return SignalStatus.good;
          },
          onInfoTap: (v) => SignalInfoSheet.show(
            context, info: SignalInfoRegistry.heartRate, currentValue: v,
          ),
        ),
        BlocBuilder<SensorsBloc, SensorsState>(
          buildWhen: (prev, curr) => prev.hrvSource != curr.hrvSource,
          builder: (context, sensorState) {
            final isEcg = sensorState.hrvSource == HrvSource.ecg;
            return SignalCard(
              label: 'HRV RMSSD',
              unit: 'ms',
              valueStream: bleService.hrvStream,
              accentColor: BioVoltColors.teal,
              formatValue: (v) => v.toStringAsFixed(1),
              getStatus: (v) {
                if (v < 25) return SignalStatus.warning;
                if (v < 35) return SignalStatus.moderate;
                return SignalStatus.good;
              },
              onInfoTap: (v) => SignalInfoSheet.show(
                context, info: SignalInfoRegistry.hrv, currentValue: v,
              ),
              labelTrailing: _HrvSourceBadge(isEcg: isEcg),
            );
          },
        ),
        SignalCard(
          label: 'GSR',
          unit: '\u00B5S',
          valueStream: bleService.gsrStream,
          accentColor: BioVoltColors.amber,
          formatValue: (v) => v.toStringAsFixed(2),
          getStatus: (v) {
            if (v > 6) return SignalStatus.warning;
            if (v > 4.5) return SignalStatus.moderate;
            return SignalStatus.good;
          },
          onInfoTap: (v) => SignalInfoSheet.show(
            context, info: SignalInfoRegistry.gsr, currentValue: v,
          ),
        ),
        SignalCard(
          label: 'Temperature',
          unit: '\u00B0F',
          valueStream: bleService.temperatureStream,
          accentColor: BioVoltColors.coral,
          formatValue: (v) => v.toStringAsFixed(1),
          getStatus: (v) {
            if (v < 96.0 || v > 99.0) return SignalStatus.warning;
            return SignalStatus.good;
          },
          onInfoTap: (v) => SignalInfoSheet.show(
            context, info: SignalInfoRegistry.temperature, currentValue: v,
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryMetrics(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SecondaryMetricCard(
            label: 'SpO2',
            unit: '%',
            stream: bleService.spo2Stream,
            color: BioVoltColors.teal,
            format: (v) => v.toStringAsFixed(0),
            signalInfo: SignalInfoRegistry.spo2,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SecondaryMetricCard(
            label: 'LF/HF',
            unit: 'ratio',
            stream: bleService.lfHfStream,
            color: BioVoltColors.amber,
            format: (v) => v.toStringAsFixed(2),
            signalInfo: SignalInfoRegistry.lfHf,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SecondaryMetricCard(
            label: 'Coherence',
            unit: 'score',
            stream: bleService.coherenceStream,
            color: BioVoltColors.teal,
            format: (v) => v.toStringAsFixed(0),
            signalInfo: SignalInfoRegistry.coherence,
          ),
        ),
      ],
    );
  }
}

class _HrvSourceBadge extends StatelessWidget {
  final bool isEcg;
  const _HrvSourceBadge({required this.isEcg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: (isEcg ? BioVoltColors.teal : BioVoltColors.amber).withAlpha(25),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: (isEcg ? BioVoltColors.teal : BioVoltColors.amber).withAlpha(80),
        ),
      ),
      child: Text(
        isEcg ? 'ECG' : 'PPG',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: isEcg ? BioVoltColors.teal : BioVoltColors.amber,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SecondaryMetricCard extends StatefulWidget {
  final String label;
  final String unit;
  final Stream<double> stream;
  final Color color;
  final String Function(double) format;
  final SignalInfo? signalInfo;

  const _SecondaryMetricCard({
    required this.label,
    required this.unit,
    required this.stream,
    required this.color,
    required this.format,
    this.signalInfo,
  });

  @override
  State<_SecondaryMetricCard> createState() => _SecondaryMetricCardState();
}

class _SecondaryMetricCardState extends State<_SecondaryMetricCard> {
  double _value = 0;
  late final StreamSubscription<double> _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.stream.listen((v) {
      setState(() => _value = v);
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.signalInfo != null
          ? () => SignalInfoSheet.show(
        context,
        info: widget.signalInfo!,
        currentValue: _value,
      )
          : null,
      child: Container(
        decoration: BioVoltTheme.glassCard(glowColor: widget.color),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    widget.label.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.signalInfo != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.info_outline_rounded,
                    size: 10,
                    color: BioVoltColors.textSecondary.withAlpha(140),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.format(_value),
              style: BioVoltTheme.valueStyle(24, color: widget.color),
            ),
            const SizedBox(height: 4),
            Text(
              widget.unit,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: BioVoltColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
