// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'day_meal_dbo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DayMealDBOAdapter extends TypeAdapter<DayMealDBO> {
  @override
  final typeId = 27;

  @override
  DayMealDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DayMealDBO(
      id: fields[0] as String,
      planDate: fields[1] as String,
      mealIndex: (fields[2] as num).toInt(),
      name: fields[3] as String,
      mealTime: fields[4] as String?,
      updatedAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, DayMealDBO obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.planDate)
      ..writeByte(2)
      ..write(obj.mealIndex)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.mealTime)
      ..writeByte(5)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayMealDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DayMealDBO _$DayMealDBOFromJson(Map<String, dynamic> json) => DayMealDBO(
  id: json['id'] as String,
  planDate: json['planDate'] as String,
  mealIndex: (json['mealIndex'] as num).toInt(),
  name: json['name'] as String,
  mealTime: json['mealTime'] as String?,
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$DayMealDBOToJson(DayMealDBO instance) =>
    <String, dynamic>{
      'id': instance.id,
      'planDate': instance.planDate,
      'mealIndex': instance.mealIndex,
      'name': instance.name,
      'mealTime': instance.mealTime,
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
