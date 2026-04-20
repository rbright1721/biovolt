import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../models/biovolt_event.dart';
import '../../services/event_log.dart';
import '../../services/storage_service.dart';
import 'collapse_runs.dart';
import 'timeline_event_renderer.dart';

/// Read-only timeline of every event in the [EventLog].
///
/// Hosted inside [TrendsScreen] via a segmented control — not a full
/// `Scaffold`. The parent provides the background and header.
class ProtocolTimelineView extends StatefulWidget {
  const ProtocolTimelineView({
    super.key,
    this.storageService,
    this.eventLogOverride,
    this.registry,
  });

  /// Defaults to [StorageService] singleton. Widget tests can pass their
  /// own instance backed by a temp Hive directory.
  final StorageService? storageService;

  /// Tests can pass an [EventLog] directly, bypassing [StorageService].
  /// When set, [storageService] is ignored.
  final EventLog? eventLogOverride;

  /// Defaults to [TimelineRendererRegistry.defaultRegistry]. Tests can
  /// pass a smaller registry for isolation.
  final TimelineRendererRegistry? registry;

  @override
  State<ProtocolTimelineView> createState() => _ProtocolTimelineViewState();
}

enum _RangePreset { h24, d7, d30, d90, custom }

class _ProtocolTimelineViewState extends State<ProtocolTimelineView> {
  static const int _queryLimit = 1000;

  _RangePreset _preset = _RangePreset.d7;
  late DateTimeRange _range;
  Set<String> _typeFilter = {};
  Set<String> _sourceFilter = {};
  final Set<String> _expanded = <String>{};
  List<BiovoltEvent> _events = const [];
  bool _loading = true;
  bool _truncated = false;
  int _unfilteredCount = 0;

  TimelineRendererRegistry get _registry =>
      widget.registry ?? TimelineRendererRegistry.defaultRegistry;

  EventLog get _eventLog =>
      widget.eventLogOverride ??
      (widget.storageService ?? StorageService()).eventLog;

  @override
  void initState() {
    super.initState();
    _range = _rangeFromPreset(_RangePreset.d7);
    _load();
  }

