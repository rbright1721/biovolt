import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/session.dart';
import '../models/session_template.dart';
import '../services/ble_service.dart';
import '../services/context_inferrer.dart';
import '../services/storage_service.dart';
import 'confirm_context_screen.dart';
import 'new_template_screen.dart';
import 'settings_screen.dart';

// ---------------------------------------------------------------------------
// Activity definitions (mirrors pre_session_screen)
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
// TemplateLauncherScreen
// ---------------------------------------------------------------------------

class TemplateLauncherScreen extends StatefulWidget {
  final BleService bleService;

  const TemplateLauncherScreen({super.key, required this.bleService});

  @override
  State<TemplateLauncherScreen> createState() => _TemplateLauncherScreenState();
}

class _TemplateLauncherScreenState extends State<TemplateLauncherScreen> {
  final StorageService _storage = StorageService();
  late final ContextInferrer _inferrer;
  List<SessionTemplate> _templates = [];
  Session? _lastSession;

  @override
  void initState() {
    super.initState();
    _inferrer = ContextInferrer(storage: _storage);
    _loadData();
  }

  void _loadData() {
    final inferred = _inferrer.infer();
    setState(() {
      _templates = _storage.getAllTemplates();
      _lastSession = inferred.lastSession;
    });
  }

  void _loadTemplates() {
    setState(() {
      _templates = _storage.getAllTemplates();
    });
  }

  // -------------------------------------------------------------------------
  // Navigation
  // -------------------------------------------------------------------------

  void _launchSession(
    BuildContext context, {
    String? sessionType,
    SessionTemplate? template,
    Session? repeatSession,
  }) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => ConfirmContextScreen(
          bleService: widget.bleService,
          template: template,
          sessionType: sessionType,
          repeatSession: repeatSession,
        ),
      ),
    )
        .then((_) {
      _loadTemplates();
    });
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 12),
            _buildHeaderRow(),
            const SizedBox(height: 16),
            if (_shouldShowLastSession) ...[
              _sectionLabel('REPEAT LAST'),
              const SizedBox(height: 8),
              _buildLastSessionCard(),
              const SizedBox(height: 20),
            ],
            _sectionLabel('MY TEMPLATES'),
            const SizedBox(height: 8),
            _buildTemplateList(),
            const SizedBox(height: 20),
            _sectionLabel('NEW SESSION'),
            const SizedBox(height: 10),
            _buildActivityGrid(),
            const SizedBox(height: 16),
            _buildNewTemplateButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // 1. Header
  // -------------------------------------------------------------------------

  Widget _buildHeaderRow() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: BioVoltColors.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        Text(
          'START SESSION',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: BioVoltColors.teal,
            letterSpacing: 2,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.settings_rounded,
              color: BioVoltColors.textSecondary, size: 20),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // 2. Last session quick-repeat
  // -------------------------------------------------------------------------

  bool get _shouldShowLastSession {
    if (_lastSession == null) return false;
    final age = DateTime.now().difference(_lastSession!.createdAt);
    return age.inDays < 7;
  }

  Widget _buildLastSessionCard() {
    final session = _lastSession!;
    final activityType =
        session.context?.activities.firstOrNull?.type ?? 'session';
    final humanized =
        activityType[0].toUpperCase() + activityType.substring(1);
    final ago = _formatTimeAgo(session.createdAt);

    return GestureDetector(
      onTap: () =>
          _launchSession(context, repeatSession: session),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BioVoltColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BioVoltColors.cardBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.replay_rounded,
                color: BioVoltColors.teal, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    humanized,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: BioVoltColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ago,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: BioVoltColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: BioVoltColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h hour${h == 1 ? '' : 's'} ago';
    }
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays} days ago';
  }

  // -------------------------------------------------------------------------
  // 3-4. Template list
  // -------------------------------------------------------------------------

  Widget _buildTemplateList() {
    if (_templates.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'No templates yet \u2014 create one below',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: BioVoltColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Column(
      children: _templates
          .map((t) => _buildTemplateCard(t))
          .toList(),
    );
  }

  Widget _buildTemplateCard(SessionTemplate template) {
    final iconChar = _iconForSessionType(template.sessionType);
    final subtitle = _templateSubtitle(template);

    return GestureDetector(
      onTap: () =>
          _launchSession(context, template: template),
      onLongPress: () => _showTemplateOptions(template),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BioVoltColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BioVoltColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(iconChar, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    template.name,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: BioVoltColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${template.useCount}\u00D7',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: BioVoltColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    color: BioVoltColors.textSecondary, size: 18),
              ],
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Text(
                  subtitle,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: BioVoltColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _iconForSessionType(String sessionType) {
    for (final a in _activities) {
      if (a.id == sessionType) return a.icon;
    }
    return '\u{1F4E6}';
  }

  String _templateSubtitle(SessionTemplate template) {
    if (template.breathworkPattern != null) {
      return _humanizeBreathwork(template.breathworkPattern!);
    }
    if (template.coldTempF != null || template.coldDurationMin != null) {
      final parts = <String>[];
      if (template.coldTempF != null) {
        parts.add('${template.coldTempF!.toStringAsFixed(0)}\u00B0F');
      }
      if (template.coldDurationMin != null) {
        parts.add('${template.coldDurationMin} min');
      }
      return parts.join(' \u2022 ');
    }
    if (template.notes != null && template.notes!.isNotEmpty) {
      final preview = template.notes!;
      return preview.length > 40 ? '${preview.substring(0, 40)}\u2026' : preview;
    }
    return '';
  }

  String _humanizeBreathwork(String pattern) {
    switch (pattern) {
      case 'wimHof':
        return 'Wim Hof';
      case 'box4':
        return 'Box Breathing';
      case 'relaxing478':
        return '4-7-8 Relaxing';
      case 'tummo':
        return 'Tummo';
      default:
        return pattern[0].toUpperCase() + pattern.substring(1);
    }
  }

  void _showTemplateOptions(SessionTemplate template) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: BioVoltColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            ListTile(
              leading: const Icon(Icons.edit_rounded,
                  color: BioVoltColors.textSecondary, size: 20),
              title: Text(
                'Edit template',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  color: BioVoltColors.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: BioVoltColors.surface,
                    content: Text(
                      'Coming soon',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: BioVoltColors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: BioVoltColors.coral, size: 20),
              title: Text(
                'Delete template',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  color: BioVoltColors.coral,
                ),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                await _storage.deleteTemplate(template.id);
                _loadTemplates();
              },
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // 5-6. New session activity grid
  // -------------------------------------------------------------------------

  Widget _buildActivityGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _activities.map((a) {
        return GestureDetector(
          onTap: () => _launchSession(context, sessionType: a.id),
          child: SizedBox(
            width: (MediaQuery.of(context).size.width - 32 - 16) / 3,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: BioVoltColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BioVoltColors.cardBorder),
              ),
              child: Column(
                children: [
                  Text(a.icon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 6),
                  Text(
                    a.label,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: BioVoltColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // -------------------------------------------------------------------------
  // 7. New template button
  // -------------------------------------------------------------------------

  Widget _buildNewTemplateButton() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context)
            .push(
          MaterialPageRoute(
            builder: (_) =>
                NewTemplateScreen(bleService: widget.bleService),
          ),
        )
            .then((_) {
          _loadTemplates();
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: BioVoltColors.teal.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: BioVoltColors.teal.withAlpha(80), width: 1.5),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded,
                color: BioVoltColors.teal, size: 16),
            const SizedBox(width: 6),
            Text(
              'NEW TEMPLATE',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: BioVoltColors.teal,
                letterSpacing: 1,
              ),
            ),
          ],
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
}
