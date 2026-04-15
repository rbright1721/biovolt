// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_type.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SessionTypeAdapter extends TypeAdapter<SessionType> {
  @override
  final int typeId = 33;

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
