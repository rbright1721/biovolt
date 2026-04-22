import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bloc/sensors/sensors_bloc.dart';
import '../bloc/sensors/sensors_state.dart';
import '../config/theme.dart';
import '../models/log_entry.dart';
import '../services/firestore_sync.dart';
import '../services/storage_service.dart';

/// Bottom sheet for capturing a raw user observation as a [LogEntry].
///
/// Intentionally kept dumb: no classification, no intent detection,
/// no AI. The classifier worker (Part 2) upgrades the entry's type
/// out-of-band after save. Vitals are snapshotted at tap time from
/// the live [SensorsBloc] state using the same `> 0 ? value : null`
/// predicate the existing bookmark sheet uses.
class LogEntrySheet extends StatefulWidget {
  const LogEntrySheet({
    super.key,
    this.storage,
    this.firestoreSync,
  });

  /// Tests can inject fakes. Defaults to the singletons.
  final StorageService? storage;
  final FirestoreSync? firestoreSync;

  /// Convenience wrapper. Uses the same modal shape the bookmark
  /// sheet uses so the two feel identical.
  static Future<void> show(
    BuildContext context, {
    StorageService? storage,
    FirestoreSync? firestoreSync,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => LogEntrySheet(
        storage: storage,
        firestoreSync: firestoreSync,
      ),
    );
  }

  @override
  State<LogEntrySheet> createState() => _LogEntrySheetState();
}

class _LogEntrySheetState extends State<LogEntrySheet> {
  final _textCtrl = TextEditingController();
  bool _saving = false;
  late final SensorsState _openState;

  StorageService get _storage => widget.storage ?? StorageService();
  FirestoreSync get _sync => widget.firestoreSync ?? FirestoreSync();

  @override
  void initState() {
    super.initState();
    // Snapshot sensor state at open time — matches the bookmark sheet's
    // `context.read<SensorsBloc>().state` pattern. A modal capture flow
    // shouldn't churn as the live stream ticks; the value the user saw
    // when they tapped "Log" is what gets saved.
    _openState = context.read<SensorsBloc>().state;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sensorState = _openState;

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: BioVoltColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle — matches bookmark sheet.
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

          Text(
            'LOG SOMETHING',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: BioVoltColors.teal,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTime(DateTime.now()),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: BioVoltColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),

          // Free-text input.
          TextField(
            key: const Key('log_entry_sheet_text_field'),
            controller: _textCtrl,
            autofocus: true,
            maxLines: 4,
            maxLength: 500,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              color: BioVoltColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText:
                  "What happened? e.g. 'took 250mcg BPC-157', 'just "
                  "ate eggs', 'feeling wired'",
              hintStyle: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: BioVoltColors.textSecondary,
              ),
              filled: true,
              fillColor: BioVoltColors.background,
              border: _fieldBorder(BioVoltColors.cardBorder),
              enabledBorder: _fieldBorder(BioVoltColors.cardBorder),
              focusedBorder: _fieldBorder(BioVoltColors.teal),
              contentPadding: const EdgeInsets.all(10),
              counterStyle: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                color: BioVoltColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Live vitals preview — shows what will be snapshotted.
          Text(
            'VITALS SNAPSHOT',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: BioVoltColors.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _buildVitalChips(sensorState),
          ),
          const SizedBox(height: 18),

          // Actions row.
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  key: const Key('log_entry_sheet_cancel_button'),
                  label: 'CANCEL',
                  color: BioVoltColors.textSecondary,
                  onTap: _saving ? null : () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _actionButton(
                  key: const Key('log_entry_sheet_log_button'),
                  label: _saving ? '...' : 'LOG →',
                  color: BioVoltColors.teal,
                  filled: true,
                  onTap: _saving ? null : () => _save(sensorState),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildVitalChips(SensorsState s) {
    String fmt(double v, int d) => v.toStringAsFixed(d);
    return [
      _chip('HR', s.heartRate > 0 ? '${fmt(s.heartRate, 0)} bpm' : '—'),
      _chip('HRV', s.hrv > 0 ? '${fmt(s.hrv, 0)} ms' : '—'),
      _chip('GSR', s.gsr > 0 ? '${fmt(s.gsr, 1)} µS' : '—'),
      _chip('SkinT',
          s.temperature > 0 ? '${fmt(s.temperature, 1)}°F' : '—'),
      _chip('SpO2', s.spo2 > 0 ? '${fmt(s.spo2, 0)}%' : '—'),
    ];
  }

  Future<void> _save(SensorsState s) async {
    setState(() => _saving = true);

    final now = DateTime.now();
    final entry = LogEntry(
      id: now.millisecondsSinceEpoch.toString(),
      rawText: _textCtrl.text.trim(),
      // The factory resolves them to the same instant when both come in
      // as the same DateTime reference, keeping audit vs. user-visible
      // timestamps aligned for fresh entries.
      occurredAt: now,
      loggedAt: now,
      // Classifier worker (Part 2) upgrades these.
      type: 'other',
      classificationStatus: 'pending',
      hrBpm: s.heartRate > 0 ? s.heartRate : null,
      hrvMs: s.hrv > 0 ? s.hrv : null,
      gsrUs: s.gsr > 0 ? s.gsr : null,
      skinTempF: s.temperature > 0 ? s.temperature : null,
      spo2Percent: s.spo2 > 0 ? s.spo2 : null,
      // ecgHrBpm and protocolIdAtTime intentionally null for now —
      // SensorsState doesn't expose a dedicated ECG-derived HR, and
      // active-protocol inference lands in Part 2 via ContextInferrer.
    );

    await _storage.saveLogEntry(entry);
    unawaited(_sync.writeLogEntry(entry));

    if (!mounted) return;
    Navigator.of(context).pop();

    // Fire-and-forget toast on the host context. Use the rootMessenger
    // so it outlives the sheet's context disposal.
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          'Logged — ${_formatTime(now)}',
          style: GoogleFonts.jetBrainsMono(fontSize: 11),
        ),
        backgroundColor: BioVoltColors.surface,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color),
      );

  Widget _chip(String label, String value) {
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

  Widget _actionButton({
    required Key key,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: filled ? color.withAlpha(20) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: filled ? color.withAlpha(120) : BioVoltColors.cardBorder,
            width: filled ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final period = t.hour < 12 ? 'am' : 'pm';
    final min = t.minute.toString().padLeft(2, '0');
    return '${t.month}/${t.day}  $h:$min $period';
  }
}
