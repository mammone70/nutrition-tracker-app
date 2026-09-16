# Calorie-tracker sync (local-first)

This fork keeps OpenNutriTracker's encrypted Hive diary as the **source of
truth for reads**. The optional [mammone70/calorie-tracker](https://github.com/mammone70/calorie-tracker)
REST API is used only to:

1. **Push** mutations that already succeeded locally (outbox).
2. **Pull** remote changes when the device is online.

If the network is down, the app keeps working from Hive. Queued operations
drain automatically when connectivity returns (after each local write, on
manual "Sync now", and when the app resumes).

## Settings

**Settings → Data → Calorie Tracker sync**

- Enable / disable sync
- Base URL (no trailing slash), e.g. `https://api.example.com`
- Bearer token (stored in Flutter Secure Storage)

Sync is a no-op until enable + URL + token are all set.

## Outbox

Pending mutations live in an encrypted Hive box `SyncOutboxBox` as JSON:

| Field | Meaning |
|-------|---------|
| `resource` | `intake` \| `activity` \| `trackedDay` \| `weightLog` \| `waterIntake` \| `user` |
| `mutation` | `upsert` \| `delete` |
| `resourceId` | Local id (`yyyy-MM-dd` for tracked days / weight log) |
| `payload` | Export-format DBO JSON for upserts |
| `enqueuedAt` | UTC timestamp |
| `attempts` / `lastError` | Retry metadata |

Multiple edits to the same resource collapse to one outbox entry.

## Provisional REST contract

> **Note:** `mammone70/calorie-tracker` was not readable from this environment
> when the client was written (GitHub 404). Paths below match the diary export
> shapes in `docs/export-format.md`. Adapt
> `lib/core/sync/calorie_tracker_api_client.dart` if the live API differs —
> the outbox and local write path stay the same.

Auth: `Authorization: Bearer <token>`

| Method | Path | Body |
|--------|------|------|
| `GET` | `/health` | — |
| `GET` | `/v1/intakes?since=ISO8601` | — (list or `{ "items": [...] }`) |
| `PUT` | `/v1/intakes/{id}` | Intake DBO JSON |
| `DELETE` | `/v1/intakes/{id}` | — |
| `GET` | `/v1/activities?since=` | |
| `PUT` | `/v1/activities/{id}` | UserActivity DBO JSON |
| `DELETE` | `/v1/activities/{id}` | |
| `GET` | `/v1/tracked-days?since=` | |
| `PUT` | `/v1/tracked-days/{yyyy-MM-dd}` | TrackedDay DBO JSON |
| `GET` | `/v1/weight-log?since=` | |
| `PUT` | `/v1/weight-log/{yyyy-MM-dd}` | WeightLog DBO JSON |
| `DELETE` | `/v1/weight-log/{yyyy-MM-dd}` | |
| `GET` | `/v1/water-intake?since=` | |
| `PUT` | `/v1/water-intake/{id}` | WaterIntake DBO JSON |
| `DELETE` | `/v1/water-intake/{id}` | |
| `GET` | `/v1/user` | |
| `PUT` | `/v1/user` | User DBO JSON |

### Conflict policy

- Local pending outbox ids are **not** overwritten by pull.
- Otherwise remote rows upsert into Hive by id (last remote write wins for
  records with no local pending change).

## Code map

| Piece | Path |
|-------|------|
| Credentials | `lib/core/sync/calorie_tracker_sync_credentials.dart` |
| Outbox | `lib/core/sync/sync_outbox_data_source.dart` |
| HTTP client | `lib/core/sync/calorie_tracker_api_client.dart` |
| Coordinator | `lib/core/sync/sync_service.dart` |
| Settings UI | `lib/features/settings/presentation/widgets/calorie_tracker_sync_screen.dart` |
