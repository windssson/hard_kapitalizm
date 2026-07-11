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

    return SizedBox(
      width: width,
      height: height,
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

    // Layout configuration
    final labelWidth = 26.w;
    final chartLeft = labelWidth;
    final chartWidth = size.width - chartLeft;
    final widthStep = chartWidth / (prices.length - 1);

    // Draw horizontal grid lines
    final gridPaint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0.r;

    canvas.drawLine(Offset(chartLeft, 2.h), Offset(size.width, 2.h), gridPaint);
    canvas.drawLine(Offset(chartLeft, size.height / 2), Offset(size.width, size.height / 2), gridPaint);
    canvas.drawLine(Offset(chartLeft, size.height - 2.h), Offset(size.width, size.height - 2.h), gridPaint);

    // Draw Y-axis labels
    final textStyle = TextStyle(
      color: AppColors.textMuted,
      fontSize: 8.sp,
      fontWeight: FontWeight.w600,
    );

    void drawLabel(double val, double yOffset) {
      final tp = TextPainter(
        text: TextSpan(text: val.toStringAsFixed(0), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, yOffset - tp.height / 2));
    }

    drawLabel(maxVal, 2.h);
    drawLabel((maxVal + minVal) / 2, size.height / 2);
    drawLabel(minVal, size.height - 2.h);

    final path = Path();
    final areaPath = Path();

    for (int i = 0; i < prices.length; i++) {
      final x = chartLeft + i * widthStep;
      final y = size.height - 2.h - ((prices[i] - minVal) / valRange * (size.height - 4.h));

      if (i == 0) {
        path.moveTo(x, y);
        areaPath.moveTo(x, size.height - 2.h);
        areaPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        areaPath.lineTo(x, y);
      }

      if (i == prices.length - 1) {
        areaPath.lineTo(x, size.height - 2.h);
        areaPath.close();
      }
    }

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [strokeColor.withValues(alpha: 0.20), strokeColor.withValues(alpha: 0.0)],
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(areaPath, fillPaint);

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8.r
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    // Draw dots at each point
    final dotPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < prices.length; i++) {
      final x = chartLeft + i * widthStep;
      final y = size.height - 2.h - ((prices[i] - minVal) / valRange * (size.height - 4.h));
      canvas.drawCircle(Offset(x, y), 2.0.r, dotPaint);
    }

    // Draw outer pulsing circle on the last point
    final lastX = chartLeft + chartWidth;
    final lastY = size.height - 2.h - ((prices.last - minVal) / valRange * (size.height - 4.h));

    final dotOuterPaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(lastX, lastY), 5.0.r, dotOuterPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.prices != prices || oldDelegate.strokeColor != strokeColor;
  }
}
