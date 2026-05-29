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
      height: height ?? 280.h,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        border: Border(
          top: BorderSide(
            color: AppColors.gold.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Display field with current value
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            margin: EdgeInsets.only(bottom: 12.h),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                return Text(
                  value.text.isEmpty ? '0' : value.text,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                );
              },
            ),
          ),
          // Keyboard grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              childAspectRatio: 1.0,
              crossAxisSpacing: 6.w,
              mainAxisSpacing: 6.h,
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
          // Action buttons
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    controller.clear();
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.red.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      'Temizle',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.red,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    onDone?.call();
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      'Tamam',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: color.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: isIcon ? 18.sp : 20.sp,
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
