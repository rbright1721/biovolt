import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../bloc/sensors/sensors_bloc.dart';
import '../config/theme.dart';
import '../models/health_journal_entry.dart';
import '../models/vitals_bookmark.dart';
import '../services/ai_service.dart';
import '../services/ble_service.dart';
import '../services/context_inferrer.dart';
import '../services/storage_service.dart';

class JournalScreen extends StatefulWidget {
  final BleService bleService;

  /// When true, start the voice-to-text session as soon as the screen
  /// mounts. Used by the home-screen widget's "NOTE" button so a tap
  /// lands the user straight into dictation.
  final bool autoStartVoice;

  const JournalScreen({
    super.key,
    required this.bleService,
    this.autoStartVoice = false,
  });

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final StorageService _storage = StorageService();
  final AiService _aiService = AiService();
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final SpeechToText _speech = SpeechToText();

  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isLoading = false;
  List<HealthJournalEntry> _entries = [];

  static const List<String> _tagKeywords = [
    'nac',
    'bpc',
    'glycine',
    'sleep',
    'hrv',
    'fast',
    'gi',
    'stomach',
    'energy',
    'dose',
    'pain',
    'mood',
  ];

  @override
  void initState() {
    super.initState();
    _speech.initialize().then((v) {
      if (!mounted) return;
      setState(() => _speechAvailable = v);
      // If opened from the home-screen widget's NOTE button, jump
      // straight into listening once speech is ready.
      if (v && widget.autoStartVoice && !_isListening) {
        _toggleListening();
      }
    });
    _loadEntries();
  }

