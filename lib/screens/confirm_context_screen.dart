import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/session/session_bloc.dart';
import '../bloc/session/session_event.dart';
import '../config/theme.dart';
import '../models/active_protocol.dart';
import '../models/session.dart';
import '../models/session_template.dart';
import '../models/session_type.dart';
import '../services/ble_service.dart';
import '../services/context_inferrer.dart';
import '../services/storage_service.dart';
import 'session_screen.dart';

// ---------------------------------------------------------------------------
// ConfirmContextScreen
// ---------------------------------------------------------------------------

class ConfirmContextScreen extends StatefulWidget {
  final BleService bleService;
  final SessionTemplate? template;
  final String? sessionType;
  final Session? repeatSession;

  const ConfirmContextScreen({
    super.key,
    required this.bleService,
    this.template,
    this.sessionType,
    this.repeatSession,
  });

  @override
  State<ConfirmContextScreen> createState() => _ConfirmContextScreenState();
}

class _ConfirmContextScreenState extends State<ConfirmContextScreen> {
  final StorageService _storage = StorageService();
  late final ContextInferrer _inferrer;
  late InferredContext _inferred;

  // Editable context state
  late String _sessionTypeName;
  String? _breathworkPattern;
  int? _breathworkRounds;
  double? _fastingHours;
  bool _fastingInferred = false;
  bool _bleConnected = false;

  List<ActiveProtocol> _activeProtocols = [];

  StreamSubscription<bool>? _bleSub;
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _inferrer = ContextInferrer(storage: _storage);

    final resolvedType = _resolveSessionType();
    _inferred = _inferrer.infer(sessionType: resolvedType);

    // Session type name
    _sessionTypeName =
        resolvedType[0].toUpperCase() + resolvedType.substring(1);
    // Prettify known types
    const nameMap = {
      'breathwork': 'Breathwork',
      'coldExposure': 'Cold Plunge',
      'sauna': 'Sauna',
      'meditation': 'Meditation',
      'workout': 'Workout',
      'redLight': 'Red Light',
      'grounding': 'Grounding',
      'rest': 'Rest / HRV',
      'other': 'Other',
    };
    _sessionTypeName = nameMap[resolvedType] ?? _sessionTypeName;

    // Template fields
    _breathworkPattern = widget.template?.breathworkPattern;
    _breathworkRounds = widget.template?.breathworkRounds;

    // Fasting
    _fastingHours = _inferred.fastingHours;
    _fastingInferred = _inferred.fastingInferred;

    // Protocols
    _activeProtocols = _inferred.activeProtocols;

