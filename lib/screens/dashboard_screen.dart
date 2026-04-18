import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/sensors/sensors_bloc.dart';
import '../bloc/sensors/sensors_event.dart';
import '../bloc/sensors/sensors_state.dart';
import '../config/theme.dart';
import '../models/signal_info.dart';
import '../models/vitals_bookmark.dart';
import '../services/ble_service.dart';
import '../services/firestore_sync.dart';
import '../services/storage_service.dart';
import '../widgets/live_waveform.dart';
import '../widgets/signal_card.dart';
import '../widgets/signal_info_sheet.dart';
import 'template_launcher_screen.dart';

class DashboardScreen extends StatelessWidget {
  final BleService bleService;
  final StorageService _storage = StorageService();

  DashboardScreen({super.key, required this.bleService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BioVoltColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            _buildBookmarkButton(context),
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TemplateLauncherScreen(bleService: bleService),
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
  // -------------------------------------------------------------------------
  // Vitals bookmark
  // -------------------------------------------------------------------------

  Widget _buildBookmarkButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showBookmarkSheet(context),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: BioVoltColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: BioVoltColors.cardBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.bookmark_add_rounded,
                size: 14, color: BioVoltColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              'Quick vitals bookmark',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: BioVoltColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              'TAP \u2192',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: BioVoltColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBookmarkSheet(BuildContext context) {
    final state = context.read<SensorsBloc>().state;

    final currentHr = state.heartRate;
    final currentHrv = state.hrv;
    final currentGsr = state.gsr;
    final currentTemp = state.temperature;
    final currentSpo2 = state.spo2;

    final noteCtrl = TextEditingController();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: const BoxDecoration(
            color: BioVoltColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: BioVoltColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title
              Text(
                'VITALS BOOKMARK',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: BioVoltColors.teal,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatBookmarkTime(DateTime.now()),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: BioVoltColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),

              // Vitals snapshot chips
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (currentHr > 0)
                    _snapshotChip(
                        'HR', '${currentHr.toStringAsFixed(0)} bpm'),
                  if (currentHrv > 0)
                    _snapshotChip(
                        'HRV', '${currentHrv.toStringAsFixed(0)} ms'),
                  if (currentGsr > 0)
                    _snapshotChip(
                        'GSR', '${currentGsr.toStringAsFixed(1)} \u00B5S'),
                  if (currentSpo2 > 0)
                    _snapshotChip(
                        'SpO2', '${currentSpo2.toStringAsFixed(0)}%'),
                  if (currentTemp > 0)
                    _snapshotChip(
                        'Temp', '${currentTemp.toStringAsFixed(1)}\u00B0F'),
                  if (currentHr == 0)
                    _snapshotChip('Sensor', 'No live data'),
                ],
              ),
              const SizedBox(height: 16),

              // Note field
              TextField(
                controller: noteCtrl,
                autofocus: true,
                maxLines: 3,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: BioVoltColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'What are you noticing? '
                      '(optional \u2014 bookmark saves without a note)',
                  hintStyle: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: BioVoltColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: BioVoltColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: BioVoltColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: BioVoltColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: BioVoltColors.teal),
                  ),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
              const SizedBox(height: 16),

              // Save button
              GestureDetector(
                onTap: saving
                    ? null
                    : () async {
                        setSheetState(() => saving = true);
                        final now = DateTime.now();
                        final bookmark = VitalsBookmark(
                          id: now.millisecondsSinceEpoch.toString(),
                          timestamp: now,
                          note: noteCtrl.text.trim().isEmpty
                              ? null
                              : noteCtrl.text.trim(),
                          hrBpm: currentHr > 0 ? currentHr : null,
                          hrvMs: currentHrv > 0 ? currentHrv : null,
                          gsrUs: currentGsr > 0 ? currentGsr : null,
                          skinTempF: currentTemp > 0 ? currentTemp : null,
                          spo2Percent:
                              currentSpo2 > 0 ? currentSpo2 : null,
                        );
                        await _storage.saveBookmark(bookmark);
                        unawaited(FirestoreSync().writeBookmark(bookmark));
                        if (ctx.mounted) Navigator.of(ctx).pop();

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Bookmark saved \u2014 ${_formatBookmarkTime(now)}',
                                style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11),
                              ),
                              backgroundColor: BioVoltColors.surface,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: BioVoltColors.teal.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: BioVoltColors.teal.withAlpha(120), width: 2),
                  ),
                  alignment: Alignment.center,
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: BioVoltColors.teal))
                      : Text(
                          'SAVE BOOKMARK \u2192',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: BioVoltColors.teal,
                            letterSpacing: 2,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _snapshotChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: BioVoltColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: BioVoltColors.cardBorder),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label  ',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: BioVoltColors.textSecondary,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: BioVoltColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBookmarkTime(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final period = t.hour < 12 ? 'am' : 'pm';
    final min = t.minute.toString().padLeft(2, '0');
    return '${t.month}/${t.day}  $h:$min $period';
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
