import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/log_entry.dart';
import '../timeline_item.dart';
import 'timeline_row.dart';

class TimelineLogEntryTile extends StatelessWidget {
  final TimelineLogEntry item;
  const TimelineLogEntryTile({required this.item, super.key});

  @override
  Widget build(BuildContext context) {
    final e = item.entry;
    final iconData = _iconForType(e.type);
    final accentColor = _accentForType(e.type);
    return TimelineRow(
      time: e.occurredAt,
      iconWidget: TimelineLeadingIcon(icon: iconData, color: accentColor),
      primary: _primaryText(e),
      secondary: _secondaryText(e),
      trailing: _typeChip(e.type, e.classificationStatus),
    );
  }

  /// Per-type icon. Picked to read at a glance without color
  /// dependence — shape carries the meaning.
  IconData _iconForType(String type) {
    switch (type) {
      case 'dose':
        return Icons.medical_services_rounded;
      case 'meal':
        return Icons.restaurant_rounded;
      case 'symptom':
        return Icons.warning_amber_rounded;
      case 'mood':
        return Icons.psychology_rounded;
      case 'bowel_movement':
        return Icons.eco_rounded;
      case 'training':
        return Icons.fitness_center_rounded;
      case 'sleep_subjective':
        return Icons.bedtime_rounded;
      case 'note':
        return Icons.note_rounded;
      case 'bookmark':
        return Icons.bookmark_rounded;
      default:
        return Icons.edit_note_rounded;
    }
  }

  Color _accentForType(String type) {
    switch (type) {
      case 'dose':
      case 'training':
        return BioVoltColors.teal;
      case 'symptom':
      case 'mood':
        return BioVoltColors.coral;
      case 'meal':
      case 'bowel_movement':
      case 'sleep_subjective':
        return BioVoltColors.amber;
      default:
        return BioVoltColors.amber;
    }
  }

  String _primaryText(LogEntry e) {
    final raw = e.rawText.trim();
    if (raw.isEmpty) return '(vitals snapshot)';
    if (raw.length <= 60) return raw;
    return '${raw.substring(0, 60)}…';
  }

  /// Compact one-line summary derived from `structured` for classified
  /// entries with useful extracted fields. Returns null when no useful
  /// summary can be built (the row degrades gracefully).
  String? _secondaryText(LogEntry e) {
    if (e.classificationStatus != 'classified') return null;
    final s = e.structured;
    if (s == null || s.isEmpty) return null;
    switch (e.type) {
      case 'dose':
        final parts = <String>[
          if (s['compound'] is String) s['compound'] as String,
          if (s['dose'] is String) s['dose'] as String,
          if (s['route'] is String) s['route'] as String,
        ];
        return parts.isEmpty ? null : parts.join(' · ');
      case 'meal':
        if (s['description'] is String) return s['description'] as String;
        if (s['items'] is List) {
          return (s['items'] as List).join(', ');
        }
        return null;
      case 'symptom':
        if (s['description'] is String) return s['description'] as String;
        return null;
      case 'mood':
        if (s['label'] is String) return s['label'] as String;
        return null;
      default:
        return null;
    }
  }

  Widget _typeChip(String type, String status) {
    final isOther = type == 'other';
    final isUnclassified = status == 'pending' ||
        status == 'failed' ||
        status == 'skipped' ||
        isOther;
    if (isUnclassified) {
      return const TimelineTypeChip(
        label: 'LOG',
        color: BioVoltColors.textSecondary,
      );
    }
    return TimelineTypeChip(
      label: type,
      color: BioVoltColors.teal,
    );
  }
}
