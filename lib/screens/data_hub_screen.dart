import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/sensors/sensors_bloc.dart';
import '../bloc/sensors/sensors_state.dart';
import '../config/theme.dart';
import '../connectors/connector_base.dart';
import '../connectors/connector_oura.dart';
import '../connectors/connector_registry.dart';
import '../models/normalized_record.dart';
import '../services/oura_sync_service.dart';
import '../services/storage_service.dart';
import 'bloodwork_screen.dart';

class DataHubScreen extends StatefulWidget {
  const DataHubScreen({super.key});

  @override
  State<DataHubScreen> createState() => _DataHubScreenState();
}

class _DataHubScreenState extends State<DataHubScreen> {
  final _storage = StorageService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BioVoltColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                'DATA HUB',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: BioVoltColors.teal,
                  letterSpacing: 3,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: _buildCompleteness(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 12),
                  _sectionLabel('ACTIVE SENSORS'),
                  const SizedBox(height: 8),
                  ..._buildBleSensors(),
                  const SizedBox(height: 20),
                  _sectionLabel('CLOUD INTEGRATIONS'),
                  const SizedBox(height: 8),
                  ..._buildRestConnectors(),
                  const SizedBox(height: 20),
                  _sectionLabel('MANUAL DATA SOURCES'),
                  const SizedBox(height: 8),
                  _buildManualSources(),
                  const SizedBox(height: 20),
                  _sectionLabel('DATA TIMELINE (30 DAYS)'),
                  const SizedBox(height: 8),
                  _buildTimeline(),
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
  // Completeness score
  // ---------------------------------------------------------------------------

