// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ConnectorStateAdapter extends TypeAdapter<ConnectorState> {
  @override
  final int typeId = 32;

  @override
  ConnectorState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ConnectorState(
      connectorId: fields[0] as String,
      status: fields[1] as ConnectorStatus,
      lastSync: fields[2] as DateTime?,
      isAuthenticated: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ConnectorState obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.connectorId)
      ..writeByte(1)
      ..write(obj.status)
      ..writeByte(2)
      ..write(obj.lastSync)
      ..writeByte(3)
      ..write(obj.isAuthenticated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectorStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final int typeId = 31;

  @override
  UserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfile(
      userId: fields[0] as String,
      createdAt: fields[1] as DateTime,
      biologicalSex: fields[2] as String?,
      dateOfBirth: fields[3] as DateTime?,
      heightCm: fields[4] as double?,
      weightKg: fields[5] as double?,
      healthGoals: (fields[6] as List).cast<String>(),
      knownConditions: (fields[7] as List).cast<String>(),
      baselineEstablished: fields[8] as bool,
      aiProvider: fields[9] as String?,
      aiModel: fields[10] as String?,
      preferredUnits: fields[11] as String,
      aiCoachingStyle: fields[12] as String?,
      mthfr: fields[13] as String?,
      apoe: fields[14] as String?,
      comt: fields[15] as String?,
      fastingType: fields[16] as String?,
      eatWindowStartHour: fields[17] as int?,
      eatWindowEndHour: fields[18] as int?,
      lastMealTime: fields[19] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.createdAt)
      ..writeByte(2)
      ..write(obj.biologicalSex)
      ..writeByte(3)
      ..write(obj.dateOfBirth)
      ..writeByte(4)
      ..write(obj.heightCm)
      ..writeByte(5)
      ..write(obj.weightKg)
      ..writeByte(6)
      ..write(obj.healthGoals)
      ..writeByte(7)
      ..write(obj.knownConditions)
      ..writeByte(8)
      ..write(obj.baselineEstablished)
      ..writeByte(9)
      ..write(obj.aiProvider)
      ..writeByte(10)
      ..write(obj.aiModel)
      ..writeByte(11)
      ..write(obj.preferredUnits)
      ..writeByte(12)
      ..write(obj.aiCoachingStyle)
      ..writeByte(13)
      ..write(obj.mthfr)
      ..writeByte(14)
      ..write(obj.apoe)
      ..writeByte(15)
      ..write(obj.comt)
      ..writeByte(16)
      ..write(obj.fastingType)
      ..writeByte(17)
      ..write(obj.eatWindowStartHour)
      ..writeByte(18)
      ..write(obj.eatWindowEndHour)
      ..writeByte(19)
      ..write(obj.lastMealTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
