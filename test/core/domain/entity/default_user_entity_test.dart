import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/default_user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_gender_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';

void main() {
  test('default user is a complete maintain/sedentary profile', () {
    final user = createDefaultUserEntity(now: DateTime(2026, 9, 16));
    expect(user.birthday, DateTime(1996, 1, 1));
    expect(user.heightCM, 170);
    expect(user.weightKG, 70);
    expect(user.gender, UserGenderEntity.male);
    expect(user.goal, UserWeightGoalEntity.maintainWeight);
    expect(user.pal, UserPALEntity.sedentary);
  });
}
