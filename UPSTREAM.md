# Upstream

**Fitty Kitties** is based on [OpenNutriTracker](https://github.com/simonoppowa/OpenNutriTracker)
(GPLv3), imported into [mammone70/nutrition-tracker-app](https://github.com/mammone70/nutrition-tracker-app).

Upstream focus: privacy-first, **local-only** diary storage (encrypted Hive).

This fork keeps that local-first model and adds an optional, offline-capable sync
layer against the [mammone70/calorie-tracker](https://github.com/mammone70/calorie-tracker)
REST API — diary intake, body weight, weekly/daily macro templates, and meal plans.
Local Hive remains the source of truth for reads; the network is used only to push
queued mutations and pull remote changes when reachable.

See `docs/calorie-tracker-sync.md` for the sync contract and outbox design.
