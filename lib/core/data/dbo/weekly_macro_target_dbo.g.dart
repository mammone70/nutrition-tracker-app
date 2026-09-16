// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weekly_macro_target_dbo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WeeklyMacroTargetDBOAdapter extends TypeAdapter<WeeklyMacroTargetDBO> {
  @override
  final typeId = 23;

  @override
  WeeklyMacroTargetDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WeeklyMacroTargetDBO(
      id: fields[0] as String,
      dayOfWeek: (fields[1] as num).toInt(),
      calories: (fields[2] as num).toInt(),
      proteinG: (fields[3] as num).toDouble(),
      fatG: (fields[4] as num).toDouble(),
      carbsG: (fields[5] as num).toDouble(),
      updatedAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, WeeklyMacroTargetDBO obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.dayOfWeek)
      ..writeByte(2)
      ..write(obj.calories)
      ..writeByte(3)
      ..write(obj.proteinG)
      ..writeByte(4)
      ..write(obj.fatG)
      ..writeByte(5)
      ..write(obj.carbsG)
      ..writeByte(6)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeeklyMacroTargetDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WeeklyMacroTargetDBO _$WeeklyMacroTargetDBOFromJson(
  Map<String, dynamic> json,
) => WeeklyMacroTargetDBO(
  id: json['id'] as String,
  dayOfWeek: (json['dayOfWeek'] as num).toInt(),
  calories: (json['calories'] as num).toInt(),
  proteinG: (json['proteinG'] as num).toDouble(),
  fatG: (json['fatG'] as num).toDouble(),
  carbsG: (json['carbsG'] as num).toDouble(),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$WeeklyMacroTargetDBOToJson(
  WeeklyMacroTargetDBO instance,
) => <String, dynamic>{
  'id': instance.id,
  'dayOfWeek': instance.dayOfWeek,
  'calories': instance.calories,
  'proteinG': instance.proteinG,
  'fatG': instance.fatG,
  'carbsG': instance.carbsG,
  'updatedAt': instance.updatedAt.toIso8601String(),
};
