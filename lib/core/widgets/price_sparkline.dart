import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';

class PriceSparkline extends StatelessWidget {
  final List<double> prices;
  final double height;
  final double width;

  const PriceSparkline({
    super.key,
    required this.prices,
    this.height = 40.0,
    this.width = 120.0,
  });

  @override
  Widget build(BuildContext context) {
    if (prices.isEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: AppLoadingIndicator(strokeWidth: 1.5, color: AppColors.gold),
          ),
        ),
      );
    }

    final isUp = prices.last >= prices.first;
    final strokeColor = isUp ? AppColors.green : AppColors.red;

    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: CustomPaint(
        painter: _SparklinePainter(
          prices: prices,
          strokeColor: strokeColor,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> prices;
  final Color strokeColor;

  _SparklinePainter({
    required this.prices,
    required this.strokeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.length < 2) return;

    double maxVal = prices.reduce((a, b) => a > b ? a : b);
    double minVal = prices.reduce((a, b) => a < b ? a : b);

    final padding = (maxVal - minVal) * 0.15;
    if (padding == 0) {
      maxVal += 1.0;
      minVal -= 1.0;
    } else {
      maxVal += padding;
      minVal -= padding;
    }

    final valRange = maxVal - minVal;
    final widthStep = size.width / (prices.length - 1);

    final path = Path();
    final areaPath = Path();

    for (int i = 0; i < prices.length; i++) {
      final x = i * widthStep;
      final y = size.height - ((prices[i] - minVal) / valRange * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        areaPath.moveTo(x, size.height);
        areaPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        areaPath.lineTo(x, y);
      }

      if (i == prices.length - 1) {
        areaPath.lineTo(x, size.height);
        areaPath.close();
      }
    }

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [strokeColor.withValues(alpha: 0.25), strokeColor.withValues(alpha: 0.0)],
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(areaPath, fillPaint);

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0.r
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);
    
    final lastX = size.width;
    final lastY = size.height - ((prices.last - minVal) / valRange * size.height);
    
    final dotPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(lastX, lastY), 3.0.r, dotPaint);

    final dotOuterPaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(lastX, lastY), 6.0.r, dotOuterPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.prices != prices || oldDelegate.strokeColor != strokeColor;
  }
}