  Widget _buildCompleteness() {
    final score = _computeCompleteness();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Data completeness:',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: BioVoltColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: score / 100,
                  minHeight: 8,
                  backgroundColor: BioVoltColors.surface,
                  valueColor: AlwaysStoppedAnimation(
                    score >= 70
                        ? BioVoltColors.teal
                        : score >= 40
                            ? BioVoltColors.amber
                            : BioVoltColors.coral,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${score.round()}%',
              style: BioVoltTheme.valueStyle(14, color: BioVoltColors.teal),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Add more data sources to improve AI analysis quality',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9,
            color: BioVoltColors.textSecondary.withAlpha(120),
          ),
        ),
      ],
    );
  }

  double _computeCompleteness() {
    double score = 0;

    // ESP32 connected → +20%
    final bleConnectors =
        ConnectorRegistry.instance.getByType(ConnectorType.ble);
    if (bleConnectors.any((c) => c.status == ConnectorStatus.connected)) {
      score += 20;
    }

    // Oura connected + synced today → +25%
    final oura = ConnectorRegistry.instance.get('oura_ring_4');
    if (oura != null && oura.isAuthenticated) {
      final today = DateTime.now();
      final ouraToday = _storage.getOuraDailyRecord(today);
      score += ouraToday != null ? 25 : 15; // partial credit if connected
    }

    // Bloodwork in last 90 days → +20%
    final allBw = _storage.getAllBloodwork();
    final ninetyAgo = DateTime.now().subtract(const Duration(days: 90));
    if (allBw.any((b) => b.labDate.isAfter(ninetyAgo))) score += 20;

    // Subjective scores on >50% of sessions → +15%
    final sessions = _storage.getAllSessions();
    if (sessions.isNotEmpty) {
      final withSubj =
          sessions.where((s) => s.subjective != null).length;
      if (withSubj / sessions.length > 0.5) score += 15;
    }

    // User profile goals filled → +10%
    final profile = _storage.getUserProfile();
    if (profile != null && profile.healthGoals.isNotEmpty) score += 10;

    // Polar H10 → +10% (check if any connector has ECG data type)
    final connectors = ConnectorRegistry.instance.getAll();
    if (connectors.any((c) =>
        c.supportedDataTypes.contains(DataType.ecg) &&
        c.connectorId != 'esp32_biovolt' &&
        c.status == ConnectorStatus.connected)) {
      score += 10;
    }

    return score.clamp(0, 100);
  }

  // ---------------------------------------------------------------------------
  // Section 1 — BLE Sensors
  // ---------------------------------------------------------------------------

  List<Widget> _buildBleSensors() {
    final bleConnectors =
        ConnectorRegistry.instance.getByType(ConnectorType.ble);
    if (bleConnectors.isEmpty) {
      return [_emptyCard('No BLE sensors registered')];
    }
    return bleConnectors.map((c) => _buildBleCard(c)).toList();
  }

  Widget _buildBleCard(BioVoltConnector connector) {
    final connected = connector.status == ConnectorStatus.connected;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BioVoltTheme.glassCard(
        glowColor: connected ? BioVoltColors.teal : BioVoltColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: connected
                      ? BioVoltColors.teal
                      : BioVoltColors.amber,
                  shape: BoxShape.circle,
                  boxShadow: connected
                      ? [
                          BoxShadow(
                            color: BioVoltColors.teal.withAlpha(100),
                            blurRadius: 6,
                          )
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  connector.displayName,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: BioVoltColors.textPrimary,
                  ),
                ),
              ),
              Text(
                connected ? 'CONNECTED' : 'SCANNING...',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: connected
                      ? BioVoltColors.teal
                      : BioVoltColors.amber,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            connector.supportedDataTypes
                .map((d) => d.name.toUpperCase())
                .join(' \u2022 '),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              color: BioVoltColors.textSecondary,
            ),
          ),
          if (connected) ...[
            const SizedBox(height: 10),
            BlocBuilder<SensorsBloc, SensorsState>(
              builder: (context, state) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _liveValue('HR', '${state.heartRate.toStringAsFixed(0)} bpm'),
                    _liveValue('HRV', '${state.hrv.toStringAsFixed(0)}ms'),
                    _liveValue('GSR', '${state.gsr.toStringAsFixed(1)}\u00B5S'),
                    _liveValue('Temp', '${state.temperature.toStringAsFixed(1)}\u00B0'),
                    _liveValue('SpO2', '${state.spo2.toStringAsFixed(0)}%'),
                  ],
                );
              },
            ),
          ],
          if (!connected)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Make sure device is powered on and in range',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: BioVoltColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _liveValue(String label, String value) {
    return Text(
      '$label: $value',
      style: GoogleFonts.jetBrainsMono(
        fontSize: 10,
        color: BioVoltColors.teal,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 2 — REST Connectors
  // ---------------------------------------------------------------------------

  List<Widget> _buildRestConnectors() {
    final restConnectors =
        ConnectorRegistry.instance.getByType(ConnectorType.restApi);
    if (restConnectors.isEmpty) {
      return [_emptyCard('No cloud integrations registered')];
    }
    return restConnectors.map((c) => _buildRestCard(c)).toList();
  }

  Widget _buildRestCard(BioVoltConnector connector) {
    final connected = connector.status == ConnectorStatus.connected;

    // Count Oura days
    int ouraDays = 0;
    if (connector is OuraConnector && connected) {
      ouraDays = _storage
          .getOuraRecordsInRange(
            DateTime(2020),
            DateTime.now(),
          )
          .length;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BioVoltTheme.glassCard(
        glowColor: connected ? BioVoltColors.teal : BioVoltColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_rounded,
                size: 18,
                color: connected
                    ? BioVoltColors.teal
                    : BioVoltColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  connector.displayName,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: BioVoltColors.textPrimary,
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: connected
                      ? BioVoltColors.teal
                      : BioVoltColors.textSecondary.withAlpha(80),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                connected ? 'SYNCED' : 'NOT CONNECTED',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: connected
                      ? BioVoltColors.teal
                      : BioVoltColors.textSecondary,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          if (connected) ...[
            if (connector.lastSync != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Last sync: ${_formatTime(connector.lastSync!)}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    color: BioVoltColors.textSecondary,
                  ),
                ),
              ),
            if (connector is OuraConnector && ouraDays > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Data: $ouraDays days of sleep \u2022 readiness \u2022 HRV',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    color: BioVoltColors.textSecondary,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                _ActionButton(
                  label: 'SYNC NOW',
                  color: BioVoltColors.teal,
                  onTap: () => _syncOura(connector as OuraConnector),
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  label: 'DISCONNECT',
                  color: BioVoltColors.coral,
                  onTap: () async {
                    if (connector is OuraConnector) {
                      await connector.revokeAuth();
                      setState(() {});
                    }
                  },
                ),
              ],
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Overnight sleep \u2022 HRV \u2022 readiness \u2022 skin temp',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: BioVoltColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _ActionButton(
              label: 'CONNECT',
              color: BioVoltColors.teal,
              onTap: () {
                if (connector is OuraConnector) {
                  _showOuraPatSheet(connector);
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _syncOura(OuraConnector oura) async {
    final sync = OuraSyncService(connector: oura, storage: _storage);
    await sync.forceSync(days: 7);
    if (mounted) setState(() {});
  }

  void _showOuraPatSheet(OuraConnector oura) {
    final patController = TextEditingController();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
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
                  'OURA RING PAT',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: BioVoltColors.teal,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Get your Personal Access Token at\ncloud.ouraring.com/personal-access-tokens',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: BioVoltColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: patController,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    color: BioVoltColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Paste your PAT here',
                    hintStyle: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      color: BioVoltColors.textSecondary.withAlpha(80),
                    ),
                    filled: true,
                    fillColor: BioVoltColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: BioVoltColors.cardBorder),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                saving
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: BioVoltColors.teal,
                          ),
                        ),
                      )
                    : _ActionButton(
                        label: 'SAVE & SYNC',
                        color: BioVoltColors.teal,
                        onTap: () async {
                          final pat = patController.text.trim();
                          if (pat.isEmpty) return;
                          setSheetState(() => saving = true);
                          await oura.setPersonalAccessToken(pat);
                          final sync = OuraSyncService(
                            connector: oura,
                            storage: _storage,
                          );
                          await sync.forceSync(days: 30);
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          setState(() {});
                        },
                      ),
              ],
            ),
          );
        });
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Section 3 — Manual Data Sources
  // ---------------------------------------------------------------------------

  Widget _buildManualSources() {
    final bloodworkCount = _storage.getAllBloodwork().length;

    return Column(
      children: [
        _manualSourceRow(
          icon: Icons.bloodtype_rounded,
          label: 'Bloodwork',
          status: bloodworkCount > 0
              ? '$bloodworkCount panels logged'
              : 'Not logged',
          actionLabel: '+ ADD',
          onAction: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BloodworkScreen()),
            );
          },
        ),
        _manualSourceRow(
          icon: Icons.medication_rounded,
          label: 'Supplement Protocol',
          status: 'Coming soon',
          actionLabel: '+ EDIT',
          onAction: () => _comingSoon(),
        ),
        _manualSourceRow(
          icon: Icons.biotech_rounded,
          label: 'Genetic Data',
          status: 'Not uploaded',
          actionLabel: '+ UPLOAD',
          onAction: () => _comingSoon(),
        ),
        _manualSourceRow(
          icon: Icons.bubble_chart_rounded,
          label: 'Microbiome',
          status: 'Not uploaded',
          actionLabel: '+ UPLOAD',
          onAction: () => _comingSoon(),
        ),
        _manualSourceRow(
          icon: Icons.monitor_heart_rounded,
          label: 'CGM / Glucose',
          status: 'Not connected',
          actionLabel: '+ CONNECT',
          onAction: () => _comingSoon(),
        ),
      ],
    );
  }

  Widget _manualSourceRow({
    required IconData icon,
    required String label,
    required String status,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BioVoltTheme.glassCard(glowColor: BioVoltColors.surface),
      child: Row(
        children: [
          Icon(icon, size: 18, color: BioVoltColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: BioVoltColors.textPrimary,
                  ),
                ),
                Text(
                  status,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    color: BioVoltColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: BioVoltColors.teal,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _comingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon')),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 4 — Timeline
  // ---------------------------------------------------------------------------

  Widget _buildTimeline() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Precompute which days have data
    final sessions = _storage.getSessionsInRange(
      today.subtract(const Duration(days: 30)),
      now,
    );
    final sessionDays = <int>{};
    for (final s in sessions) {
      sessionDays.add(
          DateTime(s.createdAt.year, s.createdAt.month, s.createdAt.day)
              .difference(today)
              .inDays);
    }

    final ouraRecords = _storage.getOuraRecordsInRange(
      today.subtract(const Duration(days: 30)),
      now,
    );
    final ouraDays = <int>{};
    for (final r in ouraRecords) {
      ouraDays.add(
          DateTime(r.date.year, r.date.month, r.date.day)
              .difference(today)
              .inDays);
    }

    final bloodwork = _storage.getAllBloodwork();
    final bwDays = <int>{};
    for (final b in bloodwork) {
      final diff = DateTime(b.labDate.year, b.labDate.month, b.labDate.day)
          .difference(today)
          .inDays;
      if (diff >= -30 && diff <= 0) bwDays.add(diff);
    }

    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 31,
        itemBuilder: (context, index) {
          final dayOffset = -(30 - index);
          final date = today.add(Duration(days: dayOffset));
          final hasSession = sessionDays.contains(dayOffset);
          final hasOura = ouraDays.contains(dayOffset);
          final hasBw = bwDays.contains(dayOffset);

          return SizedBox(
            width: 28,
            child: Column(
              children: [
                Text(
                  '${date.day}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 8,
                    color: dayOffset == 0
                        ? BioVoltColors.teal
                        : BioVoltColors.textSecondary,
                    fontWeight:
                        dayOffset == 0 ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _dot(hasSession ? BioVoltColors.teal : null),
                    const SizedBox(width: 2),
                    _dot(hasOura ? const Color(0xFF60A5FA) : null),
                    const SizedBox(width: 2),
                    _dot(hasBw ? BioVoltColors.coral : null),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _dot(Color? color) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        color: color ?? BioVoltColors.surface,
        borderRadius: BorderRadius.circular(1),
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

  Widget _emptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BioVoltTheme.glassCard(glowColor: BioVoltColors.surface),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            color: BioVoltColors.textSecondary,
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'today ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
