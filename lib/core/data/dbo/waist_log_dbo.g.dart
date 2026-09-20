// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'waist_log_dbo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WaistLogDBOAdapter extends TypeAdapter<WaistLogDBO> {
  @override
  final typeId = 30;

  @override
  WaistLogDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WaistLogDBO(
      date: fields[0] as DateTime,
      inches: (fields[1] as num).toDouble(),
      note: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, WaistLogDBO obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.inches)
      ..writeByte(2)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaistLogDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WaistLogDBO _$WaistLogDBOFromJson(Map<String, dynamic> json) => WaistLogDBO(
  date: DateTime.parse(json['date'] as String),
  inches: (json['inches'] as num).toDouble(),
  note: json['note'] as String?,
);

Map<String, dynamic> _$WaistLogDBOToJson(WaistLogDBO instance) =>
    <String, dynamic>{
      'date': instance.date.toIso8601String(),
      'inches': instance.inches,
      'note': instance.note,
    };
