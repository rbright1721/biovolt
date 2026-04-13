import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'session.dart';

/// A numeric range with a label and color for visual display.
class SignalRange {
  final String label;
  final double min;
  final double max;
  final Color color;

  const SignalRange({
    required this.label,
    required this.min,
    required this.max,
    required this.color,
  });
}

/// Per-session-type guidance for a signal.
class SessionGuidance {
  final SessionType sessionType;
  final String description;

  const SessionGuidance({
    required this.sessionType,
    required this.description,
  });
}

/// Comprehensive reference data for a single biometric signal.
class SignalInfo {
  final String id;
  final String name;
  final String unit;
  final String description;
  final String highMeans;
  final String lowMeans;
  final List<SignalRange> ranges;
  final List<SessionGuidance> sessionGuidance;

  /// Whether a higher value is better (true) or lower is better (false)
  /// or null if context-dependent.
  final bool? higherIsBetter;

  const SignalInfo({
    required this.id,
    required this.name,
    required this.unit,
    required this.description,
    required this.highMeans,
    required this.lowMeans,
    required this.ranges,
    required this.sessionGuidance,
    this.higherIsBetter,
  });

  /// The overall min across all ranges.
  double get displayMin => ranges.map((r) => r.min).reduce((a, b) => a < b ? a : b);

  /// The overall max across all ranges.
  double get displayMax => ranges.map((r) => r.max).reduce((a, b) => a > b ? a : b);

  /// Returns the range that contains [value], or null if out of all ranges.
  SignalRange? rangeFor(double value) {
    for (final r in ranges) {
      if (value >= r.min && value <= r.max) return r;
    }
    return null;
  }

