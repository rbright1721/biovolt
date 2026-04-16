// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SessionTemplateAdapter extends TypeAdapter<SessionTemplate> {
  @override
  final int typeId = 40;

  @override
  SessionTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SessionTemplate(
      id: fields[0] as String,
      name: fields[1] as String,
      sessionType: fields[2] as String,
      breathworkPattern: fields[3] as String?,
      breathworkRounds: fields[4] as int?,
      breathHoldTargetSec: fields[5] as int?,
      coldTempF: fields[6] as double?,
      coldDurationMin: fields[7] as int?,
      notes: fields[8] as String?,
      lastUsedAt: fields[9] as DateTime,
      useCount: fields[10] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SessionTemplate obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.sessionType)
      ..writeByte(3)
      ..write(obj.breathworkPattern)
      ..writeByte(4)
      ..write(obj.breathworkRounds)
      ..writeByte(5)
      ..write(obj.breathHoldTargetSec)
      ..writeByte(6)
      ..write(obj.coldTempF)
      ..writeByte(7)
      ..write(obj.coldDurationMin)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.lastUsedAt)
      ..writeByte(10)
      ..write(obj.useCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
