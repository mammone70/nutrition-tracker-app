import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_gender_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';

/// Neutral starter profile so the diary is usable without onboarding forms.
///
/// Values are mid-range placeholders; Profile settings can replace them later.
UserEntity createDefaultUserEntity({DateTime? now}) {
  final today = now ?? DateTime.now();
  return UserEntity(
    birthday: DateTime(today.year - 30, 1, 1),
    heightCM: 170,
    weightKG: 70,
    gender: UserGenderEntity.male,
    goal: UserWeightGoalEntity.maintainWeight,
    pal: UserPALEntity.sedentary,
  );
}