    // BLE
    _bleSub = widget.bleService.connectionStream.listen((connected) {
      if (mounted) setState(() => _bleConnected = connected);
    });
  }

  @override
  void dispose() {
    _bleSub?.cancel();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _resolveSessionType() {
    return widget.template?.sessionType ??
        widget.sessionType ??
        widget.repeatSession?.context?.activities.firstOrNull?.type ??
        'other';
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BioVoltColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _buildSessionHeader(),
              const SizedBox(height: 20),
              _sectionLabel('CONTEXT'),
              const SizedBox(height: 8),
              _buildContextCard(),
              const SizedBox(height: 16),
              _sectionLabel('NOTE'),
              const SizedBox(height: 8),
              _buildNoteField(),
              const SizedBox(height: 24),
              _buildStartButton(),
              const SizedBox(height: 12),
              _buildBleStatus(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Session header
  // -------------------------------------------------------------------------

  Widget _buildSessionHeader() {
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
            _sessionTypeName,
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: BioVoltColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 40),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Context card
  // -------------------------------------------------------------------------

  Widget _buildContextCard() {
    final rows = <Widget>[];

    // 1. Protocol / session type
    rows.add(_contextRow(
      'Protocol',
      widget.template?.name ?? _sessionTypeName,
      inferred: false,
    ));

    // 2. Breathwork (if applicable)
    if (_breathworkPattern != null) {
      final val = StringBuffer(_humanizeBreathwork(_breathworkPattern!));
      if (_breathworkRounds != null) {
        val.write(' \u00B7 $_breathworkRounds rounds');
      }
      rows.add(_divider());
      rows.add(_contextRow('Breathwork', val.toString(), inferred: false));
    }

    // 3. Fasting
    String fastingVal;
    if (_fastingHours == null) {
      fastingVal = 'Unknown';
    } else if (_fastingHours! < 0.5) {
      fastingVal = 'Not fasting';
    } else {
      fastingVal = '${_fastingHours!.toStringAsFixed(1)} hr';
    }
    rows.add(_divider());
    rows.add(GestureDetector(
      onTap: _showFastingOverrideSheet,
      child: _contextRow('Fasting', fastingVal, inferred: _fastingInferred),
    ));

    // 4. Active protocols
    for (final p in _activeProtocols) {
      rows.add(_divider());
      rows.add(_contextRow(
        p.name,
        'Day ${p.currentCycleDay} of ${p.cycleLengthDays}',
        inferred: true,
      ));
    }

    // 5. HRV baseline
    final hrvText = _inferred.baselineHrvMs == null
        ? '< 5 sessions'
        : '${_inferred.baselineHrvMs!.toStringAsFixed(0)} ms (90d avg)';
    rows.add(_divider());
    rows.add(_contextRow('HRV baseline', hrvText, informational: true));

    // 6. Last session
    final lastText = _inferred.lastSession == null
        ? 'None'
        : _formatTimeAgo(_inferred.lastSession!.createdAt);
    rows.add(_divider());
    rows.add(_contextRow('Last session', lastText, informational: true));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: BioVoltColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BioVoltColors.cardBorder),
      ),
      child: Column(children: rows),
    );
  }

  Widget _contextRow(
    String label,
    String value, {
    bool inferred = false,
    bool informational = false,
  }) {
    final Color valueColor;
    final String displayValue;

    if (informational) {
      valueColor = BioVoltColors.textSecondary;
      displayValue = value;
    } else if (inferred) {
      valueColor = BioVoltColors.teal;
      displayValue = '\u2197 $value';
    } else {
      valueColor = BioVoltColors.textPrimary;
      displayValue = value;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
          Flexible(
            child: Text(
              displayValue,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Divider(height: 1, color: BioVoltColors.cardBorder);
  }

  // -------------------------------------------------------------------------
  // Fasting override sheet
  // -------------------------------------------------------------------------

  void _showFastingOverrideSheet() {
    final manualCtrl = TextEditingController();

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
              'OVERRIDE FASTING',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: BioVoltColors.teal,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _fastingChip(ctx, 'Not fasting', 0),
                _fastingChip(ctx, '8 hr', 8),
                _fastingChip(ctx, '12 hr', 12),
                _fastingChip(ctx, '16 hr', 16),
                _fastingChip(ctx, '18 hr', 18),
                _fastingChip(ctx, '24 hr', 24),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: manualCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      color: BioVoltColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Custom (hours)',
                      labelStyle: GoogleFonts.jetBrainsMono(
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
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    final hours = double.tryParse(manualCtrl.text);
                    if (hours != null) {
                      setState(() {
                        _fastingHours = hours;
                        _fastingInferred = false;
                      });
                      Navigator.of(ctx).pop();
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: BioVoltColors.teal.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: BioVoltColors.teal.withAlpha(80)),
                    ),
                    child: Text(
                      'SET',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _fastingChip(BuildContext ctx, String label, double hours) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _fastingHours = hours;
          _fastingInferred = false;
        });
        Navigator.of(ctx).pop();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: BioVoltColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: BioVoltColors.cardBorder),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            color: BioVoltColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Note field
  // -------------------------------------------------------------------------

  Widget _buildNoteField() {
    return TextField(
      controller: _noteCtrl,
      maxLines: 2,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        color: BioVoltColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: 'Optional note before session...',
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

  // -------------------------------------------------------------------------
  // Start button
  // -------------------------------------------------------------------------

  Widget _buildStartButton() {
    return GestureDetector(
      onTap: _startSession,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: BioVoltColors.teal.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BioVoltColors.teal, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          'START SESSION \u2192',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: BioVoltColors.teal,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // BLE status
  // -------------------------------------------------------------------------

  Widget _buildBleStatus() {
    if (_bleConnected) {
      return Center(
        child: Text.rich(
          TextSpan(children: [
            TextSpan(
              text: '\u25CF ',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: BioVoltColors.teal,
              ),
            ),
            TextSpan(
              text: 'BLE connected \u00B7 EDA + PPG active',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: BioVoltColors.textSecondary,
              ),
            ),
          ]),
        ),
      );
    }

    return Center(
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: '\u25CB ',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: BioVoltColors.amber,
            ),
          ),
          TextSpan(
            text: 'BLE disconnected \u2014 data limited',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: BioVoltColors.textSecondary,
            ),
          ),
        ]),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Start session
  // -------------------------------------------------------------------------

  void _startSession() {
    // Map string sessionType to SessionType enum
    final typeStr = _resolveSessionType();
    final sessionType = _sessionTypeFromString(typeStr);

    final bloc = context.read<SessionBloc>();

    // Set session type
    bloc.add(SessionTypeSelected(sessionType));

    // Set breathwork pattern if applicable
    if (_breathworkPattern != null) {
      bloc.add(BreathworkPatternSelected(_breathworkPattern!));
    }

    // Start session
    bloc.add(SessionStarted());

    // Increment template use count
    if (widget.template != null) {
      _storage.incrementTemplateUseCount(widget.template!.id);
    }

    // Navigate to session screen (replace so back button doesn't return here)
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: SessionScreen(bleService: widget.bleService),
        ),
      ),
    );
  }

  SessionType _sessionTypeFromString(String type) {
    switch (type) {
      case 'breathwork':
        return SessionType.breathwork;
      case 'coldExposure':
        return SessionType.coldExposure;
      case 'meditation':
        return SessionType.meditation;
      case 'grounding':
        return SessionType.grounding;
      default:
        return SessionType.fastingCheck;
    }
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  String _humanizeBreathwork(String pattern) {
    switch (pattern) {
      case 'wimHof':
        return 'Wim Hof';
      case 'box4':
      case 'box':
        return 'Box breathing';
      case 'relaxing478':
      case '4-7-8':
        return '4-7-8';
      case 'tummo':
        return 'Tummo';
      default:
        return pattern[0].toUpperCase() + pattern.substring(1);
    }
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
