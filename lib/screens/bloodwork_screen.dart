import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/bloodwork.dart';
import '../services/storage_service.dart';

// ---------------------------------------------------------------------------
// Optimal ranges for color coding
// ---------------------------------------------------------------------------

enum _RangeStatus { optimal, moderate, flag }

_RangeStatus _crpRange(double v) =>
    v < 1.0 ? _RangeStatus.optimal : v <= 3 ? _RangeStatus.moderate : _RangeStatus.flag;
_RangeStatus _testRange(double v) =>
    v >= 600 && v <= 900 ? _RangeStatus.optimal : v >= 400 ? _RangeStatus.moderate : _RangeStatus.flag;
_RangeStatus _igf1Range(double v) =>
    v >= 150 && v <= 250 ? _RangeStatus.optimal : _RangeStatus.moderate;
_RangeStatus _cortisolRange(double v) =>
    v >= 10 && v <= 20 ? _RangeStatus.optimal : v > 25 ? _RangeStatus.flag : _RangeStatus.moderate;
_RangeStatus _vitDRange(double v) =>
    v >= 50 && v <= 80 ? _RangeStatus.optimal : v >= 30 ? _RangeStatus.moderate : _RangeStatus.flag;
_RangeStatus _hba1cRange(double v) =>
    v < 5.4 ? _RangeStatus.optimal : v <= 5.7 ? _RangeStatus.moderate : _RangeStatus.flag;

Color _rangeColor(_RangeStatus s) => switch (s) {
      _RangeStatus.optimal => BioVoltColors.teal,
      _RangeStatus.moderate => BioVoltColors.amber,
      _RangeStatus.flag => BioVoltColors.coral,
    };

// ---------------------------------------------------------------------------
// BloodworkScreen
// ---------------------------------------------------------------------------

class BloodworkScreen extends StatefulWidget {
  const BloodworkScreen({super.key});

  @override
  State<BloodworkScreen> createState() => _BloodworkScreenState();
}

