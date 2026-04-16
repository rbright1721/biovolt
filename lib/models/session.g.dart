// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SubjectiveScoresAdapter extends TypeAdapter<SubjectiveScores> {
  @override
  final int typeId = 24;

  @override
  SubjectiveScores read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SubjectiveScores(
      energy: fields[0] as int?,
      mood: fields[1] as int?,
      focus: fields[2] as int?,
      anxiety: fields[3] as int?,
      physicalSoreness: fields[4] as int?,
      motivation: fields[5] as int?,
      calm: fields[6] as int?,
      physicalFeeling: fields[7] as int?,
      sessionQuality: fields[8] as int?,
      notableEffects: fields[9] as String?,
      sideEffects: fields[10] as String?,
      notes: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SubjectiveScores obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.energy)
      ..writeByte(1)
      ..write(obj.mood)
      ..writeByte(2)
      ..write(obj.focus)
      ..writeByte(3)
      ..write(obj.anxiety)
      ..writeByte(4)
      ..write(obj.physicalSoreness)
      ..writeByte(5)
      ..write(obj.motivation)
      ..writeByte(6)
      ..write(obj.calm)
      ..writeByte(7)
      ..write(obj.physicalFeeling)
      ..writeByte(8)
      ..write(obj.sessionQuality)
      ..writeByte(9)
      ..write(obj.notableEffects)
      ..writeByte(10)
      ..write(obj.sideEffects)
      ..writeByte(11)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubjectiveScoresAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SessionSubjectiveAdapter extends TypeAdapter<SessionSubjective> {
  @override
  final int typeId = 23;

  @override
  SessionSubjective read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SessionSubjective(
      preSession: fields[0] as SubjectiveScores?,
      postSession: fields[1] as SubjectiveScores?,
    );
  }

  @override
  void write(BinaryWriter writer, SessionSubjective obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.preSession)
      ..writeByte(1)
      ..write(obj.postSession);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionSubjectiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class Esp32MetricsAdapter extends TypeAdapter<Esp32Metrics> {
  @override
  final int typeId = 20;

  @override
  Esp32Metrics read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Esp32Metrics(
      heartRateBpm: fields[0] as double?,
      hrvRmssdMs: fields[1] as double?,
      spo2Percent: fields[2] as double?,
      gsrMeanUs: fields[3] as double?,
      gsrBaselineShiftUs: fields[4] as double?,
      skinTempC: fields[5] as double?,
      ppgRedWaveformPath: fields[6] as String?,
      ppgIrWaveformPath: fields[7] as String?,
      ecgWaveformPath: fields[8] as String?,
      gsrTracePath: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Esp32Metrics obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.heartRateBpm)
      ..writeByte(1)
      ..write(obj.hrvRmssdMs)
      ..writeByte(2)
      ..write(obj.spo2Percent)
      ..writeByte(3)
      ..write(obj.gsrMeanUs)
      ..writeByte(4)
      ..write(obj.gsrBaselineShiftUs)
      ..writeByte(5)
      ..write(obj.skinTempC)
      ..writeByte(6)
      ..write(obj.ppgRedWaveformPath)
      ..writeByte(7)
      ..write(obj.ppgIrWaveformPath)
      ..writeByte(8)
      ..write(obj.ecgWaveformPath)
      ..writeByte(9)
      ..write(obj.gsrTracePath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Esp32MetricsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PolarMetricsAdapter extends TypeAdapter<PolarMetrics> {
  @override
  final int typeId = 21;

  @override
  PolarMetrics read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PolarMetrics(
      heartRateBpm: fields[0] as double?,
      hrvRmssdMs: fields[1] as double?,
      hrvSdnnMs: fields[2] as double?,
      hrvPnn50Percent: fields[3] as double?,
      rrIntervalsMs: (fields[4] as List?)?.cast<int>(),
      ecgQualityScore: fields[5] as double?,
      ecgWaveformPath: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PolarMetrics obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.heartRateBpm)
      ..writeByte(1)
      ..write(obj.hrvRmssdMs)
      ..writeByte(2)
      ..write(obj.hrvSdnnMs)
      ..writeByte(3)
      ..write(obj.hrvPnn50Percent)
      ..writeByte(4)
      ..write(obj.rrIntervalsMs)
      ..writeByte(5)
      ..write(obj.ecgQualityScore)
      ..writeByte(6)
      ..write(obj.ecgWaveformPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PolarMetricsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ComputedMetricsAdapter extends TypeAdapter<ComputedMetrics> {
  @override
  final int typeId = 22;

  @override
  ComputedMetrics read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ComputedMetrics(
      hrSource: fields[0] as String?,
      hrvSource: fields[1] as String?,
      heartRateMeanBpm: fields[2] as double?,
      heartRateMinBpm: fields[3] as double?,
      heartRateMaxBpm: fields[4] as double?,
      hrvRmssdMs: fields[5] as double?,
      coherenceScore: fields[6] as double?,
      lfHfProxy: fields[7] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, ComputedMetrics obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.hrSource)
      ..writeByte(1)
      ..write(obj.hrvSource)
      ..writeByte(2)
      ..write(obj.heartRateMeanBpm)
      ..writeByte(3)
      ..write(obj.heartRateMinBpm)
      ..writeByte(4)
      ..write(obj.heartRateMaxBpm)
      ..writeByte(5)
      ..write(obj.hrvRmssdMs)
      ..writeByte(6)
      ..write(obj.coherenceScore)
      ..writeByte(7)
      ..write(obj.lfHfProxy);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComputedMetricsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SessionBiometricsAdapter extends TypeAdapter<SessionBiometrics> {
  @override
  final int typeId = 19;

  @override
  SessionBiometrics read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SessionBiometrics(
      esp32: fields[0] as Esp32Metrics?,
      polarH10: fields[1] as PolarMetrics?,
      computed: fields[2] as ComputedMetrics?,
    );
  }

  @override
  void write(BinaryWriter writer, SessionBiometrics obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.esp32)
      ..writeByte(1)
      ..write(obj.polarH10)
      ..writeByte(2)
      ..write(obj.computed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionBiometricsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SessionActivityAdapter extends TypeAdapter<SessionActivity> {
  @override
  final int typeId = 18;

  @override
  SessionActivity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SessionActivity(
      type: fields[0] as String,
      subtype: fields[1] as String?,
      startOffsetSeconds: fields[2] as int,
      durationSeconds: fields[3] as int?,
      parameters: (fields[4] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, SessionActivity obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.subtype)
      ..writeByte(2)
      ..write(obj.startOffsetSeconds)
      ..writeByte(3)
      ..write(obj.durationSeconds)
      ..writeByte(4)
      ..write(obj.parameters);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionActivityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SessionContextAdapter extends TypeAdapter<SessionContext> {
  @override
  final int typeId = 17;

  @override
  SessionContext read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SessionContext(
      activities: (fields[0] as List).cast<SessionActivity>(),
      fastingHours: fields[1] as double?,
      timeSinceWakeHours: fields[2] as double?,
      sleepLastNightHours: fields[3] as double?,
      stressContext: fields[4] as String?,
      notes: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SessionContext obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.activities)
      ..writeByte(1)
      ..write(obj.fastingHours)
      ..writeByte(2)
      ..write(obj.timeSinceWakeHours)
      ..writeByte(3)
      ..write(obj.sleepLastNightHours)
      ..writeByte(4)
      ..write(obj.stressContext)
      ..writeByte(5)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionContextAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SessionAdapter extends TypeAdapter<Session> {
  @override
  final int typeId = 16;

  @override
  Session read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Session(
      sessionId: fields[0] as String,
      userId: fields[1] as String,
      createdAt: fields[2] as DateTime,
      timezone: fields[3] as String,
      durationSeconds: fields[4] as int?,
      dataSources: (fields[5] as List).cast<String>(),
      context: fields[6] as SessionContext?,
      biometrics: fields[7] as SessionBiometrics?,
      subjective: fields[8] as SessionSubjective?,
      interventions: fields[9] as Interventions?,
    );
  }

  @override
  void write(BinaryWriter writer, Session obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.sessionId)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.timezone)
      ..writeByte(4)
      ..write(obj.durationSeconds)
      ..writeByte(5)
      ..write(obj.dataSources)
      ..writeByte(6)
      ..write(obj.context)
      ..writeByte(7)
      ..write(obj.biometrics)
      ..writeByte(8)
      ..write(obj.subjective)
      ..writeByte(9)
      ..write(obj.interventions);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
