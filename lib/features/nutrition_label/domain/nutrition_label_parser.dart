import 'package:opennutritracker/features/nutrition_label/domain/nutrition_label_entity.dart';

/// Bounds a transcribed nutrient so a runaway model cannot write absurd
/// figures into the custom-meal form. Matching the spirit of
/// `validateParsedMealItems`: enforcement is in Dart, not in the schema.
const _maxEnergyKcal = 2000.0;
const _maxMacroG = 500.0;
const _maxMineralMg = 10000.0;
const _maxVitaminUg = 10000.0;
const _maxServing = 5000.0;

/// Turns the tool-call JSON into a [NutritionLabelEntity], dropping anything
/// that is not a finite non-negative number in a plausible range.
NutritionLabelEntity nutritionLabelFromJson(Object? raw) {
  if (raw is! Map) {
    return const NutritionLabelEntity(basis: NutritionLabelBasis.per100);
  }

  final map = Map<String, dynamic>.from(raw);
  final basisRaw = map['basis'];
  final basis = basisRaw == 'per_serving'
      ? NutritionLabelBasis.perServing
      : NutritionLabelBasis.per100;

  final unitRaw = map['serving_unit'];
  final unit = unitRaw == 'ml' ? 'ml' : 'g';

  return NutritionLabelEntity(
    name: _nonEmptyString(map['name']),
    brands: _nonEmptyString(map['brands']),
    barcode: _digitsOnlyBarcode(map['barcode']),
    servingQuantity: _bounded(map['serving_quantity'], max: _maxServing),
    servingUnit: unit,
    basis: basis,
    energyKcal: _bounded(map['energy_kcal'], max: _maxEnergyKcal),
    carbohydratesG: _bounded(map['carbohydrates_g'], max: _maxMacroG),
    fatG: _bounded(map['fat_g'], max: _maxMacroG),
    proteinsG: _bounded(map['proteins_g'], max: _maxMacroG),
    fiberG: _bounded(map['fiber_g'], max: _maxMacroG),
    sugarsG: _bounded(map['sugars_g'], max: _maxMacroG),
    saturatedFatG: _bounded(map['saturated_fat_g'], max: _maxMacroG),
    sodiumMg: _bounded(map['sodium_mg'], max: _maxMineralMg),
    calciumMg: _bounded(map['calcium_mg'], max: _maxMineralMg),
    ironMg: _bounded(map['iron_mg'], max: _maxMineralMg),
    potassiumMg: _bounded(map['potassium_mg'], max: _maxMineralMg),
    magnesiumMg: _bounded(map['magnesium_mg'], max: _maxMineralMg),
    vitaminDUg: _bounded(map['vitamin_d_ug'], max: _maxVitaminUg),
    vitaminB12Ug: _bounded(map['vitamin_b12_ug'], max: _maxVitaminUg),
  );
}

String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Retail barcodes are 8–14 digits. Anything else is dropped rather than
/// written into the custom-meal barcode field.
String? _digitsOnlyBarcode(Object? value) {
  final text = _nonEmptyString(value);
  if (text == null) return null;
  final digits = text.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 8 || digits.length > 14) return null;
  return digits;
}

double? _bounded(Object? value, {required double max}) {
  final number = switch (value) {
    num n => n.toDouble(),
    String s => double.tryParse(s.replaceAll(',', '.')),
    _ => null,
  };
  if (number == null || number.isNaN || number.isInfinite) return null;
  if (number < 0 || number > max) return null;
  return number;
}
