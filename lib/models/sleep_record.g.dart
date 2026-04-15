// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sleep_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SleepContributorsAdapter extends TypeAdapter<SleepContributors> {
  @override
  final int typeId = 13;

  @override
  SleepContributors read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SleepContributors(
      deepSleep: fields[0] as int?,
      efficiency: fields[1] as int?,
      latency: fields[2] as int?,
      remSleep: fields[3] as int?,
      restfulness: fields[4] as int?,
      timing: fields[5] as int?,
      totalSleep: fields[6] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, SleepContributors obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.deepSleep)
      ..writeByte(1)
      ..write(obj.efficiency)
      ..writeByte(2)
      ..write(obj.latency)
      ..writeByte(3)
      ..write(obj.remSleep)
      ..writeByte(4)
      ..write(obj.restfulness)
      ..writeByte(5)
      ..write(obj.timing)
      ..writeByte(6)
      ..write(obj.totalSleep);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SleepContributorsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReadinessContributorsAdapter extends TypeAdapter<ReadinessContributors> {
  @override
  final int typeId = 14;

  @override
  ReadinessContributors read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReadinessContributors(
      activityBalance: fields[0] as int?,
      bodyTemperature: fields[1] as int?,
      hrvBalance: fields[2] as int?,
      previousDayActivity: fields[3] as int?,
      previousNight: fields[4] as int?,
      recoveryIndex: fields[5] as int?,
      restingHeartRate: fields[6] as int?,
      sleepBalance: fields[7] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, ReadinessContributors obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.activityBalance)
      ..writeByte(1)
      ..write(obj.bodyTemperature)
      ..writeByte(2)
      ..write(obj.hrvBalance)
      ..writeByte(3)
      ..write(obj.previousDayActivity)
      ..writeByte(4)
      ..write(obj.previousNight)
      ..writeByte(5)
      ..write(obj.recoveryIndex)
      ..writeByte(6)
      ..write(obj.restingHeartRate)
      ..writeByte(7)
      ..write(obj.sleepBalance);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadinessContributorsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SleepRecordAdapter extends TypeAdapter<SleepRecord> {
  @override
  final int typeId = 12;

  @override
  SleepRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SleepRecord(
      bedtimeStart: fields[0] as DateTime,
      bedtimeEnd: fields[1] as DateTime,
      totalSleepSeconds: fields[2] as int,
      deepSleepSeconds: fields[3] as int,
      remSleepSeconds: fields[4] as int,
      lightSleepSeconds: fields[5] as int,
      timeInBedSeconds: fields[6] as int,
      latencySeconds: fields[7] as int?,
      efficiency: fields[8] as double?,
      lowestHrBpm: fields[9] as int?,
      restlessPeriods: fields[10] as int?,
      overnightHrvRmssdMs: fields[11] as double?,
      skinTempDeviationC: fields[12] as double?,
      readinessScore: fields[13] as int?,
      sleepScore: fields[14] as int?,
      sleepPhaseSequence: fields[15] as String?,
      sleepContributors: fields[16] as SleepContributors?,
      readinessContributors: fields[17] as ReadinessContributors?,
      connectorId: fields[18] as String,
      timestamp: fields[19] as DateTime,
      quality: fields[20] as DataQuality,
    );
  }

  @override
  void write(BinaryWriter writer, SleepRecord obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.bedtimeStart)
      ..writeByte(1)
      ..write(obj.bedtimeEnd)
      ..writeByte(2)
      ..write(obj.totalSleepSeconds)
      ..writeByte(3)
      ..write(obj.deepSleepSeconds)
      ..writeByte(4)
      ..write(obj.remSleepSeconds)
      ..writeByte(5)
      ..write(obj.lightSleepSeconds)
      ..writeByte(6)
      ..write(obj.timeInBedSeconds)
      ..writeByte(7)
      ..write(obj.latencySeconds)
      ..writeByte(8)
      ..write(obj.efficiency)
      ..writeByte(9)
      ..write(obj.lowestHrBpm)
      ..writeByte(10)
      ..write(obj.restlessPeriods)
      ..writeByte(11)
      ..write(obj.overnightHrvRmssdMs)
      ..writeByte(12)
      ..write(obj.skinTempDeviationC)
      ..writeByte(13)
      ..write(obj.readinessScore)
      ..writeByte(14)
      ..write(obj.sleepScore)
      ..writeByte(15)
      ..write(obj.sleepPhaseSequence)
      ..writeByte(16)
      ..write(obj.sleepContributors)
      ..writeByte(17)
      ..write(obj.readinessContributors)
      ..writeByte(18)
      ..write(obj.connectorId)
      ..writeByte(19)
      ..write(obj.timestamp)
      ..writeByte(20)
      ..write(obj.quality);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SleepRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
