import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';

/// Numeric keyboard widget with digits 0-9 and comma separator
class NumericKeyboard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onDone;
  final double? height;
  final double? buttonHeight;

  const NumericKeyboard({
    super.key,
    required this.controller,
    this.onDone,
    this.height,
    this.buttonHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
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
          // Keyboard grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            childAspectRatio: 1.2,
            crossAxisSpacing: 4.w,
            mainAxisSpacing: 4.h,
              children: [
                // Numbers 1-9
                ...[1, 2, 3, 4, 5, 6, 7, 8, 9].map(
                  (number) => _buildButton(
                    label: number.toString(),
                    onPressed: () => _onNumberPressed(number.toString()),
                    color: AppColors.gold,
                  ),
                ),
                // Comma button (bottom-left)
                _buildButton(
                  label: ',',
                  onPressed: () => _onNumberPressed(','),
                  color: AppColors.goldLight,
                ),
                // Zero button (bottom-center)
                _buildButton(
                  label: '0',
                  onPressed: () => _onNumberPressed('0'),
                  color: AppColors.gold,
                ),
                // Backspace button (bottom-right)
                _buildButton(
                  label: '⌫',
                  onPressed: _onBackspace,
                  color: AppColors.red,
                  isIcon: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required VoidCallback onPressed,
    required Color color,
    bool isIcon = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: isIcon ? 14.sp : 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _onNumberPressed(String value) {
    final currentText = controller.text;

    // Comma validation - only one comma allowed
    if (value == ',') {
      if (currentText.contains(',')) return;
      if (currentText.isEmpty) {
        controller.text = '0,';
      } else {
        controller.text = currentText + value;
      }
    } else {
      // Number input
      if (currentText == '0' && value != '0') {
        controller.text = value;
      } else if (currentText.isEmpty && value == '0') {
        controller.text = '0';
      } else {
        controller.text = currentText + value;
      }
    }

    // Move cursor to end
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
  }

  void _onBackspace() {
    final currentText = controller.text;
    if (currentText.isNotEmpty) {
      controller.text = currentText.substring(0, currentText.length - 1);
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
    }
  }
}
