import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/domain/entity/profile_entity.dart';
import 'package:opennutritracker/core/domain/usecase/ensure_default_user_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/switch_profile_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:opennutritracker/features/recipes/presentation/bloc/recipes_bloc.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/custom_meals_bloc.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/settings_bloc.dart';

/// Owns the ordering of a profile switch so it lives in exactly one place:
/// swap the open box-set first, then refresh the cached tab BLoCs, then
/// route. The screen-persistent tab BLoCs are GetIt singletons that hold
/// the outgoing profile's data, so each must be told to re-read once the
/// new boxes are open.
///
/// A freshly created profile gets a default user seeded so the diary is
/// usable immediately without the onboarding questionnaire.
class ProfileSwitchCoordinator {
  final SwitchProfileUsecase _switchProfileUsecase;
  final UserRepository _userRepository;

  ProfileSwitchCoordinator(this._switchProfileUsecase, this._userRepository);

  Future<void> switchTo(BuildContext context, ProfileEntity profile) async {
    await _switchProfileUsecase.switchProfile(profile);
    final hasUserData = await _userRepository.hasUserData();
    if (!hasUserData) {
      await locator<EnsureDefaultUserUsecase>().ensureExists();
    }
    if (!context.mounted) return;

    reloadTabBlocs();
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(NavigationOptions.mainRoute, (route) => false);
  }

  /// Re-reads every screen-persistent tab BLoC against the now-active
  /// profile's boxes. Safe to call only once the active profile has user
  /// data.
  static void reloadTabBlocs() {
    locator<HomeBloc>().add(const LoadItemsEvent());
    locator<DiaryBloc>().add(const LoadDiaryYearEvent());
    locator<CalendarDayBloc>().add(RefreshCalendarDayEvent());
    locator<ProfileBloc>().add(LoadProfileEvent());
    locator<RecipesBloc>().add(LoadRecipesEvent());
    locator<CustomMealsBloc>().add(LoadCustomMealsEvent());
    locator<SettingsBloc>().add(LoadSettingsEvent());
  }
}
