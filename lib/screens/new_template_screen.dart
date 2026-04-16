import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/session_template.dart';
import '../services/ble_service.dart';
import '../services/storage_service.dart';
import 'confirm_context_screen.dart';

// ---------------------------------------------------------------------------
// Activity definitions (same 9 types as TemplateLauncherScreen)
// ---------------------------------------------------------------------------

class _ActivityDef {
  final String id;
  final String label;
  final String icon;

  const _ActivityDef(this.id, this.label, this.icon);
}

const _activities = [
  _ActivityDef('breathwork', 'Breathwork', '\u{1F32C}'),
  _ActivityDef('coldExposure', 'Cold Plunge', '\u{2744}'),
  _ActivityDef('sauna', 'Sauna', '\u{1F525}'),
  _ActivityDef('meditation', 'Meditation', '\u{1F9D8}'),
  _ActivityDef('workout', 'Workout', '\u{1F4AA}'),
  _ActivityDef('redLight', 'Red Light', '\u{26A1}'),
  _ActivityDef('grounding', 'Grounding', '\u{1F30D}'),
  _ActivityDef('rest', 'Rest/HRV', '\u{1F634}'),
  _ActivityDef('other', 'Other', '\u{1F4E6}'),
];

// ---------------------------------------------------------------------------
// NewTemplateScreen
// ---------------------------------------------------------------------------

class NewTemplateScreen extends StatefulWidget {
  final BleService bleService;
  final String? preselectedSessionType;

  const NewTemplateScreen({
    super.key,
    required this.bleService,
    this.preselectedSessionType,
  });

  @override
  State<NewTemplateScreen> createState() => _NewTemplateScreenState();
}

class _NewTemplateScreenState extends State<NewTemplateScreen> {
  String _name = '';
  String _sessionType = 'breathwork';
  String? _breathworkPattern;
  int _breathworkRounds = 3;
  int _breathHoldTargetSec = 30;
  String _notes = '';
  bool _saving = false;

  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _coldTempCtrl = TextEditingController();
  final _coldDurationCtrl = TextEditingController();
  final _breathRoundsCtrl = TextEditingController(text: '3');
  final _breathHoldCtrl = TextEditingController(text: '30');

  @override
  void initState() {
    super.initState();
    _sessionType = widget.preselectedSessionType ?? 'breathwork';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    _coldTempCtrl.dispose();
    _coldDurationCtrl.dispose();
    _breathRoundsCtrl.dispose();
    _breathHoldCtrl.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BioVoltColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 12),
            _buildHeader(),
            const SizedBox(height: 24),

            // Template name
            _sectionLabel('TEMPLATE NAME'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _nameCtrl,
              hintText: 'e.g. Wim Hof fasted morning',
              onChanged: (v) => setState(() => _name = v.trim()),
            ),
            const SizedBox(height: 20),

            // Session type
            _sectionLabel('SESSION TYPE'),
            const SizedBox(height: 8),
            _buildSessionTypeChips(),
            const SizedBox(height: 20),

            // Conditional breathwork options
            if (_sessionType == 'breathwork') ...[
              _sectionLabel('BREATHWORK PATTERN'),
              const SizedBox(height: 8),
              _buildBreathworkOptions(),
              const SizedBox(height: 20),
            ],

            // Conditional cold exposure options
            if (_sessionType == 'coldExposure') ...[
              _sectionLabel('COLD EXPOSURE'),
              const SizedBox(height: 8),
              _buildColdOptions(),
              const SizedBox(height: 20),
            ],

            // Notes
            _sectionLabel('NOTES'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _notesCtrl,
              hintText: 'Optional notes for this template...',
              maxLines: 3,
              onChanged: (v) => setState(() => _notes = v.trim()),
            ),
            const SizedBox(height: 32),

