// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sensor_snapshot.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SensorSnapshotAdapter extends TypeAdapter<SensorSnapshot> {
  @override
  final int typeId = 34;

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
