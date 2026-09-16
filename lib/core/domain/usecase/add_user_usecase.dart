import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';

class AddUserUsecase {
  final UserRepository _userRepository;
  final SyncService _syncService;

  AddUserUsecase(this._userRepository, this._syncService);

  Future<void> addUser(UserEntity userEntity) async {
    await _userRepository.updateUserData(userEntity);
    await _syncService.enqueueUserUpsert(userEntity);
  }
}