  DateTimeRange _rangeFromPreset(_RangePreset preset) {
    final now = DateTime.now();
    switch (preset) {
      case _RangePreset.h24:
        return DateTimeRange(start: now.subtract(const Duration(hours: 24)), end: now);
      case _RangePreset.d7:
        return DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
      case _RangePreset.d30:
        return DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);
      case _RangePreset.d90:
        return DateTimeRange(start: now.subtract(const Duration(days: 90)), end: now);
      case _RangePreset.custom:
        return _range;
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await _eventLog.query(
      from: _range.start,
      to: _range.end,
    );
    final filtered = await _eventLog.query(
      types: _typeFilter.isEmpty ? null : _typeFilter,
      sources: _sourceFilter.isEmpty ? null : _sourceFilter,
      from: _range.start,
      to: _range.end,
      limit: _queryLimit,
    );
    if (!mounted) return;
    setState(() {
      _events = filtered;
      _unfilteredCount = all.length;
      _truncated = filtered.length >= _queryLimit && all.length > _queryLimit;
      _loading = false;
    });
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _range,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: BioVoltColors.teal,
            surface: BioVoltColors.surface,
            onSurface: BioVoltColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _preset = _RangePreset.custom;
        _range = picked;
      });
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPresetRow(),
        _buildRangeDisplay(),
        _buildFilterChips(),
        if (_truncated) _buildTruncationNotice(),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: BioVoltColors.teal,
                    strokeWidth: 2,
                  ),
                )
              : _events.isEmpty
                  ? _buildEmptyState()
                  : _buildTimelineList(),
        ),
      ],
    );
  }

  Widget _buildPresetRow() {
    const presets = <(_RangePreset, String)>[
      (_RangePreset.h24, '24h'),
      (_RangePreset.d7, '7d'),
      (_RangePreset.d30, '30d'),
      (_RangePreset.d90, '90d'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          for (final (preset, label) in presets) ...[
            _PresetChip(
              label: label,
              selected: _preset == preset,
              onTap: () {
                setState(() {
                  _preset = preset;
                  _range = _rangeFromPreset(preset);
                });
                _load();
              },
            ),
            const SizedBox(width: 8),
          ],
          _PresetChip(
            label: 'Custom…',
            selected: _preset == _RangePreset.custom,
            onTap: _pickCustomRange,
          ),
        ],
      ),
    );
  }

  Widget _buildRangeDisplay() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        '${_formatDate(_range.start)} – ${_formatDate(_range.end)}',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          color: BioVoltColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final typeCounts = <String, int>{};
    final sourceCounts = <String, int>{};
    for (final e in _events) {
      typeCounts[e.type] = (typeCounts[e.type] ?? 0) + 1;
      final src = e.deviceId.isEmpty ? 'unknown' : e.deviceId;
      sourceCounts[src] = (sourceCounts[src] ?? 0) + 1;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _FilterButton(
            label: _typeFilter.isEmpty
                ? 'All types'
                : '${_typeFilter.length} type${_typeFilter.length == 1 ? "" : "s"}',
            active: _typeFilter.isNotEmpty,
            onTap: () => _openFilterSheet(
              title: 'Filter by type',
              counts: typeCounts,
              current: _typeFilter,
              onApply: (next) {
                setState(() => _typeFilter = next);
                _load();
              },
              labelFor: humanizeEventType,
            ),
          ),
          _FilterButton(
            label: _sourceFilter.isEmpty
                ? 'All sources'
                : '${_sourceFilter.length} source${_sourceFilter.length == 1 ? "" : "s"}',
            active: _sourceFilter.isNotEmpty,
            onTap: () => _openFilterSheet(
              title: 'Filter by source',
              counts: sourceCounts,
              current: _sourceFilter,
              onApply: (next) {
                setState(() => _sourceFilter = next);
                _load();
              },
              labelFor: (s) => s,
            ),
          ),
          if (_typeFilter.isNotEmpty || _sourceFilter.isNotEmpty)
            _FilterButton(
              label: 'Clear filters',
              active: false,
              destructive: true,
              onTap: () {
                setState(() {
                  _typeFilter = {};
                  _sourceFilter = {};
                });
                _load();
              },
            ),
        ],
      ),
    );
  }

  Future<void> _openFilterSheet({
    required String title,
    required Map<String, int> counts,
    required Set<String> current,
    required ValueChanged<Set<String>> onApply,
    required String Function(String) labelFor,
  }) async {
    final keys = counts.keys.toList()..sort();
    final selected = current.toSet();
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: BioVoltColors.surface,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(
                    title,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: BioVoltColors.teal,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: keys.length,
                    itemBuilder: (_, i) {
                      final k = keys[i];
                      final isSelected = selected.contains(k);
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (v) {
                          setSheetState(() {
                            if (v == true) {
                              selected.add(k);
                            } else {
                              selected.remove(k);
                            }
                          });
                        },
                        activeColor: BioVoltColors.teal,
                        title: Text(
                          labelFor(k),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: BioVoltColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${counts[k]}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            color: BioVoltColors.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(<String>{}),
                        child: Text(
                          'Clear',
                          style: GoogleFonts.jetBrainsMono(
                            color: BioVoltColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(selected),
                        child: Text(
                          'Apply',
                          style: GoogleFonts.jetBrainsMono(
                            color: BioVoltColors.teal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null) onApply(result);
  }

  Widget _buildTruncationNotice() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        'showing most recent $_queryLimit of $_unfilteredCount',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          color: BioVoltColors.amber,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final filterActive =
        _typeFilter.isNotEmpty || _sourceFilter.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timeline_rounded,
              size: 48,
              color: BioVoltColors.textSecondary.withAlpha(80),
            ),
            const SizedBox(height: 20),
            Text(
              'No events in this range',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: BioVoltColors.textPrimary,
              ),
            ),
            if (filterActive) ...[
              const SizedBox(height: 8),
              Text(
                'Try widening the time range\nor clearing filters',
                textAlign: TextAlign.center,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: BioVoltColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineList() {
    // Events come back oldest-first from EventLog.query. Reverse for
    // newest-first display, then group by calendar day (local time).
    final newestFirst = _events.reversed.toList();
    final byDay = <DateTime, List<BiovoltEvent>>{};
    for (final e in newestFirst) {
      final d = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
      byDay.putIfAbsent(d, () => []).add(e);
    }
    final dayKeys = byDay.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      itemCount: dayKeys.length,
      itemBuilder: (_, idx) {
        final day = dayKeys[idx];
        final eventsForDay = byDay[day]!;
        final items = collapseRuns(eventsForDay);
        return Column(
          key: ValueKey('day-${day.toIso8601String()}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
              child: Text(
                _formatDayHeader(day),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: BioVoltColors.teal,
                  letterSpacing: 2,
                ),
              ),
            ),
            for (final item in items) _buildItem(item),
          ],
        );
      },
    );
  }

  Widget _buildItem(TimelineItem item) {
    switch (item) {
      case SingleEventItem(:final event):
        return _EventRow(
          event: event,
          registry: _registry,
          expanded: _expanded.contains(event.id),
          onTap: () {
            setState(() {
              if (!_expanded.add(event.id)) _expanded.remove(event.id);
            });
          },
        );
      case CollapsedRunItem():
        final runId = 'run-${item.first.id}-${item.last.id}';
        return _CollapsedRunRow(
          run: item,
          registry: _registry,
          expanded: _expanded.contains(runId),
          expandedIds: _expanded,
          onToggle: () {
            setState(() {
              if (!_expanded.add(runId)) _expanded.remove(runId);
            });
          },
          onChildToggle: (eventId) {
            setState(() {
              if (!_expanded.add(eventId)) _expanded.remove(eventId);
            });
          },
        );
    }
  }

  String _formatDayHeader(DateTime day) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final delta = todayDate.difference(day).inDays;
    if (delta == 0) return 'TODAY';
    if (delta == 1) return 'YESTERDAY';
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    return '${weekdays[day.weekday - 1]} ${months[day.month - 1]} ${day.day}';
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}

// -------------------------------------------------------------------------
// Private widgets
// -------------------------------------------------------------------------

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? BioVoltColors.teal.withAlpha(30)
              : BioVoltColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? BioVoltColors.teal.withAlpha(120)
                : BioVoltColors.cardBorder,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? BioVoltColors.teal
                : BioVoltColors.textSecondary,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.active,
    this.destructive = false,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool destructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? BioVoltColors.coral
        : active
            ? BioVoltColors.teal
            : BioVoltColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? BioVoltColors.teal.withAlpha(20) : BioVoltColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(80), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              destructive ? Icons.close : Icons.filter_list_rounded,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.registry,
    required this.expanded,
    required this.onTap,
  });

  final BiovoltEvent event;
  final TimelineRendererRegistry registry;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final renderer = registry.forEvent(event);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: expanded
              ? BioVoltColors.surface.withAlpha(160)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: expanded
                ? BioVoltColors.cardBorder
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            renderer.buildRow(context, event),
            if (expanded) renderer.buildExpanded(context, event),
          ],
        ),
      ),
    );
  }
}

