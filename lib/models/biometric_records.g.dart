// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'biometric_records.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HeartRateReadingAdapter extends TypeAdapter<HeartRateReading> {
  @override
  final int typeId = 5;

  @override
  HeartRateReading read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HeartRateReading(
      bpm: fields[0] as double,
      source: fields[1] as DataSource,
      quality: fields[2] as DataQuality,
      connectorId: fields[3] as String,
      timestamp: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, HeartRateReading obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.bpm)
      ..writeByte(1)
      ..write(obj.source)
      ..writeByte(2)
      ..write(obj.quality)
      ..writeByte(3)
      ..write(obj.connectorId)
      ..writeByte(4)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeartRateReadingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HRVReadingAdapter extends TypeAdapter<HRVReading> {
  @override
  final int typeId = 6;

  @override
  HRVReading read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HRVReading(
      rmssdMs: fields[0] as double,
      sdnnMs: fields[1] as double?,
      pnn50Percent: fields[2] as double?,
      source: fields[3] as DataSource,
      quality: fields[4] as DataQuality,
      connectorId: fields[5] as String,
      timestamp: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, HRVReading obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.rmssdMs)
      ..writeByte(1)
      ..write(obj.sdnnMs)
      ..writeByte(2)
      ..write(obj.pnn50Percent)
      ..writeByte(3)
      ..write(obj.source)
      ..writeByte(4)
      ..write(obj.quality)
      ..writeByte(5)
      ..write(obj.connectorId)
      ..writeByte(6)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HRVReadingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EDAReadingAdapter extends TypeAdapter<EDAReading> {
  @override
  final int typeId = 7;

  @override
  EDAReading read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EDAReading(
      microSiemens: fields[0] as double,
      baselineShiftUs: fields[1] as double?,
      connectorId: fields[2] as String,
      timestamp: fields[3] as DateTime,
      quality: fields[4] as DataQuality,
    );
  }

  @override
  void write(BinaryWriter writer, EDAReading obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.microSiemens)
      ..writeByte(1)
      ..write(obj.baselineShiftUs)
      ..writeByte(2)
      ..write(obj.connectorId)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.quality);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EDAReadingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SpO2ReadingAdapter extends TypeAdapter<SpO2Reading> {
  @override
  final int typeId = 8;

  @override
  SpO2Reading read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SpO2Reading(
      percent: fields[0] as double,
      perfusionIndex: fields[1] as double?,
      connectorId: fields[2] as String,
      timestamp: fields[3] as DateTime,
      quality: fields[4] as DataQuality,
    );
  }

  @override
  void write(BinaryWriter writer, SpO2Reading obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.percent)
      ..writeByte(1)
      ..write(obj.perfusionIndex)
      ..writeByte(2)
      ..write(obj.connectorId)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.quality);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpO2ReadingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TemperatureReadingAdapter extends TypeAdapter<TemperatureReading> {
  @override
  final int typeId = 9;

  @override
  TemperatureReading read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TemperatureReading(
      celsius: fields[0] as double,
      placement: fields[1] as TemperaturePlacement,
      connectorId: fields[2] as String,
      timestamp: fields[3] as DateTime,
      quality: fields[4] as DataQuality,
    );
  }

  @override
  void write(BinaryWriter writer, TemperatureReading obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.celsius)
      ..writeByte(1)
      ..write(obj.placement)
      ..writeByte(2)
      ..write(obj.connectorId)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.quality);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemperatureReadingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ECGRecordAdapter extends TypeAdapter<ECGRecord> {
  @override
  final int typeId = 10;

  @override
  ECGRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ECGRecord(
      qualityScore: fields[0] as double,
      waveformPath: fields[1] as String?,
      rrIntervalsMs: (fields[2] as List).cast<int>(),
      connectorId: fields[3] as String,
      timestamp: fields[4] as DateTime,
      quality: fields[5] as DataQuality,
    );
  }

  @override
  void write(BinaryWriter writer, ECGRecord obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.qualityScore)
      ..writeByte(1)
      ..write(obj.waveformPath)
      ..writeByte(2)
      ..write(obj.rrIntervalsMs)
      ..writeByte(3)
      ..write(obj.connectorId)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.quality);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ECGRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TemperaturePlacementAdapter extends TypeAdapter<TemperaturePlacement> {
  @override
  final int typeId = 11;

  @override
  TemperaturePlacement read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TemperaturePlacement.skin;
      case 1:
        return TemperaturePlacement.ambient;
      case 2:
        return TemperaturePlacement.core;
      default:
        return TemperaturePlacement.skin;
    }
  }

  @override
  void write(BinaryWriter writer, TemperaturePlacement obj) {
    switch (obj) {
      case TemperaturePlacement.skin:
        writer.writeByte(0);
        break;
      case TemperaturePlacement.ambient:
        writer.writeByte(1);
        break;
      case TemperaturePlacement.core:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemperaturePlacementAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
