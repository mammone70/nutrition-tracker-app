# Calorie-tracker sync (local-first)

This fork keeps OpenNutriTracker's encrypted Hive diary as the **source of
truth for reads**. Optional sync talks to
[mammone70/calorie-tracker](https://github.com/mammone70/calorie-tracker)
using the same local-first pattern as that project's web client:

1. Persist to Hive first.
2. Enqueue mutations in an encrypted outbox.
3. `POST /api/sync/push` when online; `GET /api/sync?since=` to pull.
4. Weight uses `POST /api/body-weight` (not part of `/api/sync/push`).

## Settings

**Settings → Data → Calorie Tracker sync**

- Enable / disable
- API base URL (default `https://api.cal-count.mammonesoftware.org/api`)
- Email + password (JWT login / refresh)

## Auth

- `POST /api/auth/login` → `accessToken` + `refreshToken`
- `POST /api/auth/refresh` when access expires
- Requests send `Authorization: Bearer …` and `X-User-Timezone`

## Diary mapping

| OpenNutriTracker | calorie-tracker | Direction |
|------------------|-----------------|-----------|
| Intake (meal log) | `foods` + `day_meals` + `food_log_entries` | push + pull |
| Weight log | `POST /api/body-weight` (`unit: kg`) | push |
| Weekly macro targets | `weekly_macro_targets` | push + pull |
| Daily macro override | `macro_targets` | push + pull |
| Weekly meals | `weekly_meals` | push + pull |
| Weekly meal plan foods | `foods` + `weekly_meal_plan_entries` | push + pull |
| Day meal overrides | `day_meals` | push + pull |
| Day meal plan foods | `foods` + `meal_plan_entries` | push + pull |
| Activities / water / full profile | not mirrored yet | — |

Food and day-meal IDs are deterministic UUIDv5 values so repeated logs of the
same product reuse one remote food row. Intake ids (already UUIDs) become
`food_log_entries` ids.

Meal slots: breakfast=0, lunch=1, dinner=2, snack=3.

Weekly templates use `dayOfWeek` 0=Monday … 6=Sunday. Effective targets and
meal plans resolve as: **day override → weekly template → none**.

### Meal-plan sync behaviour

- **Push:** every local save/delete of a day plan, weekly plan, or macro target
  enqueues an outbox mutation and drains on `syncNow` (Settings → Sync now,
  app resume, or after a write).
- **Pull:** `GET /api/sync?since=` applies `dayMeals`, `mealPlanEntries`,
  `weeklyMeals`, `weeklyMealPlanEntries`, `macroTargets`, and
  `weeklyMacroTargets` into Hive (joining `foods` for denormalized nutrients).
  Rows still pending in the outbox are skipped so a local edit wins the round
  trip. Soft-deleted remote rows (`deletedAt`) remove the local copy.
- **First sync:** when no pull cursor exists yet, local day/weekly plans and
  macro targets are seeded into the outbox before push, then remote rows are
  pulled — so both directions populate on the first successful sync.

## Code map

| Piece | Path |
|-------|------|
| Credentials | `lib/core/sync/calorie_tracker_sync_credentials.dart` |
| Outbox | `lib/core/sync/sync_outbox_data_source.dart` |
| Mapper | `lib/core/sync/calorie_tracker_sync_mapper.dart` |
| HTTP client | `lib/core/sync/calorie_tracker_api_client.dart` |
| Coordinator | `lib/core/sync/sync_service.dart` |
| Settings UI | `lib/features/settings/presentation/widgets/calorie_tracker_sync_screen.dart` |
| Weekly macro targets UI | `lib/features/meal_plan/weekly_macro_targets_screen.dart` |
| Weekly meal plans UI | `lib/features/meal_plan/weekly_meal_plans_screen.dart` |
| Day meal plan UI | `lib/features/meal_plan/day_meal_plan_screen.dart` |
| Macro calorie helpers | `lib/core/utils/calc/macro_calories.dart` |
| Meal plan helpers | `lib/core/utils/meal_plan_utils.dart` |