class _BloodworkScreenState extends State<BloodworkScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BioVoltColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: BioVoltColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    'BLOODWORK',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: BioVoltColors.teal,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            // Tabs
            TabBar(
              controller: _tabController,
              indicatorColor: BioVoltColors.teal,
              labelColor: BioVoltColors.teal,
              unselectedLabelColor: BioVoltColors.textSecondary,
              labelStyle: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
              tabs: const [
                Tab(text: 'HISTORY'),
                Tab(text: '+ ADD NEW'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _HistoryTab(storage: _storage),
                  _AddNewTab(
                    storage: _storage,
                    onSaved: () {
                      _tabController.animateTo(0);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History tab
// ---------------------------------------------------------------------------

class _HistoryTab extends StatelessWidget {
  final StorageService storage;

  const _HistoryTab({required this.storage});

  @override
  Widget build(BuildContext context) {
    final panels = storage.getAllBloodwork();

    if (panels.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bloodtype_rounded,
                size: 48,
                color: BioVoltColors.textSecondary.withAlpha(80)),
            const SizedBox(height: 16),
            Text(
              'No bloodwork logged',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                color: BioVoltColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap + Add New to log a panel',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: BioVoltColors.textSecondary.withAlpha(120),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: panels.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _BloodworkCard(panel: panels[index]),
    );
  }
}

class _BloodworkCard extends StatelessWidget {
  final Bloodwork panel;

  const _BloodworkCard({required this.panel});

  @override
  Widget build(BuildContext context) {
    final dt = panel.labDate;
    final dateStr = '${_monthName(dt.month)} ${dt.day}, ${dt.year}';
    final contextStr = [
      if (panel.fastingHours != null)
        'Fasted ${panel.fastingHours!.toStringAsFixed(0)}h',
      if (panel.protocolContext != null) panel.protocolContext,
    ].join('  \u2022  ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BioVoltTheme.glassCard(glowColor: BioVoltColors.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateStr,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: BioVoltColors.textPrimary,
            ),
          ),
          if (contextStr.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              contextStr,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                color: BioVoltColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: _buildMarkerChips(),
          ),
          const SizedBox(height: 4),
          Text(
            '${panel.filledCount} markers logged',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              color: BioVoltColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMarkerChips() {
    final markers = <Widget>[];

    void add(String label, double? value, String unit,
        [_RangeStatus Function(double)? rangeFn]) {
      if (value == null) return;
      final status = rangeFn?.call(value);
      final color = status != null ? _rangeColor(status) : BioVoltColors.teal;
      markers.add(_MarkerChip(
        label: label,
        value: '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)} $unit',
        color: color,
      ));
    }

    add('CRP', panel.crp, 'mg/L', _crpRange);
    add('Testosterone', panel.testosteroneTotal, 'ng/dL', _testRange);
    add('IGF-1', panel.igf1, 'ng/mL', _igf1Range);
    add('HbA1c', panel.hba1c, '%', _hba1cRange);
    add('Cortisol', panel.cortisolAm, '\u00B5g/dL', _cortisolRange);
    add('Vit D', panel.vitaminD, 'ng/mL', _vitDRange);
    add('HDL', panel.hdl, 'mg/dL');
    add('LDL', panel.ldl, 'mg/dL');
    add('ApoB', panel.apoB, 'mg/dL');
    add('TSH', panel.tsh, 'mIU/L');
    add('Ferritin', panel.ferritin, 'ng/mL');

    return markers;
  }

  String _monthName(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][m];
}

class _MarkerChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MarkerChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add New tab
// ---------------------------------------------------------------------------

class _AddNewTab extends StatefulWidget {
  final StorageService storage;
  final VoidCallback onSaved;

  const _AddNewTab({required this.storage, required this.onSaved});

  @override
  State<_AddNewTab> createState() => _AddNewTabState();
}

class _AddNewTabState extends State<_AddNewTab> {
  final _controllers = <String, TextEditingController>{};
  DateTime _labDate = DateTime.now();
  bool _saving = false;

  static const _panels = <String, List<(String key, String label, String unit)>>{
    'Inflammation': [
      ('crp', 'CRP', 'mg/L'),
      ('il6', 'IL-6', 'pg/mL'),
      ('homocysteine', 'Homocysteine', '\u00B5mol/L'),
    ],
    'Metabolic': [
      ('glucoseFasting', 'Glucose fasting', 'mg/dL'),
      ('hba1c', 'HbA1c', '%'),
      ('insulinFasting', 'Insulin fasting', '\u00B5IU/mL'),
      ('homaIr', 'HOMA-IR', ''),
    ],
    'Hormonal': [
      ('testosteroneTotal', 'Testosterone total', 'ng/dL'),
      ('testosteroneFree', 'Testosterone free', 'pg/mL'),
      ('dheaS', 'DHEA-S', '\u00B5g/dL'),
      ('cortisolAm', 'Cortisol AM', '\u00B5g/dL'),
      ('igf1', 'IGF-1', 'ng/mL'),
      ('estradiol', 'Estradiol', 'pg/mL'),
      ('shbg', 'SHBG', 'nmol/L'),
    ],
    'Thyroid': [
      ('tsh', 'TSH', 'mIU/L'),
      ('freeT3', 'Free T3', 'pg/mL'),
      ('freeT4', 'Free T4', 'ng/dL'),
    ],
    'Lipids': [
      ('totalCholesterol', 'Total cholesterol', 'mg/dL'),
      ('ldl', 'LDL', 'mg/dL'),
      ('hdl', 'HDL', 'mg/dL'),
      ('triglycerides', 'Triglycerides', 'mg/dL'),
      ('apoB', 'ApoB', 'mg/dL'),
    ],
    'Nutrients': [
      ('vitaminD', 'Vitamin D', 'ng/mL'),
      ('magnesiumRbc', 'Magnesium RBC', 'mg/dL'),
      ('omega3Index', 'Omega-3 index', '%'),
      ('ferritin', 'Ferritin', 'ng/mL'),
      ('b12', 'B12', 'pg/mL'),
    ],
  };

  TextEditingController _ctrl(String key) =>
      _controllers.putIfAbsent(key, () => TextEditingController());

  final _fastingCtrl = TextEditingController();
  final _protocolCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _fastingCtrl.dispose();
    _protocolCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double? _parseField(String key) {
    final text = _controllers[key]?.text.trim();
    if (text == null || text.isEmpty) return null;
    return double.tryParse(text);
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final bloodwork = Bloodwork(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      labDate: _labDate,
      fastingHours: double.tryParse(_fastingCtrl.text.trim()),
      protocolContext: _protocolCtrl.text.trim().isEmpty
          ? null
          : _protocolCtrl.text.trim(),
      notes:
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      crp: _parseField('crp'),
      il6: _parseField('il6'),
      homocysteine: _parseField('homocysteine'),
      glucoseFasting: _parseField('glucoseFasting'),
      hba1c: _parseField('hba1c'),
      insulinFasting: _parseField('insulinFasting'),
      homaIr: _parseField('homaIr'),
      testosteroneTotal: _parseField('testosteroneTotal'),
      testosteroneFree: _parseField('testosteroneFree'),
      dheaS: _parseField('dheaS'),
      cortisolAm: _parseField('cortisolAm'),
      igf1: _parseField('igf1'),
      estradiol: _parseField('estradiol'),
      shbg: _parseField('shbg'),
      tsh: _parseField('tsh'),
      freeT3: _parseField('freeT3'),
      freeT4: _parseField('freeT4'),
      totalCholesterol: _parseField('totalCholesterol'),
      ldl: _parseField('ldl'),
      hdl: _parseField('hdl'),
      triglycerides: _parseField('triglycerides'),
      apoB: _parseField('apoB'),
      vitaminD: _parseField('vitaminD'),
      magnesiumRbc: _parseField('magnesiumRbc'),
      omega3Index: _parseField('omega3Index'),
      ferritin: _parseField('ferritin'),
      b12: _parseField('b12'),
    );

    await widget.storage.saveBloodwork(bloodwork);
    if (mounted) {
      setState(() => _saving = false);
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Context section
        _SectionHeader(title: 'Context', initiallyExpanded: true),
        const SizedBox(height: 8),
        _buildDatePicker(),
        const SizedBox(height: 8),
        _buildTextField(_fastingCtrl, 'Fasting hours', ''),
        _buildTextField(_protocolCtrl, 'Protocol context', ''),
        _buildTextField(_notesCtrl, 'Notes', ''),
        const SizedBox(height: 16),

        // Panel sections
        for (final entry in _panels.entries) ...[
          _SectionHeader(title: entry.key),
          const SizedBox(height: 8),
          for (final field in entry.value)
            _buildTextField(_ctrl(field.$1), field.$2, field.$3),
          const SizedBox(height: 16),
        ],

        // Save button
        SizedBox(
          width: double.infinity,
          child: _saving
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: BioVoltColors.teal,
                  ),
                )
              : GestureDetector(
                  onTap: _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: BioVoltColors.teal.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: BioVoltColors.teal.withAlpha(100)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'SAVE PANEL',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: BioVoltColors.teal,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _labDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: BioVoltColors.teal,
                  surface: BioVoltColors.surface,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) setState(() => _labDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: BioVoltColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: BioVoltColors.cardBorder),
        ),
        child: Row(
          children: [
            Text(
              'Lab date',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: BioVoltColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              '${_labDate.month}/${_labDate.day}/${_labDate.year}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: BioVoltColors.teal,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.calendar_today_rounded,
                size: 14, color: BioVoltColors.teal),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, String unit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          color: BioVoltColors.textPrimary,
        ),
        decoration: InputDecoration(
          labelText: unit.isNotEmpty ? '$label ($unit)' : label,
          labelStyle: GoogleFonts.jetBrainsMono(
            fontSize: 11,
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
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatefulWidget {
  final String title;
  final bool initiallyExpanded;

  const _SectionHeader({
    required this.title,
    this.initiallyExpanded = false,
  });

  @override
  State<_SectionHeader> createState() => _SectionHeaderState();
}

class _SectionHeaderState extends State<_SectionHeader> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Row(
        children: [
          Icon(
            _expanded
                ? Icons.keyboard_arrow_down_rounded
                : Icons.keyboard_arrow_right_rounded,
            size: 18,
            color: BioVoltColors.teal,
          ),
          const SizedBox(width: 4),
          Text(
            widget.title.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: BioVoltColors.teal,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
