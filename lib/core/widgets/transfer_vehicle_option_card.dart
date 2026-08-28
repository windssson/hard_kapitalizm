import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';

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
  final bool isBestPrice;
  final bool isFastest;
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
    this.isBestPrice = false,
    this.isFastest = false,
    required this.disabledReason,
    this.onTap,
  });

  IconData _getVehicleIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('kamyonet') ||
        lower.contains('ekspres') ||
        lower.contains('kurye') ||
        lower.contains('van')) {
      return Icons.local_shipping_outlined;
    } else if (lower.contains('elektrik') ||
        lower.contains('dağıtım') ||
        lower.contains('dagitim') ||
        lower.contains('voltexpress') ||
        lower.contains('electric')) {
      return Icons.electric_bolt_rounded;
    } else if (lower.contains('tır') ||
        lower.contains('tir') ||
        lower.contains('uzun yol') ||
        lower.contains('trans') ||
        lower.contains('kıtalar')) {
      return Icons.fire_truck_rounded;
    } else if (lower.contains('kamyon') ||
        lower.contains('ağır') ||
        lower.contains('agir') ||
        lower.contains('nakliye') ||
        lower.contains('aslan')) {
      return Icons.local_shipping_rounded;
    }
    return Icons.local_shipping_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = !canSelect
        ? AppColors.danger
        : isSelected
        ? AppColors.gold
        : isRental
        ? AppColors.warning
        : AppColors.success;

    return Opacity(
      opacity: canSelect ? 1.0 : 0.72,
      child: InkWell(
        onTap: canSelect ? onTap : null,
        borderRadius: BorderRadius.circular(16.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.gold.withValues(alpha: 0.12)
                : AppColors.cardBg.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isSelected
                  ? AppColors.gold
                  : !canSelect
                  ? AppColors.red.withValues(alpha: 0.35)
                  : accentColor.withValues(alpha: 0.28),
              width: isSelected ? 2.0 : 1.2,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.25),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── ÜST BAŞLIK: İkon, Araç Adı, Mülkiyet Rozeti ve Fiyat ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Araç İkon Kutusu
                  Container(
                    width: 42.w,
                    height: 42.w,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      _getVehicleIcon(vehicleName),
                      color: accentColor,
                      size: 22.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),

                  // Araç Adı ve Mülkiyet Rozeti
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicleName,
                          style: AppTextStyles.title.standardCopyWith(
                            color: AppColors.textPrimary,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 3.h),
                        Wrap(
                          spacing: 4.w,
                          runSpacing: 3.h,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: (isRental ? AppColors.warning : AppColors.success)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(5.r),
                                border: Border.all(
                                  color: (isRental ? AppColors.warning : AppColors.success)
                                      .withValues(alpha: 0.35),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isRental
                                        ? Icons.handshake_outlined
                                        : Icons.verified_user_rounded,
                                    size: 10.sp,
                                    color: isRental
                                        ? AppColors.warning
                                        : AppColors.success,
                                  ),
                                  SizedBox(width: 3.w),
                                  Text(
                                    isRental ? 'Kiralık' : 'Özmal',
                                    style: TextStyle(
                                      color: isRental
                                          ? AppColors.warning
                                          : AppColors.success,
                                      fontSize: 9.5.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (canSelect && isBestPrice && isFastest) ...[
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 5.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.green.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(5.r),
                                  border: Border.all(
                                    color: AppColors.green.withValues(alpha: 0.45),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 10.sp,
                                      color: AppColors.green,
                                    ),
                                    SizedBox(width: 3.w),
                                    Text(
                                      'EN UCUZ & HIZLI',
                                      style: TextStyle(
                                        color: AppColors.green,
                                        fontSize: 8.5.sp,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              if (canSelect && isBestPrice) ...[
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 5.w,
                                    vertical: 2.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.green.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(5.r),
                                    border: Border.all(
                                      color: AppColors.green.withValues(alpha: 0.45),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.savings_outlined,
                                        size: 10.sp,
                                        color: AppColors.green,
                                      ),
                                      SizedBox(width: 3.w),
                                      Text(
                                        'EN UCUZ',
                                        style: TextStyle(
                                          color: AppColors.green,
                                          fontSize: 8.5.sp,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (canSelect && isFastest) ...[
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 5.w,
                                    vertical: 2.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E5FF).withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(5.r),
                                    border: Border.all(
                                      color: const Color(0xFF00E5FF).withValues(alpha: 0.45),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.bolt_rounded,
                                        size: 10.sp,
                                        color: const Color(0xFF00E5FF),
                                      ),
                                      SizedBox(width: 3.w),
                                      Text(
                                        'EN HIZLI',
                                        style: TextStyle(
                                          color: const Color(0xFF00E5FF),
                                          fontSize: 8.5.sp,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                            if (isSelected) ...[
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 5.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.gold,
                                  borderRadius: BorderRadius.circular(5.r),
                                ),
                                child: Text(
                                  'SEÇİLDİ',
                                  style: TextStyle(
                                    color: AppColors.background,
                                    fontSize: 8.5.sp,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Fiyat Kutusu
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₺ ${AppMoney.full(transportCost, withSymbol: false)}',
                          style: AppTextStyles.metric.standardCopyWith(
                            color: AppColors.gold,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 1.h),
                        Text(
                          'Toplam Nakliye',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),

              // ── ORTA BÖLÜM: 3 Sütunlu Temiz Metrik Çubuğu ──
              Container(
                padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 10.w),
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    // Kapasite
                    Expanded(
                      child: _buildMetricItem(
                        icon: Icons.inventory_2_outlined,
                        iconColor: AppColors.gold,
                        label: 'Kapasite',
                        value: '$capacity birim',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 24.h,
                      color: AppColors.border.withValues(alpha: 0.3),
                    ),
                    // Tahmini Süre
                    Expanded(
                      child: _buildMetricItem(
                        icon: Icons.schedule_rounded,
                        iconColor: AppColors.blue,
                        label: 'Tahmini Süre',
                        value: durationLabel,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 24.h,
                      color: AppColors.border.withValues(alpha: 0.3),
                    ),
                    // Hız ve Mesafe
                    Expanded(
                      child: _buildMetricItem(
                        icon: Icons.speed_rounded,
                        iconColor: AppColors.success,
                        label: 'Hız / Yol',
                        value: '$speedKmh km/s • ${distanceKm.toStringAsFixed(0)} km',
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),

              // ── ALT BİLGİ: Maliyet Kırılımı ──
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: isRental
                    ? Row(
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 13.sp,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'Kira Oranı: ${(rentalCost / (distanceKm > 0 ? distanceKm : 1)).toStringAsFixed(1)} TL/km',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Yakıt masrafı dahil',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Icon(
                            Icons.local_gas_station_rounded,
                            size: 13.sp,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'Yakıt: ${fuelNeeded.toStringAsFixed(1)} L (₺${fuelCost.toStringAsFixed(0)})',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.build_circle_outlined,
                            size: 13.sp,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'Aşınma: -%${conditionNeeded.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),

              // ── ENGEL / UYARI BİLGİSİ ──
              if (!canSelect && disabledReason != null) ...[
                SizedBox(height: 8.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.danger,
                        size: 15.sp,
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          disabledReason!,
                          style: TextStyle(
                            color: AppColors.danger,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12.sp, color: iconColor),
            SizedBox(width: 4.w),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 11.sp,
            fontWeight: FontWeight.w800,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
