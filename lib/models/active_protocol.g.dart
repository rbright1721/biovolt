// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_protocol.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ActiveProtocolAdapter extends TypeAdapter<ActiveProtocol> {
  @override
  final int typeId = 41;

  @override
  ActiveProtocol read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ActiveProtocol(
      id: fields[0] as String,
      name: fields[1] as String,
      type: fields[2] as String,
      startDate: fields[3] as DateTime,
      endDate: fields[4] as DateTime?,
      cycleLengthDays: fields[5] as int,
      doseMcg: fields[6] as double,
      route: fields[7] as String,
      notes: fields[8] as String?,
      isActive: fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ActiveProtocol obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.startDate)
      ..writeByte(4)
      ..write(obj.endDate)
      ..writeByte(5)
      ..write(obj.cycleLengthDays)
      ..writeByte(6)
      ..write(obj.doseMcg)
      ..writeByte(7)
      ..write(obj.route)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveProtocolAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
