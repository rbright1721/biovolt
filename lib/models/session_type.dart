// =============================================================================
// Hive TypeAdapter IDs used in this file:
//  33  — SessionType
// =============================================================================

import 'package:hive/hive.dart';

part 'session_type.g.dart';

@HiveType(typeId: 33)
enum SessionType {
  @HiveField(0)
  breathwork,
  @HiveField(1)
  coldExposure,
  @HiveField(2)
  meditation,
  @HiveField(3)
  fastingCheck,
  @HiveField(4)
  grounding,
}

extension SessionTypeInfo on SessionType {
  String get displayName => switch (this) {
        SessionType.breathwork => 'Breathwork',
        SessionType.coldExposure => 'Cold Exposure',
        SessionType.meditation => 'Meditation',
        SessionType.fastingCheck => 'Fasting Check',
        SessionType.grounding => 'Grounding',
      };

  String get description => switch (this) {
        SessionType.breathwork => 'Box breathing with HRV & GSR tracking',
        SessionType.coldExposure => 'Temperature & HRV during cold exposure',
        SessionType.meditation => 'GSR & coherence for calm monitoring',
        SessionType.fastingCheck => 'Full biometric snapshot vs baseline',
        SessionType.grounding => 'GSR & temperature before/after grounding',
      };

  String get focusSignals => switch (this) {
        SessionType.breathwork => 'HRV + GSR + ECG',
        SessionType.coldExposure => 'Temp + HRV + ECG',
        SessionType.meditation => 'GSR + Coherence + ECG',
        SessionType.fastingCheck => 'All Signals',
        SessionType.grounding => 'GSR + Temp',
      };

  String get estimatedDuration => switch (this) {
        SessionType.breathwork => '5-20 min',
        SessionType.coldExposure => '2-10 min',
        SessionType.meditation => '10-30 min',
        SessionType.fastingCheck => '1 min',
        SessionType.grounding => '10-20 min',
      };

  String get iconChar => switch (this) {
        SessionType.breathwork => '\u{1F32C}',
        SessionType.coldExposure => '\u{2744}',
        SessionType.meditation => '\u{1F9D8}',
        SessionType.fastingCheck => '\u{1F50D}',
        SessionType.grounding => '\u{1F333}',
      };
}
