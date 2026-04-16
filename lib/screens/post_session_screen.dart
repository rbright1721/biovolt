import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../bloc/session/session_bloc.dart';
import '../config/theme.dart';
import '../models/session.dart';
import '../models/session_type.dart';
import '../services/ai_service.dart';
import '../services/prompt_builder.dart';
import '../services/storage_service.dart';
import 'analysis_screen.dart';

class PostSessionScreen extends StatefulWidget {
  final Session session;

  const PostSessionScreen({super.key, required this.session});

  @override
  State<PostSessionScreen> createState() => _PostSessionScreenState();
}

class _PostSessionScreenState extends State<PostSessionScreen> {
  // Subjective sliders
  double _energy = 5;
  double _mood = 5;
  double _focus = 5;
  double _calm = 5;
  double _physical = 5;
  int _sessionQuality = 0;

  final _notableCtrl = TextEditingController();
  final _sideEffectsCtrl = TextEditingController();

  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _voiceTranscript = '';

  bool _hasKey = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    AiService().hasValidKey().then((v) {
      if (mounted) setState(() => _hasKey = v);
    });
    _speech.initialize().then((available) {
      if (mounted) setState(() => _speechAvailable = available);
    });
  }

  @override
  void dispose() {
    _speech.stop();
    _notableCtrl.dispose();
    _sideEffectsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final type = _sessionTypeFrom(session);
    final durationStr = _formatDuration(session.durationSeconds);
    final hrSource = session.biometrics?.computed?.hrSource ?? 'PPG';

    return Scaffold(
      backgroundColor: BioVoltColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: BioVoltColors.teal, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'SESSION COMPLETE',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: BioVoltColors.teal,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${type?.displayName ?? 'Session'}  \u2022  $durationStr  \u2022  $hrSource',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: BioVoltColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Quick stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildQuickStats(),
            ),
            const SizedBox(height: 8),
            // Scrollable content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 12),
                  _sectionLabel('HOW DO YOU FEEL NOW?'),
                  const SizedBox(height: 10),
                  _buildSubjective(),
                  const SizedBox(height: 20),
                  _buildVoiceNoteField(),
                  const SizedBox(height: 10),
                  _buildSideEffectsAndQuality(),
                  const SizedBox(height: 20),
                  _buildAiSection(),
                  const SizedBox(height: 24),
                  _buildButtons(),
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
  // Quick stats
  // ---------------------------------------------------------------------------

  Widget _buildQuickStats() {
    final c = widget.session.biometrics?.computed;
    final e = widget.session.biometrics?.esp32;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _statChip('HRV', c?.hrvRmssdMs != null
              ? '${c!.hrvRmssdMs!.toStringAsFixed(0)}ms'
              : '--'),
          _statChip('HR', c?.heartRateMeanBpm != null
              ? '${c!.heartRateMeanBpm!.toStringAsFixed(0)}bpm'
              : '--'),
          _statChip('GSR', e?.gsrMeanUs != null
              ? '${e!.gsrMeanUs!.toStringAsFixed(1)}\u00B5S'
              : '--'),
          _statChip('SpO2', e?.spo2Percent != null
              ? '${e!.spo2Percent!.toStringAsFixed(0)}%'
              : '--'),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BioVoltTheme.glassCard(glowColor: BioVoltColors.teal),
      child: Column(
        children: [
          Text(label,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 9, color: BioVoltColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value,
              style: BioVoltTheme.valueStyle(13, color: BioVoltColors.teal)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Subjective sliders
  // ---------------------------------------------------------------------------

  Widget _buildSubjective() {
    return Column(
      children: [
        _slider('Energy', '\u{1F634}', '\u{26A1}', _energy,
            (v) => setState(() => _energy = v)),
        _slider('Mood', '\u{1F614}', '\u{1F60A}', _mood,
            (v) => setState(() => _mood = v)),
        _slider('Focus', '\u{1F635}', '\u{1F3AF}', _focus,
            (v) => setState(() => _focus = v)),
        _slider('Calm', '\u{1F630}', '\u{1F60C}', _calm,
            (v) => setState(() => _calm = v)),
        _slider('Physical', '\u{1F915}', '\u{1F4AA}', _physical,
            (v) => setState(() => _physical = v)),
      ],
    );
  }

  Widget _slider(String label, String leftEmoji, String rightEmoji,
      double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(label,
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 10, color: BioVoltColors.textSecondary)),
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
          Text('${value.round()}/10',
              style: BioVoltTheme.valueStyle(11, color: BioVoltColors.teal)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Notes + quality
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Voice note field (replaces notable effects text area)
  // ---------------------------------------------------------------------------

  Widget _buildVoiceNoteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row
        Row(
          children: [
            _sectionLabel('NOTABLE EFFECTS'),
            const Spacer(),
            if (_speechAvailable)
              GestureDetector(
                onTap: _toggleListening,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _isListening
                        ? BioVoltColors.teal.withAlpha(30)
                        : BioVoltColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isListening
                          ? BioVoltColors.teal
                          : BioVoltColors.cardBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isListening
                            ? Icons.stop_rounded
                            : Icons.mic_rounded,
                        size: 14,
                        color: _isListening
                            ? BioVoltColors.teal
                            : BioVoltColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isListening ? 'STOP' : 'VOICE',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _isListening
                              ? BioVoltColors.teal
                              : BioVoltColors.textSecondary,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Transcript display
        if (_voiceTranscript.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: BioVoltColors.teal.withAlpha(15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: BioVoltColors.teal.withAlpha(60)),
            ),
            child: Text(
              _voiceTranscript,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: BioVoltColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),

        // Listening indicator
        if (_isListening)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 8,
                  height: 8,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: BioVoltColors.teal,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Listening...',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: BioVoltColors.teal,
                  ),
                ),
              ],
            ),
          ),

        // Text field
        TextField(
          controller: _notableCtrl,
          maxLines: 3,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            color: BioVoltColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: _speechAvailable
                ? 'Type or use voice above...'
                : 'Notable effects, observations...',
            hintStyle: GoogleFonts.jetBrainsMono(
              fontSize: 11,
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
            contentPadding: const EdgeInsets.all(10),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      // Append transcript to the text field
      if (_voiceTranscript.isNotEmpty) {
        final existing = _notableCtrl.text.trim();
        _notableCtrl.text = existing.isEmpty
            ? _voiceTranscript
            : '$existing. $_voiceTranscript';
      }
    } else {
      setState(() {
        _isListening = true;
        _voiceTranscript = '';
      });
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _voiceTranscript = result.recognizedWords;
          });
        },
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 4),
        localeId: 'en_US',
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Side effects + quality (split from old _buildNotesSection)
  // ---------------------------------------------------------------------------

  Widget _buildSideEffectsAndQuality() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Side effects?',
            style: GoogleFonts.jetBrainsMono(
                fontSize: 10, color: BioVoltColors.textSecondary)),
        const SizedBox(height: 6),
        _textArea(_sideEffectsCtrl),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('Session quality:',
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 10, color: BioVoltColors.textSecondary)),
            const SizedBox(width: 8),
            for (int i = 1; i <= 5; i++)
              GestureDetector(
                onTap: () => setState(() => _sessionQuality = i),
                child: Icon(
                  i <= _sessionQuality
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: i <= _sessionQuality
                      ? BioVoltColors.amber
                      : BioVoltColors.textSecondary.withAlpha(80),
                  size: 24,
                ),
              ),
            if (_sessionQuality > 0)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text('$_sessionQuality/5',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 10, color: BioVoltColors.amber)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _textArea(TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      maxLines: 2,
      style: GoogleFonts.jetBrainsMono(
          fontSize: 11, color: BioVoltColors.textPrimary),
      decoration: InputDecoration(
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
        contentPadding: const EdgeInsets.all(10),
        isDense: true,
        hintText: 'Optional',
        hintStyle: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            color: BioVoltColors.textSecondary.withAlpha(80)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AI section
  // ---------------------------------------------------------------------------

  Widget _buildAiSection() {
    if (_hasKey) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BioVoltTheme.glassCard(glowColor: BioVoltColors.teal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    size: 16, color: BioVoltColors.teal),
                const SizedBox(width: 8),
                Text('AI Coach Analysis',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BioVoltColors.teal)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your API key is configured. Analysis will run in the background '
              'using your full biological context.',
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: BioVoltColors.textSecondary,
                  height: 1.5),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BioVoltTheme.glassCard(glowColor: BioVoltColors.surface),
      child: Column(
        children: [
          const Icon(Icons.vpn_key_rounded,
              size: 20, color: BioVoltColors.textSecondary),
          const SizedBox(height: 8),
          Text('Add API Key for AI Analysis',
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 11, color: BioVoltColors.textSecondary)),
          const SizedBox(height: 4),
          Text('Connect Claude or OpenAI in Settings',
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: BioVoltColors.textSecondary.withAlpha(120))),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Buttons
  // ---------------------------------------------------------------------------

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _saving ? null : () => _save(analyze: false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: BioVoltColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BioVoltColors.cardBorder),
              ),
              alignment: Alignment.center,
              child: Text('SKIP & SAVE',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: BioVoltColors.textSecondary,
                      letterSpacing: 1)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: _saving ? null : () => _save(analyze: true),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: BioVoltColors.teal.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: BioVoltColors.teal.withAlpha(120), width: 2),
              ),
              alignment: Alignment.center,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: BioVoltColors.teal),
                    )
                  : Text('SAVE & ANALYZE \u2192',
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: BioVoltColors.teal,
                          letterSpacing: 1)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save({required bool analyze}) async {
    setState(() => _saving = true);

    // Build post-session subjective scores
    final postScores = SubjectiveScores(
      energy: _energy.round(),
      mood: _mood.round(),
      focus: _focus.round(),
      calm: _calm.round(),
      physicalFeeling: _physical.round(),
      sessionQuality: _sessionQuality > 0 ? _sessionQuality * 2 : null,
      notableEffects: _notableCtrl.text.trim().isEmpty
          ? null
          : _notableCtrl.text.trim(),
      sideEffects: _sideEffectsCtrl.text.trim().isEmpty
          ? null
          : _sideEffectsCtrl.text.trim(),
    );

    // Update session with post-session subjective
    final updatedSession = Session(
      sessionId: widget.session.sessionId,
      userId: widget.session.userId,
      createdAt: widget.session.createdAt,
      timezone: widget.session.timezone,
      durationSeconds: widget.session.durationSeconds,
      dataSources: widget.session.dataSources,
      context: widget.session.context,
      biometrics: widget.session.biometrics,
      subjective: SessionSubjective(
        preSession: widget.session.subjective?.preSession,
        postSession: postScores,
      ),
    );

    final storage = StorageService();
    await storage.saveSession(updatedSession);

    // Trigger AI analysis in background if requested and key available
    if (analyze && _hasKey) {
      final aiService = AiService();
      final promptBuilder = PromptBuilder(storage: storage);
      final prompt =
          await promptBuilder.buildSessionPrompt(updatedSession.sessionId);
      // Fire and forget — analysis will be picked up by AnalysisScreen
      aiService
          .analyzeSession(
            updatedSession.sessionId,
            prompt,
            systemPrompt: PromptBuilder.systemPrompt,
            ouraContextUsed: promptBuilder.lastPromptUsedOura,
          )
          .then((_) {}, onError: (_) {});
    }

    if (!mounted) return;

    // Navigate to analysis screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<SessionBloc>(),
          child: AnalysisScreen(
            session: updatedSession,
            analysis: null, // will be populated via BlocListener when ready
          ),
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

  SessionType? _sessionTypeFrom(Session session) {
    final typeName = session.context?.activities.firstOrNull?.type;
    if (typeName == null) return null;
    for (final t in SessionType.values) {
      if (t.name == typeName) return t;
    }
    return null;
  }

  String _formatDuration(int? seconds) {
    if (seconds == null) return '--:--';
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
