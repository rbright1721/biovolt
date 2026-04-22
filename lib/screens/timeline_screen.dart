import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/theme.dart';
import '../services/ble_service.dart';
import '../services/storage_service.dart';
import '../widgets/log_entry_sheet.dart';
import 'template_launcher_screen.dart';
import 'timeline/items/timeline_bookmark_tile.dart';
import 'timeline/items/timeline_cycle_day_marker_tile.dart';
import 'timeline/items/timeline_day_header.dart';
import 'timeline/items/timeline_expected_dose_tile.dart';
import 'timeline/items/timeline_fasting_window_tile.dart';
import 'timeline/items/timeline_log_entry_tile.dart';
import 'timeline/items/timeline_now_marker_card.dart';
import 'timeline/items/timeline_session_tile.dart';
import 'timeline/timeline_builder.dart';
import 'timeline/timeline_item.dart';

/// NOW-anchored timeline. Session 2 is static-only — the screen reads
/// once on initState() and does NOT subscribe to storage events. The
/// reactivity wiring lands in Session 3.
class TimelineScreen extends StatefulWidget {
  final BleService bleService;

  /// Optional injection for tests. Production passes null and the
  /// screen builds its own [TimelineBuilder] over [StorageService].
  final List<TimelineItem>? initialItems;

  const TimelineScreen({
    required this.bleService,
    this.initialItems,
    super.key,
  });

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _nowMarkerKey = GlobalKey();

  late List<TimelineItem> _items;
  late List<_GroupedEntry> _grouped;

  @override
  void initState() {
    super.initState();
    _rebuild();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToNow();
    });
  }

  void _rebuild() {
    if (widget.initialItems != null) {
      _items = widget.initialItems!;
    } else {
      final builder = TimelineBuilder(StorageService());
      final now = DateTime.now();
      _items = builder.build(
        rangeStart: now.subtract(const Duration(days: 14)),
        rangeEnd: now.add(const Duration(days: 2)),
      );
    }
    _grouped = _groupByDay(_items);
  }

  void _scrollToNow() {
    final ctx = _nowMarkerKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BioVoltColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildQuickLogPill(context),
            Expanded(
              child: _grouped.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: _grouped.length,
                      itemBuilder: (ctx, i) => _buildEntry(_grouped[i]),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openSessionLauncher(context),
        child: const Icon(Icons.play_arrow_rounded, size: 32),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Subviews
  // ---------------------------------------------------------------------------

  Widget _buildTopBar() {
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Text(
            'TIMELINE',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: BioVoltColors.teal,
              letterSpacing: 3,
            ),
          ),
          const Spacer(),
          Text(
            'Today · ${_month(now.month)} ${now.day}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: BioVoltColors.textSecondary,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  /// Mirrors the dashboard's quick-log pill (`_buildBookmarkButton`).
  /// Tap opens the same [LogEntrySheet]. Note: any newly logged entry
  /// will not appear in this screen's list until the user navigates
  /// away and back — Session 2 has no reactivity by design.
  Widget _buildQuickLogPill(BuildContext context) {
    return GestureDetector(
      key: const Key('timeline-quick-log-pill'),
      onTap: () => LogEntrySheet.show(context),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: BioVoltColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: BioVoltColors.cardBorder),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.edit_note_rounded,
              size: 16,
              color: BioVoltColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              'Quick log',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: BioVoltColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              'TAP →',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: BioVoltColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSessionLauncher(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TemplateLauncherScreen(bleService: widget.bleService),
      ),
    );
  }

  Widget _buildEntry(_GroupedEntry entry) {
    if (entry.isHeader) {
      return TimelineDayHeader(date: entry.date!);
    }
    return _buildItemWidget(entry.item!);
  }

  Widget _buildItemWidget(TimelineItem item) {
    return switch (item) {
      TimelineNowMarker() =>
        TimelineNowMarkerCard(key: _nowMarkerKey, item: item),
      TimelineLogEntry() => TimelineLogEntryTile(item: item),
      TimelineSession() => TimelineSessionTile(item: item),
      TimelineBookmark() => TimelineBookmarkTile(item: item),
      TimelineExpectedDose() => TimelineExpectedDoseTile(item: item),
      TimelineFastingWindow() => TimelineFastingWindowTile(item: item),
      TimelineCycleDayMarker() => TimelineCycleDayMarkerTile(item: item),
    };
  }
}

// =============================================================================
// Day grouping
// =============================================================================

class _GroupedEntry {
  final bool isHeader;
  final DateTime? date;
  final TimelineItem? item;

  const _GroupedEntry.header(DateTime this.date)
      : isHeader = true,
        item = null;

  const _GroupedEntry.item(TimelineItem this.item)
      : isHeader = false,
        date = null;
}

List<_GroupedEntry> _groupByDay(List<TimelineItem> items) {
  final result = <_GroupedEntry>[];
  DateTime? currentDay;
  for (final item in items) {
    final itemDay = DateTime(
      item.time.year,
      item.time.month,
      item.time.day,
    );
    if (currentDay == null || itemDay != currentDay) {
      result.add(_GroupedEntry.header(itemDay));
      currentDay = itemDay;
    }
    result.add(_GroupedEntry.item(item));
  }
  return result;
}

String _month(int m) {
  const names = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return names[(m - 1).clamp(0, 11)];
}
