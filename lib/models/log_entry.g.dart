// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'log_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LogEntryAdapter extends TypeAdapter<LogEntry> {
  @override
  final int typeId = 43;

  @override
  LogEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LogEntry(
      id: fields[0] as String,
      rawText: fields[3] as String,
      occurredAt: fields[1] as DateTime?,
      loggedAt: fields[2] as DateTime?,
      rawAudioPath: fields[4] as String?,
      type: fields[5] as String,
      structured: (fields[6] as Map?)?.cast<String, dynamic>(),
      classificationConfidence: fields[7] as double?,
      classificationStatus: fields[8] as String,
      classificationError: fields[9] as String?,
      classificationAttempts: fields[10] as int,
      hrBpm: fields[11] as double?,
      hrvMs: fields[12] as double?,
      gsrUs: fields[13] as double?,
      skinTempF: fields[14] as double?,
      spo2Percent: fields[15] as double?,
      ecgHrBpm: fields[16] as double?,
      protocolIdAtTime: fields[17] as String?,
      tags: (fields[18] as List?)?.cast<String>(),
      userNotes: fields[19] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LogEntry obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.occurredAt)
      ..writeByte(2)
      ..write(obj.loggedAt)
      ..writeByte(3)
      ..write(obj.rawText)
      ..writeByte(4)
      ..write(obj.rawAudioPath)
      ..writeByte(5)
      ..write(obj.type)
      ..writeByte(6)
      ..write(obj.structured)
      ..writeByte(7)
      ..write(obj.classificationConfidence)
      ..writeByte(8)
      ..write(obj.classificationStatus)
      ..writeByte(9)
      ..write(obj.classificationError)
      ..writeByte(10)
      ..write(obj.classificationAttempts)
      ..writeByte(11)
      ..write(obj.hrBpm)
      ..writeByte(12)
      ..write(obj.hrvMs)
      ..writeByte(13)
      ..write(obj.gsrUs)
      ..writeByte(14)
      ..write(obj.skinTempF)
      ..writeByte(15)
      ..write(obj.spo2Percent)
      ..writeByte(16)
      ..write(obj.ecgHrBpm)
      ..writeByte(17)
      ..write(obj.protocolIdAtTime)
      ..writeByte(18)
      ..write(obj.tags)
      ..writeByte(19)
      ..write(obj.userNotes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
