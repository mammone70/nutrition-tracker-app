import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:opennutritracker/core/data/dbo/calories_profile_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_gender_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_pal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_weight_goal_dbo.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';

part 'user_dbo.g.dart';

@HiveType(typeId: 5)
class UserDBO extends HiveObject {
  @HiveField(0)
  DateTime birthday;
  @HiveField(1)
  double heightCM;
  @HiveField(2)
  double weightKG;
  @HiveField(3)
  UserGenderDBO gender;
  @HiveField(4)
  UserWeightGoalDBO goal;
  @HiveField(5)
  UserPALDBO pal;
  @HiveField(6)
  double? weeklyWeightGoalKg;
  @HiveField(7)
  CaloriesProfileDBO? caloriesProfile;
  @HiveField(8)
  double? targetWeightKg;
  // Opt-in linear taper that scales the daily kcal deficit down as
  // current weight approaches the target. Sits next to targetWeightKg
  // because the toggle only has anything to act on once a target
  // weight is set; lives on the user, not on app config, since it's a
  // personal weight-goal preference rather than an app-wide setting.
  @HiveField(9)
  bool caloriesTaperEnabled;

  UserDBO({
    required this.birthday,
    required this.heightCM,
    required this.weightKG,
    required this.gender,
    required this.goal,
    required this.pal,
    this.weeklyWeightGoalKg,
    this.caloriesProfile,
    this.targetWeightKg,
    this.caloriesTaperEnabled = false,
  });

  factory UserDBO.fromUserEntity(UserEntity entity) {
    return UserDBO(
      birthday: entity.birthday,
      heightCM: entity.heightCM,
      weightKG: entity.weightKG,
      gender: UserGenderDBO.fromUserGenderEntity(entity.gender),
      goal: UserWeightGoalDBO.fromUserWeightGoalEntity(entity.goal),
      pal: UserPALDBO.fromUserPALEntity(entity.pal),
      weeklyWeightGoalKg: entity.weeklyWeightGoalKg,
      caloriesProfile: entity.caloriesProfile == null
          ? null
          : CaloriesProfileDBO.fromEntity(entity.caloriesProfile!),
      targetWeightKg: entity.targetWeightKg,
      caloriesTaperEnabled: entity.caloriesTaperEnabled,
    );
  }

  /// Hand-written so calorie-tracker sync can enqueue/pull without adding
  /// json_serializable to every nested user enum DBO.
  factory UserDBO.fromJson(Map<String, dynamic> json) {
    final profileRaw = json['caloriesProfile'] as String?;
    return UserDBO(
      birthday: DateTime.parse(json['birthday'] as String),
      heightCM: (json['heightCM'] as num).toDouble(),
      weightKG: (json['weightKG'] as num).toDouble(),
      gender: UserGenderDBO.values.byName(json['gender'] as String),
      goal: UserWeightGoalDBO.values.byName(json['goal'] as String),
      pal: UserPALDBO.values.byName(json['pal'] as String),
      weeklyWeightGoalKg: (json['weeklyWeightGoalKg'] as num?)?.toDouble(),
      caloriesProfile: profileRaw == null
          ? null
          : CaloriesProfileDBO.values.byName(profileRaw),
      targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble(),
      caloriesTaperEnabled: json['caloriesTaperEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'birthday': birthday.toIso8601String(),
        'heightCM': heightCM,
        'weightKG': weightKG,
        'gender': gender.name,
        'goal': goal.name,
        'pal': pal.name,
        'weeklyWeightGoalKg': weeklyWeightGoalKg,
        'caloriesProfile': caloriesProfile?.name,
        'targetWeightKg': targetWeightKg,
        'caloriesTaperEnabled': caloriesTaperEnabled,
      };
}
