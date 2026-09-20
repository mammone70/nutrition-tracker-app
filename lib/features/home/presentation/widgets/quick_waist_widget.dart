import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opennutritracker/core/domain/entity/waist_log_entity.dart';
import 'package:opennutritracker/core/domain/usecase/waist_log_usecase.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Quick waist circumference chip on the home screen (inches).
class QuickWaistWidget extends StatelessWidget {
  final double? waistInches;
  final double? avg7dInches;

  const QuickWaistWidget({super.key, this.waistInches, this.avg7dInches});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final display = waistInches == null
        ? '— ${s.inchesLabel}'
        : '${_formatInches(waistInches!)} ${s.inchesLabel}';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      identifier: 'home-waist-chip',
      child: Material(
        color: Colors.transparent,
        borderRadius: Dimens.borderRadiusM,
        child: InkWell(
          borderRadius: Dimens.borderRadiusM,
          onTap: () => _showWaistDialog(context),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimens.spacing12,
              vertical: Dimens.spacing8,
            ),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: Dimens.borderRadiusM,
              border: Border.all(color: palette.border, width: Dimens.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.straighten_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: Dimens.spacing8),
                    Text(
                      '${s.waistLabel} $display',
                      style: textTheme.labelLarge?.copyWith(
                        color: palette.textStrong,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: Dimens.spacing4),
                    Icon(
                      Icons.edit_rounded,
                      size: 15,
                      color: palette.textMuted,
                    ),
                  ],
                ),
                if (avg7dInches != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${s.sevenDayAvgLabel}: ${_formatInches(avg7dInches!)} ${s.inchesLabel}',
                    style: textTheme.labelSmall?.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatInches(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  Future<void> _showWaistDialog(BuildContext context) async {
    final controller = TextEditingController(
      text: waistInches == null ? '' : _formatInches(waistInches!),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(S.of(context).waistLabel),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: S.of(context).inchesLabel,
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(S.of(context).dialogCancelLabel),
            ),
            FilledButton(
              onPressed: () {
                final raw = controller.text.replaceAll(',', '.');
                final value = double.tryParse(raw);
                if (value == null || value <= 0) return;
                Navigator.of(context).pop(value);
              },
              child: Text(S.of(context).dialogOKLabel),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null || !context.mounted) return;

    final now = DateTime.now();
    await locator<AddWaistLogUsecase>().addEntry(
      WaistLogEntity(
        date: DateTime(now.year, now.month, now.day),
        inches: result,
      ),
    );
    locator<HomeBloc>().add(const LoadItemsEvent());
  }
}
