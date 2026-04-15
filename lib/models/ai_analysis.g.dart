// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_analysis.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AiAnalysisAdapter extends TypeAdapter<AiAnalysis> {
  @override
  final int typeId = 25;

  @override
  AiAnalysis read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AiAnalysis(
      sessionId: fields[0] as String,
      generatedAt: fields[1] as DateTime,
      provider: fields[2] as String,
      model: fields[3] as String,
      promptVersion: fields[4] as String,
      insights: (fields[5] as List).cast<String>(),
      anomalies: (fields[6] as List).cast<String>(),
      correlationsDetected: (fields[7] as List).cast<String>(),
      protocolRecommendations: (fields[8] as List).cast<String>(),
      flags: (fields[9] as List).cast<String>(),
      trendSummary: fields[10] as String?,
      confidence: fields[11] as double,
      ouraContextUsed: fields[12] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, AiAnalysis obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.sessionId)
      ..writeByte(1)
      ..write(obj.generatedAt)
      ..writeByte(2)
      ..write(obj.provider)
      ..writeByte(3)
      ..write(obj.model)
      ..writeByte(4)
      ..write(obj.promptVersion)
      ..writeByte(5)
      ..write(obj.insights)
      ..writeByte(6)
      ..write(obj.anomalies)
      ..writeByte(7)
      ..write(obj.correlationsDetected)
      ..writeByte(8)
      ..write(obj.protocolRecommendations)
      ..writeByte(9)
      ..write(obj.flags)
      ..writeByte(10)
      ..write(obj.trendSummary)
      ..writeByte(11)
      ..write(obj.confidence)
      ..writeByte(12)
      ..write(obj.ouraContextUsed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiAnalysisAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
