import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/session/session_bloc.dart';
import '../bloc/session/session_event.dart';
import '../config/theme.dart';
import '../models/interventions.dart';
import '../models/session_type.dart';
import '../services/ble_service.dart';
import '../services/storage_service.dart';
import 'session_screen.dart';

// ---------------------------------------------------------------------------
// Activity definitions
// ---------------------------------------------------------------------------

class _ActivityDef {
  final String id;
  final String label;
  final String icon;
  final SessionType? sessionType;

  const _ActivityDef(this.id, this.label, this.icon, [this.sessionType]);
}

const _activities = [
  _ActivityDef('breathwork', 'Breathwork', '\u{1F32C}', SessionType.breathwork),
  _ActivityDef('coldExposure', 'Cold Plunge', '\u{2744}', SessionType.coldExposure),
  _ActivityDef('sauna', 'Sauna', '\u{1F525}'),
  _ActivityDef('meditation', 'Meditation', '\u{1F9D8}', SessionType.meditation),
  _ActivityDef('workout', 'Workout', '\u{1F4AA}'),
  _ActivityDef('redLight', 'Red Light', '\u{26A1}'),
  _ActivityDef('grounding', 'Grounding', '\u{1F30D}', SessionType.grounding),
  _ActivityDef('rest', 'Rest/HRV', '\u{1F634}', SessionType.fastingCheck),
  _ActivityDef('other', 'Other', '\u{1F4E6}'),
];

// ---------------------------------------------------------------------------
// PreSessionScreen
// ---------------------------------------------------------------------------

class PreSessionScreen extends StatefulWidget {
  final BleService bleService;

  const PreSessionScreen({super.key, required this.bleService});

  @override
  State<PreSessionScreen> createState() => _PreSessionScreenState();
}

class _PreSessionScreenState extends State<PreSessionScreen> {
  // Activity selection
  final _selectedActivities = <String>{};
  String? _breathworkPattern;
  final _breathRoundsCtrl = TextEditingController();
  final _breathHoldCtrl = TextEditingController();
  final _waterTempCtrl = TextEditingController();
  final _coldDurationCtrl = TextEditingController();
  String? _workoutType;
  double _workoutRpe = 5;

  // Context
  bool _fasting = false;
  final _fastingHoursCtrl = TextEditingController();
  final _timeSinceWakeCtrl = TextEditingController();
  final _sleepHoursCtrl = TextEditingController();

  // Interventions
  final _peptides = <PeptideLog>[];
  final _supplements = <SupplementLog>[];

  // Subjective (1-10 sliders)
  double _energy = 5;
  double _mood = 5;
  double _focus = 5;
  double _anxiety = 3;
  double _soreness = 3;
  bool _slidersInteracted = false;

  @override
  void initState() {
    super.initState();
    _autoPopulateSleep();
  }

