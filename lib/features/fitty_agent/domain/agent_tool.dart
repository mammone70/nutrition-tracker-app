/// A tool the Fitty Agent may call. Schemas are JSON Schema objects shared by
/// every provider — Dart re-validates arguments before execution.
class AgentToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  const AgentToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });
}

/// Tools covering macros, meal plans, diary progress, profile, and sync.
///
/// Writes go through local Hive use cases first; those enqueue calorie-tracker
/// sync when configured. The model never invents diary nutrition for logged
/// meals — it can only summarise what is already stored, or write meal-plan /
/// macro targets the user asked for.
const List<AgentToolDefinition> fittyAgentTools = [
  AgentToolDefinition(
    name: 'get_effective_macros',
    description:
        'Get the effective calorie and macro targets for a date '
        '(day override or weekly template).',
    parameters: {
      'type': 'object',
      'properties': {
        'date': {
          'type': 'string',
          'description': 'YYYY-MM-DD. Defaults to today when omitted.',
        },
      },
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: 'set_daily_macro_target',
    description:
        'Set or replace the day-specific macro/calorie override for a date. '
        'Synced to Calorie Tracker when sync is configured.',
    parameters: {
      'type': 'object',
      'properties': {
        'date': {'type': 'string', 'description': 'YYYY-MM-DD'},
        'calories': {'type': 'integer'},
        'protein_g': {'type': 'number'},
        'fat_g': {'type': 'number'},
        'carbs_g': {'type': 'number'},
      },
      'required': ['date', 'calories', 'protein_g', 'fat_g', 'carbs_g'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: 'get_weekly_macro_targets',
    description:
        'List weekly macro templates (day_of_week 0=Monday … 6=Sunday).',
    parameters: {
      'type': 'object',
      'properties': {
        'unused': {'type': 'string', 'description': 'Unused. Omit.'},
      },
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: 'set_weekly_macro_target',
    description:
        'Set the weekly macro template for one weekday '
        '(0=Monday … 6=Sunday). Prefer set_weekly_macro_targets when '
        'updating several days at once. Synced when configured.',
    parameters: {
      'type': 'object',
      'properties': {
        'day_of_week': {'type': 'integer', 'minimum': 0, 'maximum': 6},
        'calories': {'type': 'integer'},
        'protein_g': {'type': 'number'},
        'fat_g': {'type': 'number'},
        'carbs_g': {'type': 'number'},
      },
      'required': ['day_of_week', 'calories', 'protein_g', 'fat_g', 'carbs_g'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: 'set_weekly_macro_targets',
    description:
        'Set weekly macro templates for multiple weekdays in one call '
        '(0=Monday … 6=Sunday). Use this for carb-cycling or any plan that '
        'differs by day. Synced when configured.',
    parameters: {
      'type': 'object',
      'properties': {
        'targets': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'day_of_week': {'type': 'integer', 'minimum': 0, 'maximum': 6},
              'calories': {'type': 'integer'},
              'protein_g': {'type': 'number'},
              'fat_g': {'type': 'number'},
              'carbs_g': {'type': 'number'},
            },
            'required': [
              'day_of_week',
              'calories',
              'protein_g',
              'fat_g',
              'carbs_g',
            ],
            'additionalProperties': false,
          },
        },
      },
      'required': ['targets'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: 'get_day_meal_plan',
    description: 'Get the meal plan (meals and foods) for a specific date.',
    parameters: {
      'type': 'object',
      'properties': {
        'date': {
          'type': 'string',
          'description': 'YYYY-MM-DD. Defaults to today when omitted.',
        },
      },
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: 'save_day_meal_plan',
    description:
        'Replace the day meal plan for a date. Provide meals with optional '
        'food entries. Nutrition on foods must be values the user stated or '
        'already stored — do not invent diary calories.',
    parameters: {
      'type': 'object',
      'properties': {
        'date': {'type': 'string', 'description': 'YYYY-MM-DD'},
        'meals': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
              'meal_time': {'type': 'string', 'description': 'Optional HH:MM'},
              'foods': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'properties': {
                    'name': {'type': 'string'},
                    'brand': {'type': 'string'},
                    'quantity': {'type': 'number'},
                    'unit': {'type': 'string'},
                    'calories_per_100': {'type': 'number'},
                    'protein_per_100': {'type': 'number'},
                    'fat_per_100': {'type': 'number'},
                    'carbs_per_100': {'type': 'number'},
                  },
                  'required': [
                    'name',
                    'quantity',
                    'calories_per_100',
                    'protein_per_100',
                    'fat_per_100',
                    'carbs_per_100',
                  ],
                  'additionalProperties': false,
                },
              },
            },
            'required': ['name'],
            'additionalProperties': false,
          },
        },
      },
      'required': ['date', 'meals'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: 'get_weekly_meal_plan',
    description:
        'Get the weekly meal-plan template for one weekday '
        '(0=Monday … 6=Sunday).',
    parameters: {
      'type': 'object',
      'properties': {
        'day_of_week': {'type': 'integer', 'minimum': 0, 'maximum': 6},
      },
      'required': ['day_of_week'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: 'save_weekly_meal_plan',
    description:
        'Replace the weekly meal-plan template for one weekday '
        '(0=Monday … 6=Sunday).',
    parameters: {
      'type': 'object',
      'properties': {
        'day_of_week': {'type': 'integer', 'minimum': 0, 'maximum': 6},
        'meals': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
              'meal_time': {'type': 'string'},
              'foods': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'properties': {
                    'name': {'type': 'string'},
                    'brand': {'type': 'string'},
                    'quantity': {'type': 'number'},
                    'unit': {'type': 'string'},
                    'calories_per_100': {'type': 'number'},
                    'protein_per_100': {'type': 'number'},
                    'fat_per_100': {'type': 'number'},
                    'carbs_per_100': {'type': 'number'},
                  },
                  'required': [
                    'name',
                    'quantity',
                    'calories_per_100',
                    'protein_per_100',
                    'fat_per_100',
                    'carbs_per_100',
                  ],
                  'additionalProperties': false,
                },
              },
            },
            'required': ['name'],
            'additionalProperties': false,
          },
        },
      },
      'required': ['day_of_week', 'meals'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: 'get_diary_day',
    description:
        'Summarise foods already logged in the diary for a date '
        '(calories and macros from stored food database values).',
    parameters: {
      'type': 'object',
      'properties': {
        'date': {
          'type': 'string',
          'description': 'YYYY-MM-DD. Defaults to today when omitted.',
        },
      },
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: 'get_profile_summary',
    description:
        'Read the user profile relevant to goals and progress: age band, '
        'height, weight, goal, activity level, target weight.',
    parameters: {
      'type': 'object',
      'properties': {
        'unused': {'type': 'string', 'description': 'Unused. Omit.'},
      },
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: 'get_weight_history',
    description: 'List recent body-weight log entries.',
    parameters: {
      'type': 'object',
      'properties': {
        'limit': {'type': 'integer', 'description': 'Max entries, default 14.'},
      },
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: 'log_weight',
    description:
        'Log a body weight for a date (YYYY-MM-DD). Updates current weight '
        'when the date is today. Synced when Calorie Tracker sync is on.',
    parameters: {
      'type': 'object',
      'properties': {
        'date': {'type': 'string'},
        'weight_kg': {'type': 'number'},
      },
      'required': ['date', 'weight_kg'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: 'get_sync_status',
    description:
        'Whether Calorie Tracker sync is configured, pending outbox count, '
        'last sync time, and last error.',
    parameters: {
      'type': 'object',
      'properties': {
        'unused': {'type': 'string', 'description': 'Unused. Omit.'},
      },
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: 'sync_now',
    description:
        'Push local pending changes to the Calorie Tracker API and pull '
        'remote updates. No-op when sync is not configured.',
    parameters: {
      'type': 'object',
      'properties': {
        'unused': {'type': 'string', 'description': 'Unused. Omit.'},
      },
      'additionalProperties': false,
    },
  ),
];

const fittyAgentSystemPrompt = '''
You are Fitty Agent for the Fitty Kitties nutrition app.
You help the user with macro targets, meal planning, diary progress, profile goals, and Calorie Tracker sync.
Use tools to read or write local data. Writes are stored on-device first and synced through the REST API when sync is configured.
Rules:
- Prefer tools over guessing. If data is missing, say so.
- Dates are YYYY-MM-DD. Weekdays use 0=Monday through 6=Sunday.
- When setting macros for several weekdays (carb cycling, high/low days, etc.), use set_weekly_macro_targets once with every day — do not call set_weekly_macro_target seven times.
- When you need several independent tools, call them together in one step.
- Protein/carbs are 4 kcal/g and fat is 9 kcal/g when deriving carbs from remaining calories.
- Never invent nutrition numbers for foods the user already logged; diary macros come from stored food data via get_diary_day.
- For meal-plan foods, only use nutrition values the user provided in this chat or that tools returned. Do not invent nutrition.
- The user may attach one or more meal photos (up to 10). Identify visible foods, prefer getting the current day or weekly meal plan first, then update with save_day_meal_plan or save_weekly_meal_plan. Use quantities the user stated; photo-based counts are approximate — ask when unsure. Prefer nutrition the user stated; otherwise ask rather than guessing.
- Keep answers concise and actionable.
- After writing, briefly confirm what changed (include calories and macros per day type).
''';
