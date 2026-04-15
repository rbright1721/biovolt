// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bloodwork.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BloodworkAdapter extends TypeAdapter<Bloodwork> {
  @override
  final int typeId = 35;

  @override
  Bloodwork read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Bloodwork(
      id: fields[0] as String,
      labDate: fields[1] as DateTime,
      fastingHours: fields[2] as double?,
      protocolContext: fields[3] as String?,
      notes: fields[4] as String?,
      crp: fields[5] as double?,
      il6: fields[6] as double?,
      homocysteine: fields[7] as double?,
      glucoseFasting: fields[8] as double?,
      hba1c: fields[9] as double?,
      insulinFasting: fields[10] as double?,
      homaIr: fields[11] as double?,
      testosteroneTotal: fields[12] as double?,
      testosteroneFree: fields[13] as double?,
      dheaS: fields[14] as double?,
      cortisolAm: fields[15] as double?,
      igf1: fields[16] as double?,
      estradiol: fields[17] as double?,
      shbg: fields[18] as double?,
      tsh: fields[19] as double?,
      freeT3: fields[20] as double?,
      freeT4: fields[21] as double?,
      totalCholesterol: fields[22] as double?,
      ldl: fields[23] as double?,
      hdl: fields[24] as double?,
      triglycerides: fields[25] as double?,
      apoB: fields[26] as double?,
      vitaminD: fields[27] as double?,
      magnesiumRbc: fields[28] as double?,
      omega3Index: fields[29] as double?,
      ferritin: fields[30] as double?,
      b12: fields[31] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, Bloodwork obj) {
    writer
      ..writeByte(32)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.labDate)
      ..writeByte(2)
      ..write(obj.fastingHours)
      ..writeByte(3)
      ..write(obj.protocolContext)
      ..writeByte(4)
      ..write(obj.notes)
      ..writeByte(5)
      ..write(obj.crp)
      ..writeByte(6)
      ..write(obj.il6)
      ..writeByte(7)
      ..write(obj.homocysteine)
      ..writeByte(8)
      ..write(obj.glucoseFasting)
      ..writeByte(9)
      ..write(obj.hba1c)
      ..writeByte(10)
      ..write(obj.insulinFasting)
      ..writeByte(11)
      ..write(obj.homaIr)
      ..writeByte(12)
      ..write(obj.testosteroneTotal)
      ..writeByte(13)
      ..write(obj.testosteroneFree)
      ..writeByte(14)
      ..write(obj.dheaS)
      ..writeByte(15)
      ..write(obj.cortisolAm)
      ..writeByte(16)
      ..write(obj.igf1)
      ..writeByte(17)
      ..write(obj.estradiol)
      ..writeByte(18)
      ..write(obj.shbg)
      ..writeByte(19)
      ..write(obj.tsh)
      ..writeByte(20)
      ..write(obj.freeT3)
      ..writeByte(21)
      ..write(obj.freeT4)
      ..writeByte(22)
      ..write(obj.totalCholesterol)
      ..writeByte(23)
      ..write(obj.ldl)
      ..writeByte(24)
      ..write(obj.hdl)
      ..writeByte(25)
      ..write(obj.triglycerides)
      ..writeByte(26)
      ..write(obj.apoB)
      ..writeByte(27)
      ..write(obj.vitaminD)
      ..writeByte(28)
      ..write(obj.magnesiumRbc)
      ..writeByte(29)
      ..write(obj.omega3Index)
      ..writeByte(30)
      ..write(obj.ferritin)
      ..writeByte(31)
      ..write(obj.b12);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BloodworkAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
