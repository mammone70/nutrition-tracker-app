# Fitty Chat–centric architecture

## Decision

**Keep Hive (local-first) + Calorie Tracker REST sync.** The data model already
covers macros, meal plans, diary intakes, weight, and tracked-day totals. The
gap for natural-language workflows is **agent tool surface + navigation**, not
storage.

## Product direction

Center the app on **Fitty Chat**: users ask in natural language to query and
change plans, macros, diary, and metrics. Structured screens (Home dashboard,
Diary, plan editors) remain as deep links and visual summaries, not the primary
way to act.

## Example queries → capabilities

| Example | Capability |
|---------|------------|
| Average bodyweight and calories last week | `get_period_summary` (tracked days + weight range) |
| Weekly carb-cycle plan, 4300 avg, next 2 weeks | `set_weekly_macro_targets` (ongoing) + `set_daily_macro_targets` (finite horizon) |
| Macros left today; meal from leftovers | `get_remaining_macros` + `search_custom_meals` / food search + `log_intake` or `save_day_meal_plan` |

## Tool additions (this change)

- `get_period_summary` — date range averages for calories/macros + weight
- `get_remaining_macros` — effective targets − diary logged for a day
- `set_daily_macro_targets` — batch day overrides (e.g. next 14 days)
- `search_custom_meals` — local food DB match by name
- `log_intake` — write a food into the diary (closes leftover-meal loop)

## Navigation

Fitty Chat becomes a **bottom-nav tab** (replacing Trends in the dock; Trends
remains reachable from Home). Empty chat shows suggested prompts aligned with
the workflows above.

## Phases (technical)

1. **Query completeness** — period summary, remaining macros, weight ranges  
2. **Write completeness** — food search + diary log (this PR starts both)  
3. **Planning ergonomics** — batch daily overrides + weekly templates together  
4. **Shell** — chat tab, persistent history (follow-up), deep links from chat  
5. **Optional metrics** — waist etc. only if product needs them with sync contract  

## What not to do

- Do not replace Hive with a remote-only store for chat — privacy, offline, and
  existing sync contracts would regress.
- Do not invent nutrition in the model; always search tools or ask the user.
