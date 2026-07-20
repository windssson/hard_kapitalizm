import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';

class PriceSparkline extends StatelessWidget {
  final List<double> prices;
  final double height;
  final double width;
  final bool showPointLabels;

  const PriceSparkline({
    super.key,
    required this.prices,
    this.height = 40.0,
    this.width = 120.0,
    this.showPointLabels = true,
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
          showPointLabels: showPointLabels,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> prices;
  final Color strokeColor;
  final bool showPointLabels;

  _SparklinePainter({
    required this.prices,
    required this.strokeColor,
    required this.showPointLabels,
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
    final topInset = showPointLabels ? 14.h : 2.h;
    final bottomInset = 3.h;

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

    canvas.drawLine(Offset(chartLeft, topInset), Offset(size.width, topInset), gridPaint);
    canvas.drawLine(Offset(chartLeft, size.height / 2), Offset(size.width, size.height / 2), gridPaint);
    canvas.drawLine(
      Offset(chartLeft, size.height - bottomInset),
      Offset(size.width, size.height - bottomInset),
      gridPaint,
    );

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

    drawLabel(maxVal, topInset);
    drawLabel((maxVal + minVal) / 2, size.height / 2);
    drawLabel(minVal, size.height - bottomInset);

    final path = Path();
    final areaPath = Path();
    final usableHeight = size.height - topInset - bottomInset;

    for (int i = 0; i < prices.length; i++) {
      final x = chartLeft + i * widthStep;
      final y =
          size.height - bottomInset - ((prices[i] - minVal) / valRange * usableHeight);

      if (i == 0) {
        path.moveTo(x, y);
        areaPath.moveTo(x, size.height - bottomInset);
        areaPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        areaPath.lineTo(x, y);
      }

      if (i == prices.length - 1) {
        areaPath.lineTo(x, size.height - bottomInset);
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
      final y =
          size.height - bottomInset - ((prices[i] - minVal) / valRange * usableHeight);
      canvas.drawCircle(Offset(x, y), 2.0.r, dotPaint);

      if (showPointLabels) {
        final priceText = prices[i].toStringAsFixed(0);
        final pricePainter = TextPainter(
          text: TextSpan(
            text: priceText,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 7.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final minLabelX = chartLeft;
        final maxLabelX = math.max(chartLeft, size.width - pricePainter.width);
        final labelX =
            (x - (pricePainter.width / 2)).clamp(minLabelX, maxLabelX).toDouble();
        final labelY = math.max(0.0, y - pricePainter.height - 4.h).toDouble();

        final labelRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            labelX - 3.w,
            labelY - 1.h,
            pricePainter.width + 6.w,
            pricePainter.height + 2.h,
          ),
          Radius.circular(4.r),
        );

        final labelPaint = Paint()
          ..color = AppColors.background.withValues(alpha: 0.92)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(labelRect, labelPaint);
        pricePainter.paint(canvas, Offset(labelX, labelY));
      }
    }

    // Draw outer pulsing circle on the last point
    final lastX = chartLeft + chartWidth;
    final lastY =
        size.height - bottomInset - ((prices.last - minVal) / valRange * usableHeight);

    final dotOuterPaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(lastX, lastY), 5.0.r, dotOuterPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.prices != prices ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.showPointLabels != showPointLabels;
  }
}
