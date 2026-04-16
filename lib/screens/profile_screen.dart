import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/active_protocol.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';

class ProfileScreen extends StatefulWidget {
  final bool isFirstLaunch;

  const ProfileScreen({super.key, this.isFirstLaunch = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _storage = StorageService();

  // Basic info
  String? _sex;
  DateTime? _dob;
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  String _units = 'metric';

  // Goals
  final _selectedGoals = <String>{};
  static const _goalOptions = [
    ('Performance', '\u{1F3C6}'),
    ('Longevity', '\u{231B}'),
    ('Recovery', '\u{1F504}'),
    ('Cognition', '\u{1F9E0}'),
    ('Strength', '\u{1F4AA}'),
    ('Stress', '\u{1F60C}'),
    ('Sleep', '\u{1F634}'),
    ('Body Comp', '\u{2696}'),
    ('Research', '\u{1F52C}'),
  ];

  // AI style
  String? _aiStyle;

  // Conditions
  final _conditions = <String>[];
  final _conditionCtrl = TextEditingController();

  // Genetics
  String _mthfr = 'Unknown';
  String _apoe = 'Unknown';
  String _comt = 'Unknown';

  // Fasting
  String _fastingType = 'none';
  int _eatWindowStartHour = 12;
  int _eatWindowEndHour = 20;
  DateTime? _lastMealTime;

  // Protocols
  List<ActiveProtocol> _protocols = [];

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  void _loadExisting() {
    final profile = _storage.getUserProfile();
    if (profile == null) return;

    _sex = profile.biologicalSex;
    _dob = profile.dateOfBirth;
    if (profile.heightCm != null) {
      _heightCtrl.text = profile.heightCm!.toStringAsFixed(0);
    }
    if (profile.weightKg != null) {
      _weightCtrl.text = profile.weightKg!.toStringAsFixed(0);
    }
    _units = profile.preferredUnits;
    _selectedGoals.addAll(profile.healthGoals);
    _aiStyle = profile.aiCoachingStyle;
    _conditions.addAll(profile.knownConditions);
    _mthfr = profile.mthfr ?? 'Unknown';
    _apoe = profile.apoe ?? 'Unknown';
    _comt = profile.comt ?? 'Unknown';
    _fastingType = profile.fastingType ?? 'none';
    _eatWindowStartHour = profile.eatWindowStartHour ?? 12;
    _eatWindowEndHour = profile.eatWindowEndHour ?? 20;
    _lastMealTime = profile.lastMealTime;
    _protocols = _storage.getAllActiveProtocols();
  }

  @override
  void dispose() {
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _conditionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BioVoltColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  if (!widget.isFirstLaunch)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: BioVoltColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  if (widget.isFirstLaunch) const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isFirstLaunch ? 'WELCOME TO BIOVOLT' : 'PROFILE',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: BioVoltColors.teal,
                          letterSpacing: 2,
                        ),
                      ),
                      if (widget.isFirstLaunch)
                        Text(
                          'Set up your profile to personalize AI analysis',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            color: BioVoltColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionLabel('BASIC INFO'),
                  const SizedBox(height: 10),
                  _buildBasicInfo(),
                  const SizedBox(height: 20),
                  _sectionLabel('HEALTH GOALS'),
                  const SizedBox(height: 10),
                  _buildGoals(),
                  const SizedBox(height: 20),
                  _sectionLabel('AI COACHING STYLE'),
                  const SizedBox(height: 10),
                  _buildAiStyle(),
                  const SizedBox(height: 20),
                  _sectionLabel('KNOWN CONDITIONS'),
                  const SizedBox(height: 10),
                  _buildConditions(),
                  const SizedBox(height: 20),
                  _sectionLabel('GENETIC MARKERS'),
                  const SizedBox(height: 10),
                  _buildGenetics(),
                  const SizedBox(height: 24),
                  _buildFastingSection(),
                  const SizedBox(height: 24),
                  _buildProtocolsSection(),
                  const SizedBox(height: 24),
                  _buildSaveButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Basic info
  // ---------------------------------------------------------------------------

  Widget _buildBasicInfo() {
    return Column(
      children: [
        // Sex
        Row(
          children: [
            _label('Biological sex'),
            const Spacer(),
            for (final s in ['Male', 'Female', 'Other'])
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _chip(s, selected: _sex == s,
                    onTap: () => setState(() => _sex = s)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        // DOB
        GestureDetector(
          onTap: _pickDob,
          child: Row(
            children: [
              _label('Date of birth'),
              const Spacer(),
              Text(
                _dob != null
                    ? '${_dob!.month}/${_dob!.day}/${_dob!.year}'
                    : 'Tap to set',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: _dob != null
                      ? BioVoltColors.teal
                      : BioVoltColors.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.calendar_today_rounded,
                  size: 14, color: BioVoltColors.teal),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Height + weight
        Row(
          children: [
            Expanded(child: _smallField(_heightCtrl, 'Height (cm)')),
            const SizedBox(width: 8),
            Expanded(child: _smallField(_weightCtrl, 'Weight (kg)')),
          ],
        ),
        const SizedBox(height: 10),
        // Units
        Row(
          children: [
            _label('Units'),
            const Spacer(),
            _chip('Metric',
                selected: _units == 'metric',
                onTap: () => setState(() => _units = 'metric')),
            const SizedBox(width: 6),
            _chip('Imperial',
                selected: _units == 'imperial',
                onTap: () => setState(() => _units = 'imperial')),
          ],
        ),
      ],
    );
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: BioVoltColors.teal,
            surface: BioVoltColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  // ---------------------------------------------------------------------------
  // Goals
  // ---------------------------------------------------------------------------

  Widget _buildGoals() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _goalOptions.map((g) {
        final selected = _selectedGoals.contains(g.$1);
        return GestureDetector(
          onTap: () => setState(() {
            if (selected) {
              _selectedGoals.remove(g.$1);
            } else {
              _selectedGoals.add(g.$1);
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
                Text(g.$2, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  g.$1,
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

  // ---------------------------------------------------------------------------
  // AI style
  // ---------------------------------------------------------------------------

  Widget _buildAiStyle() {
    const styles = [
      ('direct', 'Direct', 'Your HRV is low. Rest today.'),
      ('scientific', 'Scientific',
          'RMSSD 34ms is 28% below your 90-day mean.'),
      ('motivational', 'Motivational',
          'Strong session \u2014 your body is adapting well.'),
      ('gentle', 'Gentle',
          'Consider an easier day based on your recovery.'),
    ];

    return Column(
      children: styles.map((s) {
        final selected = _aiStyle == s.$1;
        return GestureDetector(
          onTap: () => setState(() => _aiStyle = s.$1),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? BioVoltColors.teal.withAlpha(12)
                  : BioVoltColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? BioVoltColors.teal.withAlpha(80)
                    : BioVoltColors.cardBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 18,
                  color: selected
                      ? BioVoltColors.teal
                      : BioVoltColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.$2,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: BioVoltColors.textPrimary,
                        ),
                      ),
                      Text(
                        '"${s.$3}"',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: BioVoltColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Conditions
  // ---------------------------------------------------------------------------

  Widget _buildConditions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_conditions.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _conditions
                .map((c) => _removableChip(c,
                    () => setState(() => _conditions.remove(c))))
                .toList(),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _conditionCtrl,
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 11, color: BioVoltColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Add condition...',
                  hintStyle: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: BioVoltColors.textSecondary.withAlpha(80)),
                  filled: true,
                  fillColor: BioVoltColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: BioVoltColors.cardBorder),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                onSubmitted: (v) => _addCondition(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _addCondition,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: BioVoltColors.teal.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: BioVoltColors.teal.withAlpha(80)),
                ),
                child: const Icon(Icons.add,
                    size: 18, color: BioVoltColors.teal),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _addCondition() {
    final text = _conditionCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _conditions.add(text);
      _conditionCtrl.clear();
    });
  }

  // ---------------------------------------------------------------------------
  // Genetics
  // ---------------------------------------------------------------------------

  Widget _buildGenetics() {
    return Column(
      children: [
        _geneticRow('MTHFR', _mthfr,
            ['C677T het', 'C677T hom', 'A1298C', 'Normal', 'Unknown'],
            (v) => setState(() => _mthfr = v)),
        const SizedBox(height: 8),
        _geneticRow('APOE', _apoe,
            ['E3/E3', 'E3/E4', 'E4/E4', 'Unknown'],
            (v) => setState(() => _apoe = v)),
        const SizedBox(height: 8),
        _geneticRow('COMT', _comt,
            ['Val/Val (fast)', 'Val/Met', 'Met/Met (slow)', 'Unknown'],
            (v) => setState(() => _comt = v)),
      ],
    );
  }

  Widget _geneticRow(String gene, String current, List<String> options,
      ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          gene,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: BioVoltColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: options
              .map((o) => _chip(o,
                  selected: current == o,
                  onTap: () => onChanged(o)))
              .toList(),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Fasting
  // ---------------------------------------------------------------------------

  Widget _buildFastingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('FASTING SCHEDULE'),
        const SizedBox(height: 10),
        // Type chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in [
              ('None', 'none'),
              ('16:8', '16:8'),
              ('5:2', '5:2'),
              ('24hr', '24hr'),
            ])
              _chip(entry.$1,
                  selected: _fastingType == entry.$2,
                  onTap: () => setState(() => _fastingType = entry.$2)),
          ],
        ),
        // Eat window pickers
        if (_fastingType == '16:8' || _fastingType == '5:2') ...[
          const SizedBox(height: 12),
          Row(
            children: [
              _label('Eating window'),
              const Spacer(),
              GestureDetector(
                onTap: () => _pickEatHour(isStart: true),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: BioVoltColors.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: BioVoltColors.cardBorder),
                  ),
                  child: Text(
                    _formatHour(_eatWindowStartHour),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: BioVoltColors.teal,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '\u2192',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: BioVoltColors.textSecondary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _pickEatHour(isStart: false),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: BioVoltColors.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: BioVoltColors.cardBorder),
                  ),
                  child: Text(
                    _formatHour(_eatWindowEndHour),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: BioVoltColors.teal,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
        if (_fastingType != 'none') ...[
          const SizedBox(height: 8),
          Text(
            'Auto-calculates ${_computeFastHours()} hr fast',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: BioVoltColors.teal,
            ),
          ),
        ],
        const SizedBox(height: 14),
        // "I JUST ATE" button
        GestureDetector(
          onTap: () async {
            await _storage.updateLastMealTime();
            setState(() => _lastMealTime = DateTime.now());
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: BioVoltColors.amber.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: BioVoltColors.amber.withAlpha(100), width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              _lastMealTime == null
                  ? 'I JUST ATE \u2014 set meal time'
                  : 'LAST MEAL: ${_formatLastMeal(_lastMealTime!)}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: BioVoltColors.amber,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickEatHour({required bool isStart}) async {
    final initial = isStart ? _eatWindowStartHour : _eatWindowEndHour;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: BioVoltColors.teal,
            surface: BioVoltColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _eatWindowStartHour = picked.hour;
        } else {
          _eatWindowEndHour = picked.hour;
        }
      });
    }
  }

  int _computeFastHours() {
    final diff = _eatWindowEndHour - _eatWindowStartHour;
    final eatWindow = diff < 0 ? 24 + diff : diff;
    return 24 - eatWindow;
  }

  String _formatHour(int hour) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour < 12 ? 'am' : 'pm';
    return '$h:00 $period';
  }

  String _formatLastMeal(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ---------------------------------------------------------------------------
  // Active Protocols
  // ---------------------------------------------------------------------------

  Widget _buildProtocolsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('ACTIVE PROTOCOLS'),
        const SizedBox(height: 10),
        if (_protocols.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Text(
                'No active protocols \u2014 add one below',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: BioVoltColors.textSecondary,
                ),
              ),
            ),
          ),
        for (final p in _protocols) _buildProtocolCard(p),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _showAddProtocolSheet,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: BioVoltColors.teal.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: BioVoltColors.teal.withAlpha(80), width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              'ADD PROTOCOL',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: BioVoltColors.teal,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProtocolCard(ActiveProtocol protocol) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BioVoltColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BioVoltColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  protocol.name,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: BioVoltColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${protocol.currentCycleDay} / ${protocol.cycleLengthDays} days',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: protocol.isActive
                        ? BioVoltColors.teal
                        : BioVoltColors.textSecondary,
                  ),
                ),
                if (protocol.doseMcg > 0)
                  Text(
                    '${protocol.doseMcg.toStringAsFixed(0)}mcg ${protocol.route}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: BioVoltColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (protocol.isActive)
            GestureDetector(
              onTap: () async {
                await _storage.endProtocol(protocol.id);
                _reloadProtocols();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: BioVoltColors.cardBorder),
                ),
                child: Text(
                  'END',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: BioVoltColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            Text(
              'INACTIVE',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: BioVoltColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  void _reloadProtocols() {
    setState(() => _protocols = _storage.getAllActiveProtocols());
  }

  void _showAddProtocolSheet() {
    final nameCtrl = TextEditingController();
    final doseCtrl = TextEditingController();
    final totalDaysCtrl = TextEditingController(text: '30');
    String type = 'peptide';
    String route = 'subq';
    DateTime startDate = DateTime.now();

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
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: BioVoltColors.textSecondary.withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'ADD PROTOCOL',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: BioVoltColors.teal,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              // Name
              _sheetField(nameCtrl, 'Name (e.g. BPC-157)'),
              const SizedBox(height: 8),
              // Type chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in [
                    ('Peptide', 'peptide'),
                    ('Supplement', 'supplement'),
                    ('Other', 'other'),
                  ])
                    _sheetChip(entry.$1,
                        selected: type == entry.$2,
                        onTap: () => setSheet(() => type = entry.$2)),
                ],
              ),
              const SizedBox(height: 8),
              // Dose
              _sheetField(doseCtrl, 'Daily dose (mcg, optional)'),
              const SizedBox(height: 8),
              // Route chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in [
                    ('Subq', 'subq'),
                    ('Oral', 'oral'),
                    ('Topical', 'topical'),
                    ('Nasal', 'nasal'),
                  ])
                    _sheetChip(entry.$1,
                        selected: route == entry.$2,
                        onTap: () => setSheet(() => route = entry.$2)),
                ],
              ),
              const SizedBox(height: 8),
              // Total days
              _sheetField(totalDaysCtrl, 'Total days'),
              const SizedBox(height: 8),
              // Start date
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: startDate,
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 365)),
                    lastDate:
                        DateTime.now().add(const Duration(days: 30)),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: BioVoltColors.teal,
                          surface: BioVoltColors.surface,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setSheet(() => startDate = picked);
                },
                child: Row(
                  children: [
                    Text(
                      'Started: ${startDate.month}/${startDate.day}/${startDate.year}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: BioVoltColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.edit_rounded,
                        size: 14, color: BioVoltColors.teal),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // ADD button
              GestureDetector(
                onTap: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final protocol = ActiveProtocol(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameCtrl.text.trim(),
                    type: type,
                    startDate: startDate,
                    cycleLengthDays:
                        int.tryParse(totalDaysCtrl.text) ?? 30,
                    doseMcg: double.tryParse(doseCtrl.text) ?? 0,
                    route: route,
                    isActive: true,
                  );
                  _storage.saveActiveProtocol(protocol);
                  Navigator.of(ctx).pop();
                  _reloadProtocols();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: BioVoltColors.teal.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: BioVoltColors.teal.withAlpha(120), width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'ADD',
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
        );
      }),
    );
  }

  Widget _sheetField(TextEditingController ctrl, String label) {
    return TextField(
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
          borderSide: const BorderSide(color: BioVoltColors.cardBorder),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }

  Widget _sheetChip(String label,
      {required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? BioVoltColors.teal.withAlpha(20)
              : BioVoltColors.background,
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
  // Save
  // ---------------------------------------------------------------------------

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _saving ? null : _save,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: BioVoltColors.teal.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: BioVoltColors.teal.withAlpha(120), width: 2),
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
                'SAVE PROFILE',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: BioVoltColors.teal,
                  letterSpacing: 2,
                ),
              ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final existing = _storage.getUserProfile();
    final profile = UserProfile(
      userId: existing?.userId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: existing?.createdAt ?? DateTime.now(),
      biologicalSex: _sex,
      dateOfBirth: _dob,
      heightCm: double.tryParse(_heightCtrl.text),
      weightKg: double.tryParse(_weightCtrl.text),
      healthGoals: _selectedGoals.toList(),
      knownConditions: _conditions,
      baselineEstablished: existing?.baselineEstablished ?? false,
      preferredUnits: _units,
      aiCoachingStyle: _aiStyle,
      mthfr: _mthfr == 'Unknown' ? null : _mthfr,
      apoe: _apoe == 'Unknown' ? null : _apoe,
      comt: _comt == 'Unknown' ? null : _comt,
      fastingType: _fastingType == 'none' ? null : _fastingType,
      eatWindowStartHour: _eatWindowStartHour,
      eatWindowEndHour: _eatWindowEndHour,
      lastMealTime: _lastMealTime,
    );

    await _storage.saveUserProfile(profile);

    if (mounted) {
      setState(() => _saving = false);
      if (widget.isFirstLaunch) {
        // Pop back — main.dart navigator will show the main app
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Widget _sectionLabel(String text) => Text(
        text,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: BioVoltColors.teal,
          letterSpacing: 2,
        ),
      );

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          color: BioVoltColors.textSecondary,
        ),
      );

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
          Text(label,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 9, color: BioVoltColors.teal)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child:
                const Icon(Icons.close, size: 12, color: BioVoltColors.teal),
          ),
        ],
      ),
    );
  }

  Widget _smallField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: GoogleFonts.jetBrainsMono(
          fontSize: 11, color: BioVoltColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.jetBrainsMono(
            fontSize: 10, color: BioVoltColors.textSecondary),
        filled: true,
        fillColor: BioVoltColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: BioVoltColors.cardBorder),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      ),
    );
  }
}
