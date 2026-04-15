// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'normalized_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DataSourceAdapter extends TypeAdapter<DataSource> {
  @override
  final int typeId = 1;

  @override
  DataSource read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DataSource.ecg130hz;
      case 1:
        return DataSource.ppg50hz;
      case 2:
        return DataSource.overnightRing;
      case 3:
        return DataSource.manual;
      default:
        return DataSource.ecg130hz;
    }
  }

  @override
  void write(BinaryWriter writer, DataSource obj) {
    switch (obj) {
      case DataSource.ecg130hz:
        writer.writeByte(0);
        break;
      case DataSource.ppg50hz:
        writer.writeByte(1);
        break;
      case DataSource.overnightRing:
        writer.writeByte(2);
        break;
      case DataSource.manual:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataSourceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DataQualityAdapter extends TypeAdapter<DataQuality> {
  @override
  final int typeId = 2;

  @override
  DataQuality read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DataQuality.clinical;
      case 1:
        return DataQuality.research;
      case 2:
        return DataQuality.consumer;
      case 3:
        return DataQuality.manual;
      default:
        return DataQuality.clinical;
    }
  }

  @override
  void write(BinaryWriter writer, DataQuality obj) {
    switch (obj) {
      case DataQuality.clinical:
        writer.writeByte(0);
        break;
      case DataQuality.research:
        writer.writeByte(1);
        break;
      case DataQuality.consumer:
        writer.writeByte(2);
        break;
      case DataQuality.manual:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataQualityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ConnectorTypeAdapter extends TypeAdapter<ConnectorType> {
  @override
  final int typeId = 3;

  @override
  ConnectorType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ConnectorType.ble;
      case 1:
        return ConnectorType.restApi;
      case 2:
        return ConnectorType.fileImport;
      case 3:
        return ConnectorType.manual;
      default:
        return ConnectorType.ble;
    }
  }

  @override
  void write(BinaryWriter writer, ConnectorType obj) {
    switch (obj) {
      case ConnectorType.ble:
        writer.writeByte(0);
        break;
      case ConnectorType.restApi:
        writer.writeByte(1);
        break;
      case ConnectorType.fileImport:
        writer.writeByte(2);
        break;
      case ConnectorType.manual:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectorTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ConnectorStatusAdapter extends TypeAdapter<ConnectorStatus> {
  @override
  final int typeId = 4;

  @override
  ConnectorStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ConnectorStatus.connected;
      case 1:
        return ConnectorStatus.disconnected;
      case 2:
        return ConnectorStatus.syncing;
      case 3:
        return ConnectorStatus.error;
      case 4:
        return ConnectorStatus.unauthorized;
      default:
        return ConnectorStatus.connected;
    }
  }

  @override
  void write(BinaryWriter writer, ConnectorStatus obj) {
    switch (obj) {
      case ConnectorStatus.connected:
        writer.writeByte(0);
        break;
      case ConnectorStatus.disconnected:
        writer.writeByte(1);
        break;
      case ConnectorStatus.syncing:
        writer.writeByte(2);
        break;
      case ConnectorStatus.error:
        writer.writeByte(3);
        break;
      case ConnectorStatus.unauthorized:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectorStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
