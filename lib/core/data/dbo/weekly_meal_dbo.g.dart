// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weekly_meal_dbo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WeeklyMealDBOAdapter extends TypeAdapter<WeeklyMealDBO> {
  @override
  final typeId = 25;

  @override
  WeeklyMealDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WeeklyMealDBO(
      id: fields[0] as String,
      dayOfWeek: (fields[1] as num).toInt(),
      mealIndex: (fields[2] as num).toInt(),
      name: fields[3] as String,
      mealTime: fields[4] as String?,
      updatedAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, WeeklyMealDBO obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.dayOfWeek)
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
      other is WeeklyMealDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WeeklyMealDBO _$WeeklyMealDBOFromJson(Map<String, dynamic> json) =>
    WeeklyMealDBO(
      id: json['id'] as String,
      dayOfWeek: (json['dayOfWeek'] as num).toInt(),
      mealIndex: (json['mealIndex'] as num).toInt(),
      name: json['name'] as String,
      mealTime: json['mealTime'] as String?,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$WeeklyMealDBOToJson(WeeklyMealDBO instance) =>
    <String, dynamic>{
      'id': instance.id,
      'dayOfWeek': instance.dayOfWeek,
      'mealIndex': instance.mealIndex,
      'name': instance.name,
      'mealTime': instance.mealTime,
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
