import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Tier classification for breathwork patterns.
enum BreathworkTier {
  foundation,
  alteredState,
}

/// Difficulty level for display.
enum BreathworkDifficulty {
  beginner, // 1 dot
  intermediate, // 2 dots
  advanced, // 3 dots
}

/// Describes a breathwork pattern for the selector UI and session tracking.
///
/// Foundation patterns use the standard [BreathingPacer] widget.
/// Altered state patterns may use specialized widgets (e.g., [WimHofPacer]).
class BreathworkPatternInfo {
  final String id;
  final String name;
  final String label;
  final String description;
  final BreathworkTier tier;
  final BreathworkDifficulty difficulty;
  final String estimatedDuration;
  final Color accentColor;

  const BreathworkPatternInfo({
    required this.id,
    required this.name,
    required this.label,
    required this.description,
    required this.tier,
    required this.difficulty,
    required this.estimatedDuration,
    required this.accentColor,
  });

  bool get isAlteredState => tier == BreathworkTier.alteredState;
}

/// Registry of all breathwork patterns.
class BreathworkPatterns {
  BreathworkPatterns._();

  static const box4 = BreathworkPatternInfo(
    id: 'box4',
    name: 'Box Breathing',
    label: 'Calm',
    description: 'Equal 4-second inhale, hold, exhale, hold. '
        'Activates parasympathetic nervous system.',
    tier: BreathworkTier.foundation,
    difficulty: BreathworkDifficulty.beginner,
    estimatedDuration: '5-20 min',
    accentColor: BioVoltColors.teal,
  );

  static const relaxing478 = BreathworkPatternInfo(
    id: 'relaxing478',
    name: 'Relaxing 4-7-8',
    label: 'Relaxing',
    description: 'Extended exhale pattern. Inhale 4s, hold 7s, exhale 8s. '
        'Deep relaxation and sleep preparation.',
    tier: BreathworkTier.foundation,
    difficulty: BreathworkDifficulty.beginner,
    estimatedDuration: '5-15 min',
    accentColor: BioVoltColors.teal,
  );

  static const coherence = BreathworkPatternInfo(
    id: 'coherence',
    name: 'Coherence 5-5',
    label: 'Coherence',
    description: 'Equal 5-second inhale and exhale at 6 breaths/minute. '
        'Maximizes heart-breath synchronization.',
    tier: BreathworkTier.foundation,
    difficulty: BreathworkDifficulty.beginner,
    estimatedDuration: '5-20 min',
    accentColor: BioVoltColors.teal,
  );

  static const wimHof = BreathworkPatternInfo(
    id: 'wimHof',
    name: 'Wim Hof Method',
    label: 'Altered State',
    description: '30 rapid breaths, exhale hold until you must breathe, '
        '15s recovery. 3 rounds. Expect tingling and SpO2 drops.',
    tier: BreathworkTier.alteredState,
    difficulty: BreathworkDifficulty.advanced,
    estimatedDuration: '15-25 min',
    accentColor: BioVoltColors.amber,
  );

  static const holotropic = BreathworkPatternInfo(
    id: 'holotropic',
    name: 'Holotropic Breathwork',
    label: 'Altered State',
    description: 'Continuous deep circular breathing with no pauses. '
        'Gradual slowdown in final 5 minutes.',
    tier: BreathworkTier.alteredState,
    difficulty: BreathworkDifficulty.advanced,
    estimatedDuration: '20-30 min',
    accentColor: BioVoltColors.amber,
  );

  static const tummo = BreathworkPatternInfo(
    id: 'tummo',
    name: 'Tummo Breathing',
    label: 'Altered State',
    description: 'Energizing breath with core engagement. '
        'Nose inhale, mouth exhale, 10-20 cycles then hold with bandha.',
    tier: BreathworkTier.alteredState,
    difficulty: BreathworkDifficulty.advanced,
    estimatedDuration: '10-20 min',
    accentColor: BioVoltColors.amber,
  );

  static const List<BreathworkPatternInfo> foundation = [
    box4,
    relaxing478,
    coherence,
  ];

  static const List<BreathworkPatternInfo> alteredState = [
    wimHof,
    holotropic,
    tummo,
  ];

  static const List<BreathworkPatternInfo> all = [
    box4,
    relaxing478,
    coherence,
    wimHof,
    holotropic,
    tummo,
  ];

  static BreathworkPatternInfo? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}
