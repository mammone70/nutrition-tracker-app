// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'confirmed_plan_food_dbo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ConfirmedPlanFoodDBOAdapter extends TypeAdapter<ConfirmedPlanFoodDBO> {
  @override
  final typeId = 29;

  @override
  ConfirmedPlanFoodDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ConfirmedPlanFoodDBO(
      planDate: fields[0] as String,
      entryId: fields[1] as String,
      intakeId: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ConfirmedPlanFoodDBO obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.planDate)
      ..writeByte(1)
      ..write(obj.entryId)
      ..writeByte(2)
      ..write(obj.intakeId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConfirmedPlanFoodDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConfirmedPlanFoodDBO _$ConfirmedPlanFoodDBOFromJson(
  Map<String, dynamic> json,
) => ConfirmedPlanFoodDBO(
  planDate: json['planDate'] as String,
  entryId: json['entryId'] as String,
  intakeId: json['intakeId'] as String,
);

Map<String, dynamic> _$ConfirmedPlanFoodDBOToJson(
  ConfirmedPlanFoodDBO instance,
) => <String, dynamic>{
  'planDate': instance.planDate,
  'entryId': instance.entryId,
  'intakeId': instance.intakeId,
};
