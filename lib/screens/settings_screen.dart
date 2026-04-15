import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../connectors/connector_base.dart';
import '../connectors/connector_oura.dart';
import '../connectors/connector_registry.dart';
import '../models/normalized_record.dart';
import '../services/ai_config_service.dart';
import '../services/ai_service.dart';
import '../services/oura_sync_service.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final AiService _aiService;
  late final AiConfigService _aiConfigService;
  late final StorageService _storage;

  // AI config state
  AiConfig _aiConfig = const AiConfig();
  final _keyController = TextEditingController();
  bool _keyObscured = true;
  bool _testing = false;
  String? _keyError;

  // Data stats
  int _sessionCount = 0;
  String _dateRange = '';
  String _ouraRange = '';

  @override
  void initState() {
    super.initState();
    _aiService = AiService();
    _aiConfigService = AiConfigService(aiService: _aiService);
    _storage = StorageService();
    _loadConfig();
    _loadStats();
  }

  Future<void> _loadConfig() async {
    final config = await _aiConfigService.getConfig();
    if (mounted) setState(() => _aiConfig = config);
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
    _keyController.dispose();
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
                  _buildAiSection(),
                  const SizedBox(height: 24),
                  _buildDevicesSection(),
                  const SizedBox(height: 24),
                  _buildDataSection(),
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

  Widget _buildAiSection() {
    return _Section(
      title: 'AI CONFIGURATION',
      children: [
        // Provider toggle
        _label('AI Provider'),
        const SizedBox(height: 8),
        Row(
          children: [
            _ProviderChip(
              label: 'Claude (Anthropic)',
              selected: _aiConfig.provider == 'anthropic' ||
                  _aiConfig.provider == null,
              onTap: () async {
                await _aiConfigService.setProvider('anthropic');
                _loadConfig();
              },
            ),
            const SizedBox(width: 8),
            _ProviderChip(
              label: 'ChatGPT (OpenAI)',
              selected: _aiConfig.provider == 'openai',
              onTap: () async {
                await _aiConfigService.setProvider('openai');
                _loadConfig();
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // API Key field
        _label('API Key'),
        const SizedBox(height: 8),
        TextField(
          controller: _keyController,
          obscureText: _keyObscured,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            color: BioVoltColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: _aiConfig.provider == 'openai'
                ? 'sk-...'
                : 'sk-ant-...',
            hintStyle: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              color: BioVoltColors.textSecondary.withAlpha(80),
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
            suffixIcon: IconButton(
              icon: Icon(
                _keyObscured
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 18,
                color: BioVoltColors.textSecondary,
              ),
              onPressed: () =>
                  setState(() => _keyObscured = !_keyObscured),
            ),
            errorText: _keyError,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _ActionButton(
              label: 'TEST KEY',
              color: BioVoltColors.amber,
              onTap: _aiConfig.hasKey ? _testKey : null,
            ),
            const SizedBox(width: 8),
            _ActionButton(
              label: 'SAVE',
              color: BioVoltColors.teal,
              onTap: _saveKey,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Status indicator
        _buildKeyStatus(),
        const SizedBox(height: 12),

        // Help text
        _ExpandableHelp(),
      ],
    );
  }

  Widget _buildKeyStatus() {
    Color dotColor;
    String statusText;

    if (_testing) {
      return Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: BioVoltColors.amber,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Testing...',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: BioVoltColors.amber,
            ),
          ),
        ],
      );
    }

    if (_aiConfig.hasKey && _aiConfig.keyTested) {
      dotColor = BioVoltColors.teal;
      statusText = 'Key valid and tested';
    } else if (_aiConfig.hasKey) {
      dotColor = BioVoltColors.amber;
      statusText = 'Key saved, not tested';
    } else {
      dotColor = BioVoltColors.coral;
      statusText = 'No key configured';
    }

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: dotColor.withAlpha(100), blurRadius: 6),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          statusText,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            color: dotColor,
          ),
        ),
      ],
    );
  }

  Future<void> _saveKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;

    try {
      await _aiConfigService.setApiKey(key);
      setState(() => _keyError = null);
      await _loadConfig();
      // Auto-test after save
      await _testKey();
    } on AiAuthException catch (e) {
      setState(() => _keyError = e.message);
    }
  }

  Future<void> _testKey() async {
    setState(() => _testing = true);
    final success = await _aiConfigService.testKey();
    await _loadConfig();
    if (mounted) {
      setState(() {
        _testing = false;
        if (!success) _keyError = 'Key test failed — check key and try again';
      });
    }
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

  Widget _label(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: BioVoltColors.textSecondary,
        letterSpacing: 1.5,
      ),
    );
  }

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

class _ProviderChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ProviderChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color:
                selected ? BioVoltColors.teal : BioVoltColors.textSecondary,
          ),
        ),
      ),
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

class _ExpandableHelp extends StatefulWidget {
  @override
  State<_ExpandableHelp> createState() => _ExpandableHelpState();
}

class _ExpandableHelpState extends State<_ExpandableHelp> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              Icon(
                Icons.help_outline_rounded,
                size: 14,
                color: BioVoltColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'How API keys work',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: BioVoltColors.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: BioVoltColors.textSecondary,
              ),
            ],
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BioVoltColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: BioVoltColors.cardBorder),
            ),
            child: Text(
              'Your key is stored only on this device using Android Keystore. '
              'It is never sent to BioVolt servers. API calls go directly from '
              'your device to Anthropic/OpenAI.\n\n'
              'Get a Claude key: console.anthropic.com\n'
              'Get an OpenAI key: platform.openai.com',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: BioVoltColors.textSecondary,
                height: 1.6,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
