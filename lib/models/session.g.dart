// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SensorSnapshotAdapter extends TypeAdapter<SensorSnapshot> {
  @override
  final int typeId = 1;

  @override
  SensorSnapshot read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SensorSnapshot(
      timestampMs: fields[0] as int,
      heartRate: fields[1] as double,
      hrv: fields[2] as double,
      gsr: fields[3] as double,
      temperature: fields[4] as double,
      spo2: fields[5] as double,
      lfHfRatio: fields[6] as double,
      coherence: fields[7] as double,
    );
  }

  @override
  void write(BinaryWriter writer, SensorSnapshot obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.timestampMs)
      ..writeByte(1)
      ..write(obj.heartRate)
      ..writeByte(2)
      ..write(obj.hrv)
      ..writeByte(3)
      ..write(obj.gsr)
      ..writeByte(4)
      ..write(obj.temperature)
      ..writeByte(5)
      ..write(obj.spo2)
      ..writeByte(6)
      ..write(obj.lfHfRatio)
      ..writeByte(7)
      ..write(obj.coherence);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SensorSnapshotAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SessionAdapter extends TypeAdapter<Session> {
  @override
  final int typeId = 2;

  @override
  Session read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Session(
      id: fields[0] as String,
      type: fields[1] as SessionType,
      startTimeMs: fields[2] as int,
      endTimeMs: fields[3] as int?,
      snapshots: (fields[4] as List?)?.cast<SensorSnapshot>(),
    );
  }

  @override
  void write(BinaryWriter writer, Session obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.startTimeMs)
      ..writeByte(3)
      ..write(obj.endTimeMs)
      ..writeByte(4)
      ..write(obj.snapshots);
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

class SessionTypeAdapter extends TypeAdapter<SessionType> {
  @override
  final int typeId = 0;

  @override
  SessionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SessionType.breathwork;
      case 1:
        return SessionType.coldExposure;
      case 2:
        return SessionType.meditation;
      case 3:
        return SessionType.fastingCheck;
      case 4:
        return SessionType.grounding;
      default:
        return SessionType.breathwork;
    }
  }

  @override
  void write(BinaryWriter writer, SessionType obj) {
    switch (obj) {
      case SessionType.breathwork:
        writer.writeByte(0);
        break;
      case SessionType.coldExposure:
        writer.writeByte(1);
        break;
      case SessionType.meditation:
        writer.writeByte(2);
        break;
      case SessionType.fastingCheck:
        writer.writeByte(3);
        break;
      case SessionType.grounding:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