            // Save button
            _buildSaveButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Header
  // -------------------------------------------------------------------------

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(Icons.chevron_left_rounded,
                color: BioVoltColors.textSecondary, size: 28),
          ),
        ),
        Expanded(
          child: Text(
            'NEW TEMPLATE',
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: BioVoltColors.teal,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(width: 40),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Session type chips
  // -------------------------------------------------------------------------

  Widget _buildSessionTypeChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _activities.map((a) {
        final selected = _sessionType == a.id;
        return GestureDetector(
          onTap: () => setState(() => _sessionType = a.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? BioVoltColors.teal.withAlpha(20)
                  : BioVoltColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? BioVoltColors.teal.withAlpha(100)
                    : BioVoltColors.cardBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(a.icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  a.label,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? BioVoltColors.teal
                        : BioVoltColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // -------------------------------------------------------------------------
  // Breathwork options
  // -------------------------------------------------------------------------

  Widget _buildBreathworkOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in [
              ('Wim Hof', 'wim_hof'),
              ('Box breathing', 'box'),
              ('4-7-8', '4-7-8'),
              ('Tummo', 'tummo'),
            ])
              _chip(entry.$1,
                  selected: _breathworkPattern == entry.$2,
                  onTap: () =>
                      setState(() => _breathworkPattern = entry.$2)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSmallField(
                controller: _breathRoundsCtrl,
                label: 'Rounds',
                onChanged: (v) =>
                    _breathworkRounds = int.tryParse(v) ?? _breathworkRounds,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSmallField(
                controller: _breathHoldCtrl,
                label: 'Hold target (sec)',
                onChanged: (v) => _breathHoldTargetSec =
                    int.tryParse(v) ?? _breathHoldTargetSec,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Cold exposure options
  // -------------------------------------------------------------------------

  Widget _buildColdOptions() {
    return Row(
      children: [
        Expanded(
          child: _buildSmallField(
            controller: _coldTempCtrl,
            label: 'Temp (\u00B0F)',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSmallField(
            controller: _coldDurationCtrl,
            label: 'Duration (min)',
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Save button
  // -------------------------------------------------------------------------

  Widget _buildSaveButton() {
    final enabled = _name.isNotEmpty && !_saving;

    return GestureDetector(
      onTap: enabled ? _saveTemplate : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: enabled
              ? BioVoltColors.teal.withAlpha(20)
              : BioVoltColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled
                ? BioVoltColors.teal
                : BioVoltColors.cardBorder,
            width: enabled ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: _saving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: BioVoltColors.teal),
              )
            : Text(
                'SAVE TEMPLATE \u2192',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: enabled
                      ? BioVoltColors.teal
                      : BioVoltColors.textSecondary,
                  letterSpacing: 2,
                ),
              ),
      ),
    );
  }

  Future<void> _saveTemplate() async {
    setState(() => _saving = true);

    final template = SessionTemplate(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _name,
      sessionType: _sessionType,
      breathworkPattern:
          _sessionType == 'breathwork' ? _breathworkPattern : null,
      breathworkRounds:
          _sessionType == 'breathwork' ? _breathworkRounds : null,
      breathHoldTargetSec:
          _sessionType == 'breathwork' ? _breathHoldTargetSec : null,
      coldTempF: _sessionType == 'coldExposure'
          ? double.tryParse(_coldTempCtrl.text)
          : null,
      coldDurationMin: _sessionType == 'coldExposure'
          ? int.tryParse(_coldDurationCtrl.text)
          : null,
      notes: _notes.isEmpty ? null : _notes,
      lastUsedAt: DateTime.now(),
      useCount: 0,
    );

    await StorageService().saveTemplate(template);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ConfirmContextScreen(
          bleService: widget.bleService,
          template: template,
          sessionType: null,
          repeatSession: null,
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Shared helpers
  // -------------------------------------------------------------------------

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

  Widget _chip(String label,
      {required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? BioVoltColors.teal.withAlpha(20)
              : BioVoltColors.surface,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        color: BioVoltColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          color: BioVoltColors.textSecondary.withAlpha(120),
        ),
        filled: true,
        fillColor: BioVoltColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: BioVoltColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: BioVoltColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: BioVoltColors.teal),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildSmallField({
    required TextEditingController controller,
    required String label,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        color: BioVoltColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          color: BioVoltColors.textSecondary,
        ),
        filled: true,
        fillColor: BioVoltColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: BioVoltColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: BioVoltColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: BioVoltColors.teal),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      ),
    );
  }
}
