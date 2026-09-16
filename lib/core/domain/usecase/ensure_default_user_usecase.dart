import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/domain/entity/default_user_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_user_usecase.dart';

/// Ensures the active profile has a user row so calorie goals and home can
/// load without forcing the multi-step onboarding questionnaire.
class EnsureDefaultUserUsecase {
  final UserRepository _userRepository;
  final AddUserUsecase _addUserUsecase;

  EnsureDefaultUserUsecase(this._userRepository, this._addUserUsecase);

  /// Returns `true` if a user already existed; `false` if a default was seeded.
  Future<bool> ensureExists() async {
    if (await _userRepository.hasUserData()) return true;
    await _addUserUsecase.addUser(createDefaultUserEntity());
    return false;
  }
}
