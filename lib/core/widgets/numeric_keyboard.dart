import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';

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
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
        border: Border(
          top: BorderSide(
            color: AppColors.gold.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (shortcuts.isNotEmpty) ...[
            SizedBox(
              height: 34.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final shortcut = shortcuts[index];
                  return GestureDetector(
                    onTap: () => _applyShortcut(shortcut.value),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999.r),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          shortcut.label,
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  );
                },
                separatorBuilder: (_, __) => SizedBox(width: 6.w),
                itemCount: shortcuts.length,
              ),
            ),
            SizedBox(height: 8.h),
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
                  if (i < rows[rowIndex].length - 1) SizedBox(width: 3.w),
                ],
              ],
            ),
            if (rowIndex < rows.length - 1) SizedBox(height: 3.h),
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
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: isIcon ? 12.sp : 14.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _onNumberPressed(String value) {
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
    final currentText = controller.text;
    if (currentText.isEmpty) return;

    controller.text = currentText.substring(0, currentText.length - 1);
    _moveCursorToEnd();
    onChanged?.call(controller.text);
  }

  void _onClear() {
    controller.clear();
    onChanged?.call(controller.text);
  }

  void _applyShortcut(String value) {
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