  @override
  void dispose() {
    _speech.stop();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _loadEntries() {
    setState(() {
      _entries = _storage.getAllJournalEntries();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Display oldest first in the list
    final displayEntries =
        _entries.reversed.toList(growable: false);

    return Scaffold(
      backgroundColor: BioVoltColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: displayEntries.isEmpty && !_isLoading
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount: displayEntries.length +
                          (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= displayEntries.length) {
                          return _buildLoadingBubble();
                        }
                        return _buildEntry(displayEntries[index]);
                      },
                    ),
            ),
            _buildInputRow(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: BioVoltColors.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'HEALTH JOURNAL',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: BioVoltColors.teal,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.chat_bubble_outline_rounded,
            color: BioVoltColors.textSecondary.withAlpha(120),
            size: 18,
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              color: BioVoltColors.textSecondary.withAlpha(80),
              size: 42,
            ),
            const SizedBox(height: 16),
            Text(
              'Start a conversation',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: BioVoltColors.textPrimary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ask about symptoms, protocols,\nor how you feel right now.',
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: BioVoltColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Entry bubbles
  // ---------------------------------------------------------------------------

  Widget _buildEntry(HealthJournalEntry entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildUserBubble(entry),
        const SizedBox(height: 8),
        _buildAiBubble(entry),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildUserBubble(HealthJournalEntry entry) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const SizedBox(width: 40),
        Flexible(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            decoration: BoxDecoration(
              color: BioVoltColors.teal.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BioVoltColors.teal.withAlpha(120)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  entry.userMessage,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    color: BioVoltColors.textPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(entry.timestamp),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: BioVoltColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _toggleBookmark(entry),
                      behavior: HitTestBehavior.opaque,
                      child: Icon(
                        entry.bookmarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_outline_rounded,
                        size: 14,
                        color: entry.bookmarked
                            ? BioVoltColors.teal
                            : BioVoltColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAiBubble(HealthJournalEntry entry) {
    final vitalChips = _buildVitalChips(entry);

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BioVoltColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BioVoltColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.aiResponse,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    color: BioVoltColors.textPrimary,
                    height: 1.6,
                  ),
                ),
                if (entry.researchGrounded)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.science_rounded,
                          size: 11,
                          color: BioVoltColors.teal,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'grounded in PubMed research',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            color: BioVoltColors.teal,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (entry.bookmarked) ...[
                  const SizedBox(height: 8),
                  Text(
                    '\u25CF saved to timeline',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: BioVoltColors.teal,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
                if (vitalChips.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: vitalChips,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 40),
      ],
    );
  }

  List<Widget> _buildVitalChips(HealthJournalEntry e) {
    final chips = <Widget>[];
    if (e.hrBpm != null) {
      chips.add(_vitalChip('HR', '${e.hrBpm!.toStringAsFixed(0)} bpm'));
    }
    if (e.hrvMs != null) {
      chips.add(_vitalChip('HRV', '${e.hrvMs!.toStringAsFixed(0)} ms'));
    }
    if (e.gsrUs != null) {
      chips.add(_vitalChip('GSR', '${e.gsrUs!.toStringAsFixed(1)} \u00B5S'));
    }
    if (e.spo2Percent != null) {
      chips.add(
          _vitalChip('SpO2', '${e.spo2Percent!.toStringAsFixed(0)}%'));
    }
    return chips;
  }

  Widget _vitalChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: BioVoltColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: BioVoltColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              color: BioVoltColors.textSecondary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: BioVoltColors.teal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BioVoltColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BioVoltColors.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: BioVoltColors.teal,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'thinking...',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: BioVoltColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Input row
  // ---------------------------------------------------------------------------

  Widget _buildInputRow() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: BioVoltColors.background,
        border: Border(
          top: BorderSide(color: BioVoltColors.cardBorder, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              minLines: 1,
              maxLines: 4,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                color: BioVoltColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Ask about symptoms, protocols, how you feel...',
                hintStyle: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: BioVoltColors.textSecondary,
                ),
                filled: true,
                fillColor: BioVoltColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: BioVoltColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: BioVoltColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: BioVoltColors.teal),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
          ),
          if (_speechAvailable) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _toggleListening,
              child: Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: _isListening
                      ? BioVoltColors.teal.withAlpha(40)
                      : BioVoltColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isListening
                        ? BioVoltColors.teal
                        : BioVoltColors.cardBorder,
                  ),
                ),
                child: Icon(
                  _isListening
                      ? Icons.stop_rounded
                      : Icons.mic_rounded,
                  size: 18,
                  color: _isListening
                      ? BioVoltColors.teal
                      : BioVoltColors.textSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: _isLoading
                    ? BioVoltColors.surface
                    : BioVoltColors.teal,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isLoading
                      ? BioVoltColors.cardBorder
                      : BioVoltColors.teal,
                ),
              ),
              child: Icon(
                Icons.arrow_upward_rounded,
                size: 20,
                color: _isLoading
                    ? BioVoltColors.textSecondary
                    : BioVoltColors.background,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    _inputCtrl.clear();
    setState(() => _isLoading = true);

    // Capture vitals from current SensorsBloc state
    final sensorState = context.read<SensorsBloc>().state;
    final double? hrBpm =
        sensorState.heartRate > 0 ? sensorState.heartRate : null;
    final double? hrvMs = sensorState.hrv > 0 ? sensorState.hrv : null;
    final double? gsrUs = sensorState.gsr > 0 ? sensorState.gsr : null;
    final double? skinTempF =
        sensorState.temperature > 0 ? sensorState.temperature : null;
    final double? spo2Percent =
        sensorState.spo2 > 0 ? sensorState.spo2 : null;

    final biologicalContext = _buildBiologicalContext(
      hrBpm: hrBpm,
      hrvMs: hrvMs,
      gsrUs: gsrUs,
      skinTempF: skinTempF,
      spo2Percent: spo2Percent,
    );

    final conversationContext = _buildConversationContext();

    final result = await _aiService.sendJournalMessage(
      userMessage: text,
      conversationContext: conversationContext,
      biologicalContext: biologicalContext,
    );
    final aiResponse = result['response'] as String;
    final researchGrounded = result['researchGrounded'] as bool? ?? false;

    final combined = '$text\n$aiResponse'.toLowerCase();
    final autoTags = _tagKeywords.where(combined.contains).toList();

    final entry = HealthJournalEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      userMessage: text,
      aiResponse: aiResponse,
      bookmarked: false,
      autoTags: autoTags,
      researchGrounded: researchGrounded,
      hrBpm: hrBpm,
      hrvMs: hrvMs,
      gsrUs: gsrUs,
      skinTempF: skinTempF,
      spo2Percent: spo2Percent,
    );

    await _storage.saveJournalEntry(entry);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _entries = _storage.getAllJournalEntries();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  String _buildBiologicalContext({
    double? hrBpm,
    double? hrvMs,
    double? gsrUs,
    double? skinTempF,
    double? spo2Percent,
  }) {
    final buf = StringBuffer();

    final protocols = _storage.getAllActiveProtocols();
    if (protocols.isNotEmpty) {
      buf.writeln('Active protocols:');
      for (final p in protocols) {
        final dose = p.doseMcg > 0
            ? ' \u2014 ${p.doseMcg.toStringAsFixed(0)}mcg/day'
            : '';
        final route = p.route.isNotEmpty ? ' (${p.route})' : '';
        final notes =
            p.notes != null ? '\n    Protocol notes: ${p.notes}' : '';
        buf.writeln(
            '  ${p.name}$dose$route \u2014 day ${p.currentCycleDay}/${p.cycleLengthDays}$notes');
      }
    }

    try {
      final inferred = ContextInferrer(storage: _storage).infer();
      if (inferred.fastingHours != null && inferred.fastingHours! > 0) {
        buf.writeln(
            'Fasting: ${inferred.fastingHours!.toStringAsFixed(1)}h (${inferred.fastingSource ?? 'unknown'})');
      }
      final last = inferred.lastSession;
      if (last != null) {
        final type =
            last.context?.activities.firstOrNull?.type ?? 'session';
        buf.writeln(
            'Last session: $type at ${last.createdAt.toIso8601String()}');
      }
    } catch (_) {
      // Context inference is best-effort
    }

    final vitals = <String>[];
    if (hrBpm != null) vitals.add('HR ${hrBpm.toStringAsFixed(0)}bpm');
    if (hrvMs != null) vitals.add('HRV ${hrvMs.toStringAsFixed(0)}ms');
    if (gsrUs != null) vitals.add('GSR ${gsrUs.toStringAsFixed(1)}\u00B5S');
    if (skinTempF != null) {
      vitals.add('Temp ${skinTempF.toStringAsFixed(1)}\u00B0F');
    }
    if (spo2Percent != null) {
      vitals.add('SpO2 ${spo2Percent.toStringAsFixed(0)}%');
    }
    if (vitals.isNotEmpty) {
      buf.writeln('Current vitals: ${vitals.join(', ')}');
    }

    if (buf.isEmpty) return 'No active biological context recorded.';
    return buf.toString().trim();
  }

  String _buildConversationContext() {
    // _entries is sorted newest first — take last 3 (most recent)
    final recent = _entries.take(3).toList().reversed;
    if (recent.isEmpty) return '';
    return recent
        .map((e) => 'User: ${e.userMessage}\nAI: ${e.aiResponse}')
        .join('\n\n');
  }

  Future<void> _toggleBookmark(HealthJournalEntry entry) async {
    final updated = entry.copyWithBookmarked(!entry.bookmarked);
    await _storage.updateJournalEntry(updated);

    if (updated.bookmarked) {
      final bookmark = VitalsBookmark(
        id: 'journal_${entry.id}',
        timestamp: entry.timestamp,
        note: entry.userMessage,
        hrBpm: entry.hrBpm,
        hrvMs: entry.hrvMs,
        gsrUs: entry.gsrUs,
        skinTempF: entry.skinTempF,
        spo2Percent: entry.spo2Percent,
      );
      await _storage.saveBookmark(bookmark);
    }

    if (!mounted) return;
    _loadEntries();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _inputCtrl.text = result.recognizedWords;
            _inputCtrl.selection = TextSelection.fromPosition(
              TextPosition(offset: _inputCtrl.text.length),
            );
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

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
