// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'oura_daily.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OuraDailyRecordAdapter extends TypeAdapter<OuraDailyRecord> {
  @override
  final int typeId = 15;

  @override
  OuraDailyRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OuraDailyRecord(
      date: fields[0] as DateTime,
      syncedAt: fields[1] as DateTime,
      readinessScore: fields[2] as int?,
      readinessContributors: fields[3] as ReadinessContributors?,
      sleepScore: fields[4] as int?,
      sleepContributors: fields[5] as SleepContributors?,
      temperatureDeviationC: fields[6] as double?,
      temperatureTrendDeviationC: fields[7] as double?,
      overnightHrvSamples: (fields[8] as List?)?.cast<double>(),
      overnightHrvAverageMs: fields[9] as double?,
      overnightHrSamplesBpm: (fields[10] as List?)?.cast<double>(),
      spo2AveragePercent: fields[11] as double?,
      breathingDisturbanceIndex: fields[12] as double?,
      highStressSeconds: fields[13] as int?,
      highRecoverySeconds: fields[14] as int?,
      stressDaySummary: fields[15] as String?,
      resilienceLevel: fields[16] as String?,
      vo2Max: fields[17] as double?,
      cardiovascularAge: fields[18] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, OuraDailyRecord obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.syncedAt)
      ..writeByte(2)
      ..write(obj.readinessScore)
      ..writeByte(3)
      ..write(obj.readinessContributors)
      ..writeByte(4)
      ..write(obj.sleepScore)
      ..writeByte(5)
      ..write(obj.sleepContributors)
      ..writeByte(6)
      ..write(obj.temperatureDeviationC)
      ..writeByte(7)
      ..write(obj.temperatureTrendDeviationC)
      ..writeByte(8)
      ..write(obj.overnightHrvSamples)
      ..writeByte(9)
      ..write(obj.overnightHrvAverageMs)
      ..writeByte(10)
      ..write(obj.overnightHrSamplesBpm)
      ..writeByte(11)
      ..write(obj.spo2AveragePercent)
      ..writeByte(12)
      ..write(obj.breathingDisturbanceIndex)
      ..writeByte(13)
      ..write(obj.highStressSeconds)
      ..writeByte(14)
      ..write(obj.highRecoverySeconds)
      ..writeByte(15)
      ..write(obj.stressDaySummary)
      ..writeByte(16)
      ..write(obj.resilienceLevel)
      ..writeByte(17)
      ..write(obj.vo2Max)
      ..writeByte(18)
      ..write(obj.cardiovascularAge);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OuraDailyRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
