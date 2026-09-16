import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/domain/entity/weekly_macro_target_entity.dart';
import 'package:opennutritracker/core/domain/usecase/weekly_macro_target_usecase.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/calc/macro_calories.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/meal_plan_utils.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:uuid/uuid.dart';

class WeeklyMacroTargetsScreen extends StatefulWidget {
  const WeeklyMacroTargetsScreen({super.key});

  @override
  State<WeeklyMacroTargetsScreen> createState() =>
      _WeeklyMacroTargetsScreenState();
}

class _DayForm {
  final TextEditingController calories = TextEditingController();
  final TextEditingController protein = TextEditingController();
  final TextEditingController fat = TextEditingController();
  final TextEditingController carbs = TextEditingController();
  String? existingId;

  void dispose() {
    calories.dispose();
    protein.dispose();
    fat.dispose();
    carbs.dispose();
  }
}

class _WeeklyMacroTargetsScreenState extends State<WeeklyMacroTargetsScreen> {
  final _log = Logger('WeeklyMacroTargetsScreen');
  static const _uuid = Uuid();
  late final List<_DayForm> _forms;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _forms = List.generate(7, (_) => _DayForm());
    _load();
  }

  @override
  void dispose() {
    for (final form in _forms) {
      form.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final targets = await locator<GetWeeklyMacroTargetsUsecase>().getAll();
    if (!mounted) return;
    for (final target in targets) {
      if (target.dayOfWeek < 0 || target.dayOfWeek > 6) continue;
      final form = _forms[target.dayOfWeek];
      form.existingId = target.id;
      form.calories.text = '${target.calories}';
      form.protein.text = _fmt(target.proteinG);
      form.fat.text = _fmt(target.fatG);
      form.carbs.text = _fmt(target.carbsG);
    }
    setState(() => _loading = false);
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

  String? _dayError(int index) {
    final form = _forms[index];
    final hasValues =
        form.calories.text.isNotEmpty ||
        form.protein.text.isNotEmpty ||
        form.fat.text.isNotEmpty ||
        form.carbs.text.isNotEmpty;
    if (!hasValues) return null;
    final cal = int.tryParse(form.calories.text) ?? 0;
    final p = double.tryParse(form.protein.text) ?? 0;
    final f = double.tryParse(form.fat.text) ?? 0;
    final c = double.tryParse(form.carbs.text) ?? 0;
    return macroCaloriesError(cal, p, f, c);
  }

  Future<void> _save() async {
    for (var i = 0; i < 7; i++) {
      final err = _dayError(i);
      if (err != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${weekdays[i]}: $err')));
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now().toUtc();
      final toSave = <WeeklyMacroTargetEntity>[];
      for (var i = 0; i < 7; i++) {
        final form = _forms[i];
        final hasValues =
            form.calories.text.isNotEmpty ||
            form.protein.text.isNotEmpty ||
            form.fat.text.isNotEmpty ||
            form.carbs.text.isNotEmpty;
        if (!hasValues) continue;
        toSave.add(
          WeeklyMacroTargetEntity(
            id: form.existingId ?? _uuid.v4(),
            dayOfWeek: i,
            calories: int.tryParse(form.calories.text) ?? 0,
            proteinG: double.tryParse(form.protein.text) ?? 0,
            fatG: double.tryParse(form.fat.text) ?? 0,
            carbsG: double.tryParse(form.carbs.text) ?? 0,
            updatedAt: now,
          ),
        );
      }
      await locator<SaveWeeklyMacroTargetsUsecase>().saveAll(toSave);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).calorieTrackerSyncSavedLabel)),
      );
    } catch (e, st) {
      _log.warning('Failed to save weekly macro targets', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _weekdayLabel(BuildContext context, int index) {
    switch (index) {
      case 0:
        return S.of(context).weekdayMonday;
      case 1:
        return S.of(context).weekdayTuesday;
      case 2:
        return S.of(context).weekdayWednesday;
      case 3:
        return S.of(context).weekdayThursday;
      case 4:
        return S.of(context).weekdayFriday;
      case 5:
        return S.of(context).weekdaySaturday;
      default:
        return S.of(context).weekdaySunday;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).weeklyMacroTargetsTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(Dimens.spacing16),
              children: [
                Text(
                  S.of(context).weeklyMacroTargetsSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: Dimens.spacing16),
                for (var i = 0; i < 7; i++) ...[
                  Text(
                    _weekdayLabel(context, i),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: Dimens.spacing8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _forms[i].calories,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Cal',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: Dimens.spacing8),
                      Expanded(
                        child: TextField(
                          controller: _forms[i].protein,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'P',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: Dimens.spacing8),
                      Expanded(
                        child: TextField(
                          controller: _forms[i].fat,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'F',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: Dimens.spacing8),
                      Expanded(
                        child: TextField(
                          controller: _forms[i].carbs,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'C',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  if (_dayError(i) != null)
                    Padding(
                      padding: const EdgeInsets.only(top: Dimens.spacing4),
                      child: Text(
                        S.of(context).macrosCaloriesMismatchLabel,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: Dimens.spacing16),
                ],
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(S.of(context).saveWeeklyTargetsLabel),
                ),
              ],
            ),
    );
  }
}
