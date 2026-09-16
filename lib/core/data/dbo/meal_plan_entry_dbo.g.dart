// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_plan_entry_dbo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MealPlanEntryDBOAdapter extends TypeAdapter<MealPlanEntryDBO> {
  @override
  final typeId = 28;

  @override
  MealPlanEntryDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MealPlanEntryDBO(
      id: fields[0] as String,
      planDate: fields[1] as String,
      dayMealId: fields[2] as String,
      foodId: fields[3] as String,
      foodName: fields[4] as String,
      brand: fields[5] as String?,
      caloriesPer100: (fields[6] as num).toDouble(),
      proteinPer100: (fields[7] as num).toDouble(),
      fatPer100: (fields[8] as num).toDouble(),
      carbsPer100: (fields[9] as num).toDouble(),
      quantity: (fields[10] as num).toDouble(),
      unit: fields[11] as String,
      updatedAt: fields[12] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, MealPlanEntryDBO obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.planDate)
      ..writeByte(2)
      ..write(obj.dayMealId)
      ..writeByte(3)
      ..write(obj.foodId)
      ..writeByte(4)
      ..write(obj.foodName)
      ..writeByte(5)
      ..write(obj.brand)
      ..writeByte(6)
      ..write(obj.caloriesPer100)
      ..writeByte(7)
      ..write(obj.proteinPer100)
      ..writeByte(8)
      ..write(obj.fatPer100)
      ..writeByte(9)
      ..write(obj.carbsPer100)
      ..writeByte(10)
      ..write(obj.quantity)
      ..writeByte(11)
      ..write(obj.unit)
      ..writeByte(12)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealPlanEntryDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MealPlanEntryDBO _$MealPlanEntryDBOFromJson(Map<String, dynamic> json) =>
    MealPlanEntryDBO(
      id: json['id'] as String,
      planDate: json['planDate'] as String,
      dayMealId: json['dayMealId'] as String,
      foodId: json['foodId'] as String,
      foodName: json['foodName'] as String,
      brand: json['brand'] as String?,
      caloriesPer100: (json['caloriesPer100'] as num).toDouble(),
      proteinPer100: (json['proteinPer100'] as num).toDouble(),
      fatPer100: (json['fatPer100'] as num).toDouble(),
      carbsPer100: (json['carbsPer100'] as num).toDouble(),
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$MealPlanEntryDBOToJson(MealPlanEntryDBO instance) =>
    <String, dynamic>{
      'id': instance.id,
      'planDate': instance.planDate,
      'dayMealId': instance.dayMealId,
      'foodId': instance.foodId,
      'foodName': instance.foodName,
      'brand': instance.brand,
      'caloriesPer100': instance.caloriesPer100,
      'proteinPer100': instance.proteinPer100,
      'fatPer100': instance.fatPer100,
      'carbsPer100': instance.carbsPer100,
      'quantity': instance.quantity,
      'unit': instance.unit,
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
