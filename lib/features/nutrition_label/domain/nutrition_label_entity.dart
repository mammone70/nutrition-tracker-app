import 'package:equatable/equatable.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

/// How the numbers on a nutrition facts panel are stated.
///
/// Labels usually print **per serving**; some (EU-style panels, supplements)
/// print **per 100 g / 100 ml**. The app stores nutrients per 100 g/ml, so a
/// per-serving reading is scaled using [NutritionLabelEntity.servingQuantity]
/// before it becomes a [MealEntity].
enum NutritionLabelBasis { perServing, per100 }

/// Numbers read from a photographed nutrition facts panel.
///
/// This is **transcription**, not estimation: the values are what the panel
/// printed. The meal-assist rule that a model may not invent nutrition does
/// not apply here — the user reviews every field on the custom-meal form
/// before anything is saved or logged.
class NutritionLabelEntity extends Equatable {
  final String? name;
  final String? brands;
  final String? barcode;

  /// Serving size in grams or millilitres, when the panel states one.
  final double? servingQuantity;

  /// `g` or `ml`. Defaults to grams when the panel does not say.
  final String servingUnit;

  final NutritionLabelBasis basis;

  final double? energyKcal;
  final double? carbohydratesG;
  final double? fatG;
  final double? proteinsG;
  final double? fiberG;
  final double? sugarsG;
  final double? saturatedFatG;

  /// Milligrams on the panel (US labels often print sodium in mg).
  final double? sodiumMg;
  final double? calciumMg;
  final double? ironMg;
  final double? potassiumMg;
  final double? magnesiumMg;

  /// Micrograms.
  final double? vitaminDUg;
  final double? vitaminB12Ug;

  const NutritionLabelEntity({
    this.name,
    this.brands,
    this.barcode,
    this.servingQuantity,
    this.servingUnit = 'g',
    required this.basis,
    this.energyKcal,
    this.carbohydratesG,
    this.fatG,
    this.proteinsG,
    this.fiberG,
    this.sugarsG,
    this.saturatedFatG,
    this.sodiumMg,
    this.calciumMg,
    this.ironMg,
    this.potassiumMg,
    this.magnesiumMg,
    this.vitaminDUg,
    this.vitaminB12Ug,
  });

  /// True when at least energy or one macro was read — enough to open the
  /// custom-meal form with something useful to review.
  bool get hasUsableNutrition =>
      energyKcal != null ||
      carbohydratesG != null ||
      fatG != null ||
      proteinsG != null;

  /// Converts panel numbers into the app's per-100 g/ml [MealEntity] shape.
  ///
  /// Per-serving values are scaled by `100 / servingQuantity`. When the
  /// serving size is missing, per-serving numbers are stored as-is under the
  /// same Simple-mode convention the custom-meal form already uses (treat the
  /// typed serving totals as the stored `*100` fields with a 100 g base).
  MealEntity toMealEntity({String? barcodeOverride}) {
    final unit = servingUnit == 'ml' ? 'ml' : 'g';
    final factor = _factorToPer100();

    double? scale(double? value) => value == null ? null : value * factor;

    final nutriments = MealNutrimentsEntity(
      energyKcal100: scale(energyKcal),
      carbohydrates100: scale(carbohydratesG),
      fat100: scale(fatG),
      proteins100: scale(proteinsG),
      fiber100: scale(fiberG),
      sugars100: scale(sugarsG),
      saturatedFat100: scale(saturatedFatG),
      sodium100: scale(sodiumMg),
      calcium100: scale(calciumMg),
      iron100: scale(ironMg),
      potassium100: scale(potassiumMg),
      magnesium100: scale(magnesiumMg),
      vitaminD100: scale(vitaminDUg),
      vitaminB12100: scale(vitaminB12Ug),
    );

    final code = barcodeOverride ?? barcode;
    final serving = servingQuantity;

    return MealEntity(
      code: (code != null && code.isNotEmpty)
          ? code
          : IdGenerator.getUniqueID(),
      name: name,
      brands: brands,
      url: null,
      mealQuantity: serving?.toString(),
      mealUnit: unit,
      servingQuantity: serving,
      servingUnit: unit,
      servingSize: serving == null ? '' : '${_trimNumber(serving)} $unit',
      nutriments: nutriments,
      source: MealSourceEntity.custom,
      detailed: true,
    );
  }

  double _factorToPer100() {
    if (basis == NutritionLabelBasis.per100) return 1;
    final serving = servingQuantity;
    if (serving == null || serving <= 0) return 1;
    return 100 / serving;
  }

  static String _trimNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }

  @override
  List<Object?> get props => [
    name,
    brands,
    barcode,
    servingQuantity,
    servingUnit,
    basis,
    energyKcal,
    carbohydratesG,
    fatG,
    proteinsG,
    fiberG,
    sugarsG,
    saturatedFatG,
    sodiumMg,
    calciumMg,
    ironMg,
    potassiumMg,
    magnesiumMg,
    vitaminDUg,
    vitaminB12Ug,
  ];
}
