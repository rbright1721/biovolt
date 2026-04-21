import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../connectors/connector_base.dart';
import '../connectors/connector_oura.dart';
import '../connectors/connector_registry.dart';
import '../models/normalized_record.dart';
import '../services/auth_service.dart';
import '../services/oura_sync_service.dart';
import '../services/storage_service.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final StorageService _storage;

  // Data stats
  int _sessionCount = 0;
  String _dateRange = '';
  String _ouraRange = '';

  @override
  void initState() {
    super.initState();
    _storage = StorageService();
    _loadStats();
  }

  void _loadStats() {
    final sessions = _storage.getAllSessions();
    final ouraRecords = _storage.getOuraRecordsInRange(
      DateTime(2020),
      DateTime.now(),
    );

    setState(() {
      _sessionCount = sessions.length;
      if (sessions.isNotEmpty) {
        final oldest = sessions.last.createdAt;
        final newest = sessions.first.createdAt;
        _dateRange =
            '${oldest.month}/${oldest.day}/${oldest.year} \u2192 ${newest.month}/${newest.day}/${newest.year}';
      } else {
        _dateRange = 'None';
      }
      if (ouraRecords.isNotEmpty) {
        final oldest = ouraRecords.first.date;
        final newest = ouraRecords.last.date;
        _ouraRange =
            '${oldest.month}/${oldest.day}/${oldest.year} \u2192 ${newest.month}/${newest.day}/${newest.year}';
      } else {
        _ouraRange = 'None';
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BioVoltColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'SETTINGS',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: BioVoltColors.teal,
                  letterSpacing: 3,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 8),
                  _buildProfileButton(),
                  const SizedBox(height: 24),
                  _buildAiSection(),
                  const SizedBox(height: 24),
                  _buildDevicesSection(),
                  const SizedBox(height: 24),
                  _buildDataSection(),
                  const SizedBox(height: 24),
                  _buildAccountSection(),
                  const SizedBox(height: 24),
                  _buildAboutSection(),
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
  // AI Configuration
  // ---------------------------------------------------------------------------

  Widget _buildProfileButton() {
    final profile = _storage.getUserProfile();
    final hasProfile = profile != null && profile.healthGoals.isNotEmpty;

    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
        _loadStats();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BioVoltTheme.glassCard(
          glowColor: hasProfile ? BioVoltColors.teal : BioVoltColors.amber,
        ),
        child: Row(
          children: [
            Icon(
              Icons.person_rounded,
              size: 20,
              color: hasProfile
                  ? BioVoltColors.teal
                  : BioVoltColors.amber,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasProfile ? 'EDIT PROFILE' : 'SET UP PROFILE',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: BioVoltColors.textPrimary,
                    ),
                  ),
                  Text(
                    hasProfile
                        ? 'Goals: ${profile.healthGoals.join(', ')}'
                        : 'Required for personalized AI analysis',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      color: BioVoltColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: BioVoltColors.textSecondary.withAlpha(80),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiSection() {
    return _Section(
      title: 'AI ANALYSIS',
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BioVoltColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BioVoltColors.cardBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 18, color: BioVoltColors.teal),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI analysis powered by Claude',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BioVoltColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'No API key required.',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: BioVoltColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: BioVoltColors.teal,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: BioVoltColors.teal.withAlpha(100),
                        blurRadius: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Connected Devices
  // ---------------------------------------------------------------------------

  Widget _buildDevicesSection() {
    final connectors = ConnectorRegistry.instance.getAll();

    return _Section(
      title: 'CONNECTED DEVICES',
      children: connectors.map((c) => _buildDeviceCard(c)).toList(),
    );
  }

  Widget _buildDeviceCard(BioVoltConnector connector) {
    final isConnected = connector.status == ConnectorStatus.connected;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BioVoltTheme.glassCard(
        glowColor: isConnected ? BioVoltColors.teal : BioVoltColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                connector.type == ConnectorType.ble
                    ? Icons.bluetooth_rounded
                    : Icons.cloud_rounded,
                size: 20,
                color: isConnected
                    ? BioVoltColors.teal
                    : BioVoltColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connector.displayName,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: BioVoltColors.textPrimary,
                      ),
                    ),
                    Text(
                      connector.connectorId,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        color: BioVoltColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isConnected
                      ? BioVoltColors.teal
                      : BioVoltColors.textSecondary.withAlpha(80),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isConnected ? 'Connected' : 'Disconnected',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: isConnected
                      ? BioVoltColors.teal
                      : BioVoltColors.textSecondary,
                ),
              ),
            ],
          ),
          if (connector.lastSync != null) ...[
            const SizedBox(height: 4),
            Text(
              'Last sync: ${_formatTime(connector.lastSync!)}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                color: BioVoltColors.textSecondary,
              ),
            ),
          ],
          if (connector is OuraConnector && !isConnected) ...[
            const SizedBox(height: 10),
            _ActionButton(
              label: 'CONNECT \u2014 ENTER PAT',
              color: BioVoltColors.teal,
              onTap: () => _showOuraPatSheet(connector),
            ),
          ],
        ],
      ),
    );
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
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
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
                      borderSide:
                          BorderSide(color: BioVoltColors.cardBorder),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: saving
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
                            // Trigger sync
                            final sync = OuraSyncService(
                              connector: oura,
                              storage: _storage,
                            );
                            await sync.forceSync(days: 30);
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            _loadStats();
                            setState(() {});
                          },
                        ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  Widget _buildDataSection() {
    return _Section(
      title: 'DATA',
      children: [
        _statRow('Sessions recorded', '$_sessionCount'),
        _statRow('Date range', _dateRange),
        _statRow('Oura data', _ouraRange),
        const SizedBox(height: 12),
        Row(
          children: [
            _ActionButton(
              label: 'EXPORT JSON',
              color: BioVoltColors.teal,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Export coming soon')),
                );
              },
            ),
            const SizedBox(width: 8),
            _ActionButton(
              label: 'CLEAR ALL',
              color: BioVoltColors.coral,
              onTap: _confirmClear,
            ),
          ],
        ),
      ],
    );
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BioVoltColors.surface,
        title: Text(
          'Clear all data?',
          style: GoogleFonts.jetBrainsMono(
            color: BioVoltColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'This will delete all sessions, Oura records, and AI analyses. This cannot be undone.',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            color: BioVoltColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: GoogleFonts.jetBrainsMono(
                    color: BioVoltColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              await _storage.clearAll();
              if (ctx.mounted) Navigator.of(ctx).pop();
              _loadStats();
            },
            child: Text('Delete',
                style: GoogleFonts.jetBrainsMono(
                    color: BioVoltColors.coral)),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: BioVoltColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: BioVoltColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Account
  // ---------------------------------------------------------------------------

  Widget _buildAccountSection() {
    final auth = AuthService();
    return _Section(
      title: 'ACCOUNT',
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BioVoltTheme.glassCard(),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.account_circle_rounded,
                      color: BioVoltColors.teal, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.displayName,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: BioVoltColors.textPrimary,
                          ),
                        ),
                        if (auth.email != null)
                          Text(
                            auth.email!,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              color: BioVoltColors.textSecondary,
                            ),
                          )
                        else
                          Text(
                            'Guest account \u2014 data saved locally',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              color: BioVoltColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final nav = Navigator.of(context);
                  await auth.signOut();
                  nav.pushNamedAndRemoveUntil('/', (route) => false);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: BioVoltColors.cardBorder),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'SIGN OUT',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: BioVoltColors.textSecondary,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  // ---------------------------------------------------------------------------
  // About
  // ---------------------------------------------------------------------------

  Widget _buildAboutSection() {
    return _Section(
      title: 'ABOUT',
      children: [
        _statRow('Version', '1.0.0'),
        _statRow('Schema version', '2.0'),
        _statRow('Prompt sequence', '7/17'),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}

// =============================================================================
// Shared building blocks
// =============================================================================

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: BioVoltColors.teal,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
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
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? color.withAlpha(15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? color.withAlpha(80) : BioVoltColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: enabled ? color : BioVoltColors.textSecondary.withAlpha(80),
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