  /// Returns session guidance for a specific session type, or null.
  SessionGuidance? guidanceFor(SessionType type) {
    for (final g in sessionGuidance) {
      if (g.sessionType == type) return g;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Static signal reference database
// ---------------------------------------------------------------------------

class SignalInfoRegistry {
  SignalInfoRegistry._();

  static const _teal = BioVoltColors.teal;
  static const _amber = BioVoltColors.amber;
  static const _coral = BioVoltColors.coral;

  // -- Heart Rate ----------------------------------------------------------

  static final heartRate = SignalInfo(
    id: 'heartRate',
    name: 'Heart Rate',
    unit: 'BPM',
    description:
        'Beats per minute measured via PPG or ECG. Resting heart rate is '
        'a key indicator of cardiovascular fitness and autonomic balance.',
    highMeans:
        'Stress, anxiety, stimulants, dehydration, or overtraining.',
    lowMeans:
        'Strong cardiovascular fitness and deep relaxation. If symptomatic, '
        'could indicate bradycardia.',
    higherIsBetter: false,
    ranges: const [
      SignalRange(label: 'Critical low', min: 30, max: 44, color: _coral),
      SignalRange(label: 'Athletic', min: 45, max: 54, color: _teal),
      SignalRange(label: 'Healthy', min: 55, max: 75, color: _teal),
      SignalRange(label: 'Elevated', min: 76, max: 85, color: _amber),
      SignalRange(label: 'Warning', min: 86, max: 150, color: _coral),
    ],
    sessionGuidance: const [
      SessionGuidance(
        sessionType: SessionType.breathwork,
        description:
            'Should decrease 5-15 BPM during box breathing as '
            'parasympathetic activates.',
      ),
      SessionGuidance(
        sessionType: SessionType.coldExposure,
        description:
            'Will spike initially (sympathetic shock) then gradually '
            'lower as you adapt.',
      ),
      SessionGuidance(
        sessionType: SessionType.meditation,
        description:
            'Gradual decrease over session, may drop 5-10 BPM in deep states.',
      ),
      SessionGuidance(
        sessionType: SessionType.grounding,
        description:
            'Expect a subtle 3-8 BPM decrease over 20-30 minutes.',
      ),
      SessionGuidance(
        sessionType: SessionType.fastingCheck,
        description:
            'Compare morning fasted HR to post-meal \u2014 fasted should be lower.',
      ),
    ],
  );

  // -- HRV RMSSD -----------------------------------------------------------

  static final hrv = SignalInfo(
    id: 'hrv',
    name: 'HRV RMSSD',
    unit: 'ms',
    description:
        'Root Mean Square of Successive Differences between heartbeats. '
        'The gold-standard short-term measure of parasympathetic activity '
        'and autonomic resilience.',
    highMeans:
        'Parasympathetic dominance and resilience \u2014 higher is better.',
    lowMeans:
        'Stress, fatigue, inflammation, poor sleep, or overtraining.',
    higherIsBetter: true,
    ranges: const [
      SignalRange(label: 'Low', min: 0, max: 19, color: _coral),
      SignalRange(label: 'Moderate', min: 20, max: 39, color: _amber),
      SignalRange(label: 'Good', min: 40, max: 59, color: _teal),
      SignalRange(label: 'Excellent', min: 60, max: 150, color: _teal),
    ],
    sessionGuidance: const [
      SessionGuidance(
        sessionType: SessionType.breathwork,
        description:
            'Should increase 20-50% during session as vagal tone improves.',
      ),
      SessionGuidance(
        sessionType: SessionType.coldExposure,
        description:
            'Drops sharply during cold (sympathetic), then rebounds above '
            'baseline after (parasympathetic recovery).',
      ),
      SessionGuidance(
        sessionType: SessionType.meditation,
        description:
            'Gradual increase, especially RMSSD \u2014 may take 5-10 minutes '
            'to see shift.',
      ),
      SessionGuidance(
        sessionType: SessionType.grounding,
        description:
            'Expect gradual improvement over 20+ minutes.',
      ),
      SessionGuidance(
        sessionType: SessionType.fastingCheck,
        description:
            'Morning fasted HRV is typically higher than post-meal \u2014 '
            'this is your cleanest baseline. Weekly trend: rising RMSSD '
            'correlates inversely with systemic inflammation.',
      ),
    ],
  );

  // -- GSR -----------------------------------------------------------------

  static final gsr = SignalInfo(
    id: 'gsr',
    name: 'GSR',
    unit: '\u00B5S',
    description:
        'Galvanic Skin Response measures electrodermal activity \u2014 '
        'skin conductance driven by sweat gland activity under '
        'sympathetic nervous system control.',
    highMeans:
        'Stress, anxiety, emotional arousal, or fight-or-flight activation. '
        'Sudden spikes indicate startle response or acute stress reaction.',
    lowMeans:
        'Calm, relaxed, parasympathetic-dominant state.',
    higherIsBetter: false,
    ranges: const [
      SignalRange(label: 'Calm', min: 0, max: 5, color: _teal),
      SignalRange(label: 'Alert', min: 5, max: 10, color: _amber),
      SignalRange(label: 'Stressed', min: 10, max: 20, color: _coral),
      SignalRange(label: 'High arousal', min: 20, max: 40, color: _coral),
    ],
    sessionGuidance: const [
      SessionGuidance(
        sessionType: SessionType.breathwork,
        description:
            'Should see steady decline over 5-10 minutes with occasional '
            'small spikes that get smaller.',
      ),
      SessionGuidance(
        sessionType: SessionType.coldExposure,
        description:
            'Will spike dramatically when cold hits, then should begin '
            'dropping as you regulate.',
      ),
      SessionGuidance(
        sessionType: SessionType.meditation,
        description:
            'Best signal for tracking meditation depth \u2014 steady downward '
            'slope is ideal, flat low line indicates deep state.',
      ),
      SessionGuidance(
        sessionType: SessionType.grounding,
        description:
            'Gradual decline expected, skin conductance may shift within '
            '10 minutes of earth contact.',
      ),
      SessionGuidance(
        sessionType: SessionType.fastingCheck,
        description:
            'Baseline GSR in fasted state vs fed state \u2014 fasted is '
            'typically lower (less metabolic stress).',
      ),
    ],
  );

  // -- Temperature ---------------------------------------------------------

  static final temperature = SignalInfo(
    id: 'temperature',
    name: 'Temperature',
    unit: '\u00B0F',
    description:
        'Peripheral skin temperature reflects autonomic vascular tone. '
        'Rising temperature indicates vasodilation and parasympathetic '
        'activation; dropping indicates vasoconstriction and stress.',
    highMeans:
        'Relaxation, vasodilation, parasympathetic activation, '
        'good peripheral blood flow.',
    lowMeans:
        'Stress, vasoconstriction, sympathetic activation.',
    higherIsBetter: true,
    ranges: const [
      SignalRange(label: 'Cold/stressed', min: 90, max: 95, color: _coral),
      SignalRange(label: 'Cool', min: 95, max: 96, color: _amber),
      SignalRange(label: 'Normal', min: 96, max: 98.6, color: _teal),
      SignalRange(label: 'Warm', min: 98.6, max: 100, color: _amber),
    ],
    sessionGuidance: const [
      SessionGuidance(
        sessionType: SessionType.breathwork,
        description:
            'May rise slightly (0.5-1\u00B0F) as relaxation deepens and '
            'peripheral blood flow increases.',
      ),
      SessionGuidance(
        sessionType: SessionType.coldExposure,
        description:
            'Will drop during exposure, then track recovery time \u2014 faster '
            'return to baseline indicates better cold adaptation over weeks.',
      ),
      SessionGuidance(
        sessionType: SessionType.meditation,
        description:
            'Slow rise as relaxation deepens.',
      ),
      SessionGuidance(
        sessionType: SessionType.grounding,
        description:
            'Some studies show warming of extremities during grounding.',
      ),
      SessionGuidance(
        sessionType: SessionType.fastingCheck,
        description:
            'Temperature may be slightly lower during extended fasting '
            '(metabolic downregulation).',
      ),
    ],
  );

  // -- SpO2 ----------------------------------------------------------------

  static final spo2 = SignalInfo(
    id: 'spo2',
    name: 'SpO2',
    unit: '%',
    description:
        'Peripheral oxygen saturation measured via pulse oximetry. '
        'Indicates how well oxygen is being delivered to extremities.',
    highMeans:
        'Normal oxygenation \u2014 healthy range is 95-100%.',
    lowMeans:
        'Hypoxemia. Below 90% at rest without breath holds is a medical '
        'concern, not a biofeedback target.',
    higherIsBetter: true,
    ranges: const [
      SignalRange(label: 'Serious', min: 70, max: 89, color: _coral),
      SignalRange(label: 'Mild concern', min: 90, max: 94, color: _amber),
      SignalRange(label: 'Normal', min: 95, max: 100, color: _teal),
    ],
    sessionGuidance: const [
      SessionGuidance(
        sessionType: SessionType.breathwork,
        description:
            'May fluctuate during breath holds \u2014 Wim Hof style breathing '
            'can temporarily drop SpO2 to 85-90% during retention. This is '
            'expected and temporary.',
      ),
      SessionGuidance(
        sessionType: SessionType.coldExposure,
        description:
            'Should remain stable above 95%.',
      ),
      SessionGuidance(
        sessionType: SessionType.meditation,
        description:
            'Should remain stable 96-99%.',
      ),
      SessionGuidance(
        sessionType: SessionType.grounding,
        description:
            'Should remain stable. No significant grounding-specific change expected.',
      ),
      SessionGuidance(
        sessionType: SessionType.fastingCheck,
        description:
            'Should remain in normal range. Fasting does not typically '
            'affect SpO2.',
      ),
    ],
  );

  // -- LF/HF Ratio --------------------------------------------------------

  static final lfHf = SignalInfo(
    id: 'lfHf',
    name: 'LF/HF Ratio',
    unit: 'ratio',
    description:
        'Low-Frequency to High-Frequency power ratio of heart rate '
        'variability. Reflects sympathetic-parasympathetic balance. '
        'Note: LF/HF interpretation is debated in research \u2014 LF '
        'contains both sympathetic and parasympathetic components.',
    highMeans:
        'Sympathetic dominance \u2014 stress, fight-or-flight activation.',
    lowMeans:
        'Parasympathetic dominance \u2014 deep relaxation, recovery state.',
    higherIsBetter: false,
    ranges: const [
      SignalRange(label: 'Parasympathetic', min: 0, max: 0.99, color: _teal),
      SignalRange(label: 'Balanced', min: 1.0, max: 2.0, color: _teal),
      SignalRange(label: 'Sympathetic', min: 2.01, max: 3.0, color: _amber),
      SignalRange(label: 'High stress', min: 3.01, max: 6.0, color: _coral),
    ],
    sessionGuidance: const [
      SessionGuidance(
        sessionType: SessionType.breathwork,
        description:
            'Should shift toward <1.0 during slow breathing (6 breaths/minute '
            'especially drives parasympathetic).',
      ),
      SessionGuidance(
        sessionType: SessionType.coldExposure,
        description:
            'Will spike >3.0 during cold, then recovery shows how quickly '
            'it drops back.',
      ),
      SessionGuidance(
        sessionType: SessionType.meditation,
        description:
            'Gradual shift toward parasympathetic (<1.5).',
      ),
      SessionGuidance(
        sessionType: SessionType.grounding,
        description:
            'May gradually shift toward balanced or parasympathetic over the session.',
      ),
      SessionGuidance(
        sessionType: SessionType.fastingCheck,
        description:
            'Compare fasted vs fed ratio \u2014 fasted state often shows '
            'better autonomic balance.',
      ),
    ],
  );

  // -- Coherence -----------------------------------------------------------

  static final coherence = SignalInfo(
    id: 'coherence',
    name: 'Coherence',
    unit: 'score',
    description:
        'A derived metric (0-100) combining HRV pattern regularity with '
        'breathing synchronization. High coherence means heart rhythm, '
        'breathing, and autonomic activity are synchronized \u2014 this is '
        'the target state for biofeedback training.',
    highMeans:
        'Heart rhythm, breathing, and autonomic activity are synchronized. '
        'This is the target state.',
    lowMeans:
        'Dysregulated, stressed, or unsynchronized autonomic activity.',
    higherIsBetter: true,
    ranges: const [
      SignalRange(label: 'Low', min: 0, max: 39, color: _coral),
      SignalRange(label: 'Moderate', min: 40, max: 69, color: _amber),
      SignalRange(label: 'High', min: 70, max: 100, color: _teal),
    ],
    sessionGuidance: const [
      SessionGuidance(
        sessionType: SessionType.breathwork,
        description:
            'Coherence is highest during rhythmic breathing at ~6 '
            'breaths/minute (resonance frequency). This is your primary '
            'target signal during breathwork.',
      ),
      SessionGuidance(
        sessionType: SessionType.coldExposure,
        description:
            'Will drop during initial cold shock. Focus on maintaining '
            'controlled breathing to recover coherence.',
      ),
      SessionGuidance(
        sessionType: SessionType.meditation,
        description:
            'Builds slowly, may take 10+ minutes to reach high coherence.',
      ),
      SessionGuidance(
        sessionType: SessionType.grounding,
        description:
            'May gradually improve as autonomic balance shifts.',
      ),
      SessionGuidance(
        sessionType: SessionType.fastingCheck,
        description:
            'Fasted-state coherence provides a clean autonomic baseline.',
      ),
    ],
  );

  // -- ECG -----------------------------------------------------------------

  static final ecg = SignalInfo(
    id: 'ecg',
    name: 'ECG',
    unit: 'mV',
    description:
        'Single-lead electrocardiogram from the AD8232 clinical-grade '
        'analog front-end. Displays the electrical activity of the heart '
        'as a continuous PQRST waveform.\n\n'
        'The PQRST complex represents one complete heartbeat cycle:\n'
        '\u2022 P wave \u2014 atrial depolarization (atria contracting)\n'
        '\u2022 QRS complex \u2014 ventricular depolarization (ventricles '
        'contracting, the tall spike)\n'
        '\u2022 T wave \u2014 ventricular repolarization (ventricles recovering)\n\n'
        'A normal rhythm shows regular spacing between R peaks (the tallest '
        'points), consistent P wave morphology, and a narrow QRS complex. '
        'Irregular R-R spacing indicates arrhythmia or high heart rate '
        'variability.\n\n'
        'This is a single-lead (Lead I) recording \u2014 it provides gold-standard '
        'R-R interval timing for HRV calculation but is not a diagnostic '
        '12-lead ECG. The AD8232 includes onboard 0.5-40 Hz bandpass '
        'filtering and right-leg drive for noise rejection.',
    highMeans:
        'High amplitude QRS indicates strong ventricular depolarization. '
        'Baseline wander or noise may indicate poor electrode contact.',
    lowMeans:
        'Low amplitude may indicate poor electrode placement, dry electrodes, '
        'or high skin impedance. Ensure good contact with conductive gel.',
    higherIsBetter: null,
    ranges: const [
      SignalRange(label: 'Noise floor', min: -0.4, max: -0.1, color: _coral),
      SignalRange(label: 'Baseline', min: -0.1, max: 0.2, color: _teal),
      SignalRange(label: 'P/T waves', min: 0.2, max: 0.5, color: _teal),
      SignalRange(label: 'QRS complex', min: 0.5, max: 1.2, color: _teal),
    ],
    sessionGuidance: const [
      SessionGuidance(
        sessionType: SessionType.breathwork,
        description:
            'Watch R-R interval spacing change with your breath \u2014 intervals '
            'lengthen on exhale (parasympathetic) and shorten on inhale '
            '(sympathetic). This respiratory sinus arrhythmia is the mechanism '
            'behind HRV improvement during breathwork. ECG provides gold-standard '
            'R-R timing for real-time HRV calculation.',
      ),
      SessionGuidance(
        sessionType: SessionType.coldExposure,
        description:
            'Expect heart rate acceleration (shorter R-R intervals) during '
            'initial cold shock. As you adapt, rhythm should stabilize. '
            'ECG detects arrhythmias that cold stress can provoke \u2014 if you '
            'see irregular R-R patterns, exit cold exposure.',
      ),
      SessionGuidance(
        sessionType: SessionType.meditation,
        description:
            'In deep meditation, R-R intervals become longer and more regular. '
            'ECG-derived HRV is the most accurate measure of the parasympathetic '
            'shift that meditation produces.',
      ),
      SessionGuidance(
        sessionType: SessionType.grounding,
        description:
            'ECG may show subtle rhythm changes during grounding. Less relevant '
            'than GSR and temperature for this session type.',
      ),
      SessionGuidance(
        sessionType: SessionType.fastingCheck,
        description:
            'ECG provides the cleanest R-R interval data for fasting-state '
            'HRV baseline comparison.',
      ),
    ],
  );

  // -- Lookup helpers ------------------------------------------------------

  static final List<SignalInfo> all = [
    heartRate,
    hrv,
    gsr,
    temperature,
    spo2,
    lfHf,
    coherence,
    ecg,
  ];

  static SignalInfo? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }
}