class _CollapsedRunRow extends StatelessWidget {
  const _CollapsedRunRow({
    required this.run,
    required this.registry,
    required this.expanded,
    required this.expandedIds,
    required this.onToggle,
    required this.onChildToggle,
  });

  final CollapsedRunItem run;
  final TimelineRendererRegistry registry;
  final bool expanded;
  final Set<String> expandedIds;
  final VoidCallback onToggle;
  final ValueChanged<String> onChildToggle;

  @override
  Widget build(BuildContext context) {
    final renderer = registry.forType(run.type);
    final summary = renderer is GenericTimelineRenderer
        ? humanizeEventType(run.type)
        : renderer.buildSummary(run.first).split(' — ').first;
    final source = run.deviceId.isEmpty ? 'unknown' : run.deviceId;
    final timeRange =
        '${formatRelativeTime(run.last.timestamp)} – ${formatRelativeTime(run.first.timestamp)}';
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: BioVoltColors.surface.withAlpha(120),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BioVoltColors.cardBorder, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_right_rounded,
                    size: 16,
                    color: BioVoltColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${run.count} $summary events',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: BioVoltColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'from $source · $timeRange',
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
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in run.events)
                      _EventRow(
                        event: e,
                        registry: registry,
                        expanded: expandedIds.contains(e.id),
                        onTap: () => onChildToggle(e.id),
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