  void _autoPopulateSleep() {
    final storage = StorageService();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final oura = storage.getOuraDailyRecord(yesterday);
    if (oura != null && oura.sleepScore != null) {
      // Rough estimate: sleep score 80 ≈ 7.5 hours
      final estimatedHours = (oura.sleepScore! / 10.0).clamp(4.0, 10.0);
      _sleepHoursCtrl.text = estimatedHours.toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _breathRoundsCtrl.dispose();
    _breathHoldCtrl.dispose();
    _waterTempCtrl.dispose();
    _coldDurationCtrl.dispose();
    _fastingHoursCtrl.dispose();
    _timeSinceWakeCtrl.dispose();
    _sleepHoursCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BioVoltColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 12),
                  _sectionLabel('WHAT ARE YOU DOING TODAY?'),
                  const SizedBox(height: 10),
                  _buildActivityGrid(),
                  _buildActivityParams(),
                  const SizedBox(height: 20),
                  _sectionLabel('CONTEXT'),
                  const SizedBox(height: 10),
                  _buildContextSection(),
                  const SizedBox(height: 20),
                  _sectionLabel('INTERVENTIONS LOGGED TODAY'),
                  const SizedBox(height: 10),
                  _buildInterventionsSection(),
                  const SizedBox(height: 20),
                  _sectionLabel('HOW DO YOU FEEL RIGHT NOW?'),
                  const SizedBox(height: 10),
                  _buildSubjectiveSection(),
                  const SizedBox(height: 24),
                  _buildStartButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: BioVoltColors.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Text(
            'PREPARE SESSION',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: BioVoltColors.teal,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 1 — Activity selector
  // ---------------------------------------------------------------------------

  Widget _buildActivityGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _activities.map((a) {
        final selected = _selectedActivities.contains(a.id);
        return GestureDetector(
          onTap: () => setState(() {
            if (selected) {
              _selectedActivities.remove(a.id);
            } else {
              _selectedActivities.add(a.id);
            }
          }),
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
                    fontSize: 11,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
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

  Widget _buildActivityParams() {
    final widgets = <Widget>[];

    if (_selectedActivities.contains('breathwork')) {
      widgets.add(_buildBreathworkParams());
    }
    if (_selectedActivities.contains('coldExposure')) {
      widgets.add(_buildColdParams());
    }
    if (_selectedActivities.contains('workout')) {
      widgets.add(_buildWorkoutParams());
    }

    if (widgets.isEmpty) return const SizedBox.shrink();
    return Column(children: [const SizedBox(height: 12), ...widgets]);
  }

  Widget _buildBreathworkParams() {
    return _ParamCard(
      title: 'Breathwork',
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in ['wimHof', 'box4', 'relaxing478', 'tummo', 'other'])
              _chipSelect(
                p == 'wimHof'
                    ? 'Wim Hof'
                    : p == 'box4'
                        ? 'Box'
                        : p == 'relaxing478'
                            ? '4-7-8'
                            : p == 'tummo'
                                ? 'Tummo'
                                : 'Other',
                selected: _breathworkPattern == p,
                onTap: () =>
                    setState(() => _breathworkPattern = p),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _smallField(_breathRoundsCtrl, 'Rounds')),
            const SizedBox(width: 8),
            Expanded(
                child: _smallField(_breathHoldCtrl, 'Hold (sec)')),
          ],
        ),
      ],
    );
  }

  Widget _buildColdParams() {
    return _ParamCard(
      title: 'Cold Plunge',
      children: [
        Row(
          children: [
            Expanded(
                child: _smallField(_waterTempCtrl, 'Water temp (\u00B0F)')),
            const SizedBox(width: 8),
            Expanded(
                child: _smallField(_coldDurationCtrl, 'Duration (min)')),
          ],
        ),
      ],
    );
  }

  Widget _buildWorkoutParams() {
    return _ParamCard(
      title: 'Workout',
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in ['HIIT', 'Zone 2', 'Strength', 'Yoga', 'Other'])
              _chipSelect(
                t,
                selected: _workoutType == t,
                onTap: () => setState(() => _workoutType = t),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'RPE',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: BioVoltColors.textSecondary,
              ),
            ),
            Expanded(
              child: Slider(
                value: _workoutRpe,
                min: 1,
                max: 10,
                divisions: 9,
                activeColor: BioVoltColors.teal,
                inactiveColor: BioVoltColors.surface,
                onChanged: (v) => setState(() => _workoutRpe = v),
              ),
            ),
            Text(
              '${_workoutRpe.round()}/10',
              style: BioVoltTheme.valueStyle(12, color: BioVoltColors.teal),
            ),
          ],
        ),
      ],
    );
  }

  Widget _chipSelect(String label,
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

  // ---------------------------------------------------------------------------
  // Section 2 — Context
  // ---------------------------------------------------------------------------

  Widget _buildContextSection() {
    return Column(
      children: [
        // Fasting toggle
        Row(
          children: [
            Text(
              'Fasting?',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: BioVoltColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            _chipSelect('Yes', selected: _fasting, onTap: () {
              setState(() => _fasting = true);
            }),
            const SizedBox(width: 6),
            _chipSelect('No', selected: !_fasting, onTap: () {
              setState(() => _fasting = false);
            }),
            if (_fasting) ...[
              const SizedBox(width: 12),
              SizedBox(
                width: 80,
                child: _smallField(_fastingHoursCtrl, 'hours'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _smallField(_timeSinceWakeCtrl, 'Time since wake (h)')),
            const SizedBox(width: 8),
            Expanded(
                child: _smallField(_sleepHoursCtrl, 'Sleep last night (h)')),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Section 3 — Interventions
  // ---------------------------------------------------------------------------

  Widget _buildInterventionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logged items as chips
        if (_peptides.isNotEmpty || _supplements.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ..._peptides.map((p) => _removableChip(
                    '${p.name} ${p.doseMcg.toStringAsFixed(0)}mcg ${p.route}',
                    () => setState(() => _peptides.remove(p)),
                  )),
              ..._supplements.map((s) => _removableChip(
                    '${s.name} ${s.doseMg.toStringAsFixed(0)}mg',
                    () => setState(() => _supplements.remove(s)),
                  )),
            ],
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            _actionBtn('+ ADD PEPTIDE', () => _showPeptideSheet()),
            const SizedBox(width: 8),
            _actionBtn('+ ADD SUPPLEMENT', () => _showSupplementSheet()),
          ],
        ),
      ],
    );
  }

  Widget _removableChip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: BioVoltColors.teal.withAlpha(12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: BioVoltColors.teal.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              color: BioVoltColors.teal,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 12, color: BioVoltColors.teal),
          ),
        ],
      ),
    );
  }

  void _showPeptideSheet() {
    final nameCtrl = TextEditingController();
    final doseCtrl = TextEditingController();
    String route = 'SC';
    final cycleDayCtrl = TextEditingController();
    final cycleTotalCtrl = TextEditingController();

    final suggestions = [
      'BPC-157',
      'TB-500',
      'GHK-Cu',
      'Epithalon',
      'SS-31',
      'KPV',
      'Thymosin Alpha-1',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        return Container(
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
              _sheetHandle(),
              _sheetTitle('ADD PEPTIDE'),
              const SizedBox(height: 12),
              // Suggestion chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: suggestions
                    .map((s) => GestureDetector(
                          onTap: () => nameCtrl.text = s,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: BioVoltColors.background,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: BioVoltColors.cardBorder),
                            ),
                            child: Text(
                              s,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9,
                                color: BioVoltColors.textSecondary,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              _sheetField(nameCtrl, 'Name'),
              _sheetField(doseCtrl, 'Dose (mcg)'),
              Row(
                children: [
                  for (final r in ['SC', 'IM', 'Intranasal', 'Oral'])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _chipSelect(r,
                          selected: route == r,
                          onTap: () => setSheet(() => route = r)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _sheetField(cycleDayCtrl, 'Cycle day')),
                  const SizedBox(width: 8),
                  Expanded(child: _sheetField(cycleTotalCtrl, 'of total')),
                ],
              ),
              const SizedBox(height: 12),
              _actionBtn('ADD', () {
                if (nameCtrl.text.trim().isEmpty) return;
                setState(() {
                  _peptides.add(PeptideLog(
                    name: nameCtrl.text.trim(),
                    doseMcg: double.tryParse(doseCtrl.text) ?? 0,
                    route: route,
                    cycleDay: int.tryParse(cycleDayCtrl.text),
                    cycleTotalDays: int.tryParse(cycleTotalCtrl.text),
                    loggedAt: DateTime.now(),
                  ));
                });
                Navigator.of(ctx).pop();
              }),
            ],
          ),
        );
      }),
    );
  }

  void _showSupplementSheet() {
    final nameCtrl = TextEditingController();
    final doseCtrl = TextEditingController();
    final formCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
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
            _sheetHandle(),
            _sheetTitle('ADD SUPPLEMENT'),
            const SizedBox(height: 12),
            _sheetField(nameCtrl, 'Name'),
            _sheetField(doseCtrl, 'Dose (mg)'),
            _sheetField(formCtrl, 'Form (capsule, powder, etc.)'),
            const SizedBox(height: 12),
            _actionBtn('ADD', () {
              if (nameCtrl.text.trim().isEmpty) return;
              setState(() {
                _supplements.add(SupplementLog(
                  name: nameCtrl.text.trim(),
                  doseMg: double.tryParse(doseCtrl.text) ?? 0,
                  form: formCtrl.text.trim().isEmpty
                      ? null
                      : formCtrl.text.trim(),
                  loggedAt: DateTime.now(),
                ));
              });
              Navigator.of(ctx).pop();
            }),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 4 — Subjective
  // ---------------------------------------------------------------------------

  Widget _buildSubjectiveSection() {
    return Column(
      children: [
        _subjectiveSlider('Energy', '\u{1F634}', '\u{26A1}', _energy,
            (v) => setState(() { _energy = v; _slidersInteracted = true; })),
        _subjectiveSlider('Mood', '\u{1F614}', '\u{1F60A}', _mood,
            (v) => setState(() { _mood = v; _slidersInteracted = true; })),
        _subjectiveSlider('Focus', '\u{1F635}', '\u{1F3AF}', _focus,
            (v) => setState(() { _focus = v; _slidersInteracted = true; })),
        _subjectiveSlider('Anxiety', '\u{1F60C}', '\u{1F630}', _anxiety,
            (v) => setState(() { _anxiety = v; _slidersInteracted = true; })),
        _subjectiveSlider('Soreness', '\u{1F4AA}', '\u{1F915}', _soreness,
            (v) => setState(() { _soreness = v; _slidersInteracted = true; })),
      ],
    );
  }

  Widget _subjectiveSlider(String label, String leftEmoji, String rightEmoji,
      double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: BioVoltColors.textSecondary,
              ),
            ),
          ),
          Text(leftEmoji, style: const TextStyle(fontSize: 14)),
          Expanded(
            child: Slider(
              value: value,
              min: 1,
              max: 10,
              divisions: 9,
              activeColor: BioVoltColors.teal,
              inactiveColor: BioVoltColors.surface,
              onChanged: onChanged,
            ),
          ),
          Text(rightEmoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            '${value.round()}/10',
            style: BioVoltTheme.valueStyle(11, color: BioVoltColors.teal),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Start button
  // ---------------------------------------------------------------------------

  Widget _buildStartButton() {
    final canStart =
        _selectedActivities.isNotEmpty && _slidersInteracted;

    return GestureDetector(
      onTap: canStart ? _startSession : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: canStart
              ? BioVoltColors.teal.withAlpha(20)
              : BioVoltColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: canStart
                ? BioVoltColors.teal.withAlpha(120)
                : BioVoltColors.cardBorder,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          'START SESSION \u2192',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: canStart
                ? BioVoltColors.teal
                : BioVoltColors.textSecondary.withAlpha(80),
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  void _startSession() {
    // Determine primary session type from first selected activity
    final primaryActivity = _activities.firstWhere(
      (a) => _selectedActivities.contains(a.id),
    );
    final sessionType = primaryActivity.sessionType ?? SessionType.fastingCheck;

    final bloc = context.read<SessionBloc>();

    // Set session type and breathwork pattern
    bloc.add(SessionTypeSelected(sessionType));
    if (_selectedActivities.contains('breathwork') &&
        _breathworkPattern != null) {
      bloc.add(BreathworkPatternSelected(_breathworkPattern!));
    }

    // Start session
    bloc.add(SessionStarted());

    // Navigate to session screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: SessionScreen(bleService: widget.bleService),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

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

  Widget _smallField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          borderSide: BorderSide(color: BioVoltColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: BioVoltColors.cardBorder),
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

  Widget _actionBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: BioVoltColors.teal.withAlpha(15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: BioVoltColors.teal.withAlpha(80)),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: BioVoltColors.teal,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _sheetHandle() => Center(
        child: Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: BioVoltColors.textSecondary.withAlpha(80),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _sheetTitle(String text) => Text(
        text,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: BioVoltColors.teal,
          letterSpacing: 2,
        ),
      );

  Widget _sheetField(TextEditingController ctrl, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: ctrl,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            color: BioVoltColors.textPrimary,
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: BioVoltColors.textSecondary,
            ),
            filled: true,
            fillColor: BioVoltColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: BioVoltColors.cardBorder),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
      );
}

class _ParamCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ParamCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BioVoltTheme.glassCard(glowColor: BioVoltColors.teal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: BioVoltColors.teal,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
