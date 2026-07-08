import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';

class TransferVehicleOptionCard extends StatelessWidget {
  final String vehicleName;
  final bool isRental;
  final int capacity;
  final int speedKmh;
  final double distanceKm;
  final String durationLabel;
  final double transportCost;
  final double rentalCost;
  final double fuelCost;
  final double fuelNeeded;
  final double conditionNeeded;
  final bool canSelect;
  final bool isSelected;
  final String? disabledReason;
  final VoidCallback? onTap;

  const TransferVehicleOptionCard({
    super.key,
    required this.vehicleName,
    required this.isRental,
    required this.capacity,
    required this.speedKmh,
    required this.distanceKm,
    required this.durationLabel,
    required this.transportCost,
    required this.rentalCost,
    required this.fuelCost,
    required this.fuelNeeded,
    required this.conditionNeeded,
    required this.canSelect,
    required this.isSelected,
    required this.disabledReason,
    this.onTap,
  });

  IconData _getVehicleIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('kurye')) {
      return Icons.delivery_dining_rounded;
    } else if (lower.contains('voltexpress') || lower.contains('electric') || lower.contains('elektrik')) {
      return Icons.electric_car_rounded;
    } else if (lower.contains('aslan')) {
      return Icons.local_shipping_rounded;
    } else if (lower.contains('trans') || lower.contains('tır') || lower.contains('kıtalar')) {
      return Icons.speed_rounded;
    }
    return Icons.local_shipping_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = !canSelect
        ? AppColors.red
        : isSelected
        ? AppColors.gold
        : isRental
        ? Colors.orange
        : AppColors.green;

    return InkWell(
      onTap: canSelect ? onTap : null,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: AppDecorations.premiumCard(accentColor, 16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38.w,
                  height: 38.w,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(
                    _getVehicleIcon(vehicleName),
                    color: accentColor,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicleName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                        child: Text(
                          isRental ? 'Kiralik' : 'Ozmal',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Nakliye',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${transportCost.toStringAsFixed(0)} TL',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                _buildStatChip('Kapasite', '$capacity'),
                _buildStatChip('Hız', '$speedKmh km/h'),
                _buildStatChip('Mesafe', '${distanceKm.toStringAsFixed(0)} km'),
                _buildStatChip('Süre', durationLabel),
                if (isRental) ...[
                  _buildStatChip(
                    'Kira Oranı',
                    '${(rentalCost / (distanceKm > 0 ? distanceKm : 1)).toStringAsFixed(1)} TL/km',
                  ),
                ] else ...[
                  _buildStatChip('Yakıt', '${fuelNeeded.toStringAsFixed(1)} L'),
                  _buildStatChip('Yıpranma', '-%${conditionNeeded.toStringAsFixed(0)}'),
                ],
              ],
            ),
            if (!canSelect && disabledReason != null) ...[
              SizedBox(height: 8.h),
              Text(
                disabledReason!,
                style: TextStyle(
                  color: AppColors.red,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
