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

| OpenNutriTracker | calorie-tracker |
|------------------|-----------------|
| Intake (meal log) | `foods` + `day_meals` + `food_log_entries` |
| Weight log | `POST /api/body-weight` (`unit: kg`) |
| Activities / water / full profile | not mirrored yet |

Food and day-meal IDs are deterministic UUIDv5 values so repeated logs of the
same product reuse one remote food row. Intake ids (already UUIDs) become
`food_log_entries` ids.

Meal slots: breakfast=0, lunch=1, dinner=2, snack=3.

## Code map

| Piece | Path |
|-------|------|
| Credentials | `lib/core/sync/calorie_tracker_sync_credentials.dart` |
| Outbox | `lib/core/sync/sync_outbox_data_source.dart` |
| Mapper | `lib/core/sync/calorie_tracker_sync_mapper.dart` |
| HTTP client | `lib/core/sync/calorie_tracker_api_client.dart` |
| Coordinator | `lib/core/sync/sync_service.dart` |
| Settings UI | `lib/features/settings/presentation/widgets/calorie_tracker_sync_screen.dart` |
