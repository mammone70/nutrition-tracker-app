import 'package:flutter/material.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Compact, scannable calorie + macro summary used on Home and meal-plan
/// editors. Keeps each metric on its own chip so the line does not wrap into
/// an unreadable slash/dot soup.
class MealPlanMacroSummary extends StatelessWidget {
  const MealPlanMacroSummary({
    super.key,
    required this.calories,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    this.label,
    this.targetCalories,
    this.targetProteinG,
    this.targetFatG,
    this.targetCarbsG,
  });

  final String? label;
  final num calories;
  final num proteinG;
  final num fatG;
  final num carbsG;
  final num? targetCalories;
  final num? targetProteinG;
  final num? targetFatG;
  final num? targetCarbsG;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context);
    final chipStyle = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    Widget chip(String text) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Dimens.radiusS),
        ),
        child: Text(text, style: chipStyle),
      );
    }

    String pair(num value, num? target, {String suffix = ''}) {
      final left = value.round().toString();
      if (target == null) return '$left$suffix';
      return '$left / ${target.round()}$suffix';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Dimens.spacing8),
        ],
        Wrap(
          spacing: Dimens.spacing8,
          runSpacing: Dimens.spacing8,
          children: [
            chip(pair(calories, targetCalories, suffix: ' kcal')),
            chip(
              '${s.proteinLabelShort.toUpperCase()} '
              '${pair(proteinG, targetProteinG)}',
            ),
            chip(
              '${s.fatLabelShort.toUpperCase()} '
              '${pair(fatG, targetFatG)}',
            ),
            chip(
              '${s.carbsLabelShort.toUpperCase()} '
              '${pair(carbsG, targetCarbsG)}',
            ),
          ],
        ),
      ],
    );
  }
}

/// Two-line food subtitle: amount + kcal, then macros — avoids one dense
/// horizontal string that wraps mid-token on narrow screens.
class MealPlanFoodMacrosSubtitle extends StatelessWidget {
  const MealPlanFoodMacrosSubtitle({
    super.key,
    required this.quantityLabel,
    required this.calories,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
  });

  final String quantityLabel;
  final num calories;
  final num proteinG;
  final num fatG;
  final num carbsG;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context);
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$quantityLabel · ${calories.round()} kcal',
          style: secondary,
        ),
        Text(
          '${s.proteinLabelShort.toUpperCase()} ${proteinG.round()}  ·  '
          '${s.fatLabelShort.toUpperCase()} ${fatG.round()}  ·  '
          '${s.carbsLabelShort.toUpperCase()} ${carbsG.round()}',
          style: secondary,
        ),
      ],
    );
  }
}
