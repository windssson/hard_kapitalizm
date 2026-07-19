import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_haptic.dart';

class NumericKeyboard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onDone;
  final ValueChanged<String>? onChanged;
  final bool allowDecimal;
  final List<NumericKeyboardShortcut> shortcuts;
  final double? height;
  final double? buttonHeight;

  const NumericKeyboard({
    super.key,
    required this.controller,
    this.onDone,
    this.onChanged,
    this.allowDecimal = false,
    this.shortcuts = const [],
    this.height,
    this.buttonHeight,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedButtonHeight = buttonHeight ?? 52.h;
    final rows = <List<_NumericKey>>[
      [
        _NumericKey('1', () => _onNumberPressed('1'), AppColors.gold),
        _NumericKey('2', () => _onNumberPressed('2'), AppColors.gold),
        _NumericKey('3', () => _onNumberPressed('3'), AppColors.gold),
      ],
      [
        _NumericKey('4', () => _onNumberPressed('4'), AppColors.gold),
        _NumericKey('5', () => _onNumberPressed('5'), AppColors.gold),
        _NumericKey('6', () => _onNumberPressed('6'), AppColors.gold),
      ],
      [
        _NumericKey('7', () => _onNumberPressed('7'), AppColors.gold),
        _NumericKey('8', () => _onNumberPressed('8'), AppColors.gold),
        _NumericKey('9', () => _onNumberPressed('9'), AppColors.gold),
      ],
      [
        allowDecimal
            ? _NumericKey(',', () => _onNumberPressed(','), AppColors.goldLight)
            : _NumericKey('C', _onClear, AppColors.goldLight),
        _NumericKey('0', () => _onNumberPressed('0'), AppColors.gold),
        _NumericKey('Sil', _onBackspace, AppColors.red, isIcon: true),
      ],
    ];

    return Container(
      padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 12.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.cardBg,
            AppColors.background,
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        border: Border(
          top: BorderSide(
            color: AppColors.gold,
            width: 2.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppFx.shadow(0.65),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (shortcuts.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0; index < shortcuts.length; index++) ...[
                    _buildShortcutChip(shortcuts[index]),
                    if (index < shortcuts.length - 1) SizedBox(width: 6.w),
                  ],
                ],
              ),
            ),
            SizedBox(height: 10.h),
          ],
          for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
            Row(
              children: [
                for (var i = 0; i < rows[rowIndex].length; i++) ...[
                  Expanded(
                    child: _buildButton(
                      label: rows[rowIndex][i].label,
                      onPressed: rows[rowIndex][i].onPressed,
                      color: rows[rowIndex][i].color,
                      isIcon: rows[rowIndex][i].isIcon,
                      height: resolvedButtonHeight,
                    ),
                  ),
                  if (i < rows[rowIndex].length - 1) SizedBox(width: 4.w),
                ],
              ],
            ),
            if (rowIndex < rows.length - 1) SizedBox(height: 4.h),
          ],
        ],
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required VoidCallback onPressed,
    required Color color,
    bool isIcon = false,
    required double height,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.18),
              color.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: color.withValues(alpha: 0.45),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppFx.shadow(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: isIcon
              ? Icon(
                  AppIcons.backspaceOutlined,
                  size: AppIconSizes.regular,
                  color: color,
                )
              : Text(
                  label,
                  style: AppTextStyles.title.standardCopyWith(
                    color: color,
                    fontSize: AppTypography.titleLarge,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildShortcutChip(NumericKeyboardShortcut shortcut) {
    return GestureDetector(
      onTap: () => _applyShortcut(shortcut.value),
      child: Container(
        constraints: BoxConstraints(minHeight: 32.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.gold.withValues(alpha: 0.15),
              AppColors.gold.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppFx.shadow(0.15),
              blurRadius: 3,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Center(
          child: Text(
            shortcut.label,
            style: AppTextStyles.label.standardCopyWith(
              color: AppColors.gold,
              fontSize: AppTypography.bodySmall,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  void _onNumberPressed(String value) {
    AppHaptic.selection();
    final currentText = controller.text;

    if (value == ',') {
      if (!allowDecimal) return;
      if (currentText.contains(',')) return;
      controller.text = currentText.isEmpty ? '0,' : '$currentText,';
    } else {
      if (currentText == '0' && value != '0') {
        controller.text = value;
      } else if (currentText.isEmpty && value == '0') {
        controller.text = '0';
      } else {
        controller.text = currentText + value;
      }
    }

    _moveCursorToEnd();
    onChanged?.call(controller.text);
  }

  void _onBackspace() {
    AppHaptic.selection();
    final currentText = controller.text;
    if (currentText.isEmpty) return;

    controller.text = currentText.substring(0, currentText.length - 1);
    _moveCursorToEnd();
    onChanged?.call(controller.text);
  }

  void _onClear() {
    AppHaptic.selection();
    controller.clear();
    onChanged?.call(controller.text);
  }

  void _applyShortcut(String value) {
    AppHaptic.selection();
    controller.text = value;
    _moveCursorToEnd();
    onChanged?.call(controller.text);
  }

  void _moveCursorToEnd() {
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
  }
}

class NumericKeyboardShortcut {
  final String label;
  final String value;

  const NumericKeyboardShortcut({
    required this.label,
    required this.value,
  });
}

class _NumericKey {
  final String label;
  final VoidCallback onPressed;
  final Color color;
  final bool isIcon;

  const _NumericKey(
    this.label,
    this.onPressed,
    this.color, {
    this.isIcon = false,
  });
}
