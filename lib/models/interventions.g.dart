// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'interventions.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PeptideLogAdapter extends TypeAdapter<PeptideLog> {
  @override
  final int typeId = 27;

  @override
  PeptideLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PeptideLog(
      name: fields[0] as String,
      doseMcg: fields[1] as double,
      route: fields[2] as String,
      cycleDay: fields[3] as int?,
      cycleTotalDays: fields[4] as int?,
      stackId: fields[5] as String?,
      loggedAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, PeptideLog obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.doseMcg)
      ..writeByte(2)
      ..write(obj.route)
      ..writeByte(3)
      ..write(obj.cycleDay)
      ..writeByte(4)
      ..write(obj.cycleTotalDays)
      ..writeByte(5)
      ..write(obj.stackId)
      ..writeByte(6)
      ..write(obj.loggedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeptideLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SupplementLogAdapter extends TypeAdapter<SupplementLog> {
  @override
  final int typeId = 28;

  @override
  SupplementLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SupplementLog(
      name: fields[0] as String,
      doseMg: fields[1] as double,
      form: fields[2] as String?,
      timing: fields[3] as String?,
      loggedAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, SupplementLog obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.doseMg)
      ..writeByte(2)
      ..write(obj.form)
      ..writeByte(3)
      ..write(obj.timing)
      ..writeByte(4)
      ..write(obj.loggedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupplementLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NutritionLogAdapter extends TypeAdapter<NutritionLog> {
  @override
  final int typeId = 29;

  @override
  NutritionLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NutritionLog(
      mealTimingHoursBefore: fields[0] as double?,
      fasted: fields[1] as bool,
      quality: fields[2] as String?,
      notes: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, NutritionLog obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.mealTimingHoursBefore)
      ..writeByte(1)
      ..write(obj.fasted)
      ..writeByte(2)
      ..write(obj.quality)
      ..writeByte(3)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NutritionLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HydrationLogAdapter extends TypeAdapter<HydrationLog> {
  @override
  final int typeId = 30;

  @override
  HydrationLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HydrationLog(
      waterMlToday: fields[0] as double?,
      electrolytes: fields[1] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, HydrationLog obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.waterMlToday)
      ..writeByte(1)
      ..write(obj.electrolytes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HydrationLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class InterventionsAdapter extends TypeAdapter<Interventions> {
  @override
  final int typeId = 26;

  @override
  Interventions read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Interventions(
      peptides: (fields[0] as List).cast<PeptideLog>(),
      supplements: (fields[1] as List).cast<SupplementLog>(),
      nutrition: fields[2] as NutritionLog?,
      hydration: fields[3] as HydrationLog?,
    );
  }

  @override
  void write(BinaryWriter writer, Interventions obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.peptides)
      ..writeByte(1)
      ..write(obj.supplements)
      ..writeByte(2)
      ..write(obj.nutrition)
      ..writeByte(3)
      ..write(obj.hydration);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InterventionsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
