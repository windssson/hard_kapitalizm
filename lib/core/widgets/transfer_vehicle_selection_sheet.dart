import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/models/production_logistics_models.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_haptic.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/widgets/transfer_vehicle_option_card.dart';
import 'package:hard_kapitalizm/features/market/models/market_transfer_vehicle_option_model.dart';
import 'package:hard_kapitalizm/features/tender/models/tender_detail_model.dart';

/// Tüm ekranlar için birleştirilmiş Transfer Aracı Seçenek Modeli
class TransferVehicleOptionItem {
  final String vehicleId;
  final String vehicleName;
  final bool isRental;
  final int capacity;
  final int speedKmh;
  final double distanceKm;
  final int estimatedDurationSeconds;
  final String durationLabel;
  final double transportCost;
  final double rentalCost;
  final double fuelCost;
  final double fuelNeeded;
  final double conditionNeeded;
  final bool canSelect;
  final String? disabledReason;

  const TransferVehicleOptionItem({
    required this.vehicleId,
    required this.vehicleName,
    required this.isRental,
    required this.capacity,
    required this.speedKmh,
    required this.distanceKm,
    required this.estimatedDurationSeconds,
    required this.durationLabel,
    required this.transportCost,
    required this.rentalCost,
    required this.fuelCost,
    required this.fuelNeeded,
    required this.conditionNeeded,
    required this.canSelect,
    this.disabledReason,
  });

  static String formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return 'Hemen';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0 && minutes > 0) return '$hours sa $minutes dk';
    if (hours > 0) return '$hours sa';
    return '$minutes dk';
  }

  factory TransferVehicleOptionItem.fromMarket(
    MarketTransferVehicleOptionModel model,
  ) {
    return TransferVehicleOptionItem(
      vehicleId: model.vehicleId,
      vehicleName: model.vehicleName,
      isRental: model.isRental,
      capacity: model.capacity,
      speedKmh: model.speedKmh,
      distanceKm: model.distanceKm,
      estimatedDurationSeconds: model.estimatedDurationSeconds,
      durationLabel: formatDuration(model.estimatedDurationSeconds),
      transportCost: model.transportCost,
      rentalCost: model.rentalCost,
      fuelCost: model.fuelCost,
      fuelNeeded: model.fuelNeeded,
      conditionNeeded: model.conditionNeeded,
      canSelect: model.canSelect,
      disabledReason: model.disabledReason,
    );
  }

  factory TransferVehicleOptionItem.fromProduction(
    ProductionLogisticsVehicleOption model,
  ) {
    return TransferVehicleOptionItem(
      vehicleId: model.vehicleId,
      vehicleName: model.vehicleName,
      isRental: model.isRental,
      capacity: model.capacity,
      speedKmh: model.speedKmh,
      distanceKm: model.distanceKm,
      estimatedDurationSeconds: model.estimatedDurationSeconds,
      durationLabel: formatDuration(model.estimatedDurationSeconds),
      transportCost: model.totalPrice,
      rentalCost: model.rentalCost,
      fuelCost: model.fuelCost,
      fuelNeeded: model.fuelNeeded,
      conditionNeeded: model.conditionNeeded,
      canSelect: model.canSelect,
      disabledReason: model.disabledReason,
    );
  }

  factory TransferVehicleOptionItem.fromTender(
    TenderVehicleOptionModel model,
  ) {
    return TransferVehicleOptionItem(
      vehicleId: model.vehicleId,
      vehicleName: model.vehicleName,
      isRental: model.isRental,
      capacity: model.capacity,
      speedKmh: model.speedKmh,
      distanceKm: model.distanceKm,
      estimatedDurationSeconds: model.estimatedDurationSeconds,
      durationLabel: formatDuration(model.estimatedDurationSeconds),
      transportCost: model.transportCost,
      rentalCost: model.rentalCost,
      fuelCost: model.fuelCost,
      fuelNeeded: model.fuelNeeded,
      conditionNeeded: model.conditionNeeded,
      canSelect: model.canSelect,
      disabledReason: model.disabledReason,
    );
  }
}

/// Merkezi Transfer Aracı Seçim Penceresini Açar
Future<String?> showTransferVehicleSelectionSheet({
  required BuildContext context,
  required String sourceCityName,
  required String targetCityName,
  required List<TransferVehicleOptionItem> options,
  double? totalVolume,
  String? volumeLabel,
  String? unavailableReason,
  String title = 'Transfer Aracı Seçin',
  String? selectedVehicleId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.background,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      side: BorderSide(
        color: AppColors.borderGold.withValues(alpha: 0.3),
        width: 1.2,
      ),
    ),
    builder: (sheetContext) => TransferVehicleSelectionSheet(
      sourceCityName: sourceCityName,
      targetCityName: targetCityName,
      options: options,
      totalVolume: totalVolume,
      volumeLabel: volumeLabel,
      unavailableReason: unavailableReason,
      title: title,
      selectedVehicleId: selectedVehicleId,
    ),
  );
}

/// Merkezi Transfer Aracı Seçim Widget'ı
class TransferVehicleSelectionSheet extends StatefulWidget {
  final String sourceCityName;
  final String targetCityName;
  final List<TransferVehicleOptionItem> options;
  final double? totalVolume;
  final String? volumeLabel;
  final String? unavailableReason;
  final String title;
  final String? selectedVehicleId;

  const TransferVehicleSelectionSheet({
    super.key,
    required this.sourceCityName,
    required this.targetCityName,
    required this.options,
    this.totalVolume,
    this.volumeLabel,
    this.unavailableReason,
    this.title = 'Transfer Aracı Seçin',
    this.selectedVehicleId,
  });

  @override
  State<TransferVehicleSelectionSheet> createState() =>
      _TransferVehicleSelectionSheetState();
}

class _TransferVehicleSelectionSheetState
    extends State<TransferVehicleSelectionSheet> {
  @override
  Widget build(BuildContext context) {
    // En fazla 8 araç listele (karışık)
    final displayOptions = widget.options.take(8).toList();

    // En ucuz ve en hızlı araçları belirle (yalnızca seçilebilirler arasından)
    String? cheapestVehicleId;
    String? fastestVehicleId;
    double minPrice = double.infinity;
    int minDuration = 0x7FFFFFFF;

    for (final option in displayOptions) {
      if (option.canSelect) {
        final price = option.transportCost > 0
            ? option.transportCost
            : (option.rentalCost + option.fuelCost);
        if (price < minPrice) {
          minPrice = price;
          cheapestVehicleId = option.vehicleId;
        }
        if (option.estimatedDurationSeconds > 0 &&
            option.estimatedDurationSeconds < minDuration) {
          minDuration = option.estimatedDurationSeconds;
          fastestVehicleId = option.vehicleId;
        }
      }
    }

    final formattedVolume = widget.volumeLabel ??
        (widget.totalVolume != null
            ? '${AppMoney.full(widget.totalVolume!, withSymbol: false)} m³'
            : null);

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── TUTAMAÇ (DRAG HANDLE) ──
          Center(
            child: Container(
              width: 44.w,
              height: 4.5.h,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(3.r),
              ),
            ),
          ),
          SizedBox(height: 12.h),

          // ── BAŞLIK & KAPAT BUTONU ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(7.w),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      Icons.local_shipping_rounded,
                      color: AppColors.gold,
                      size: 18.sp,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    widget.title,
                    style: AppTextStyles.h1.standardCopyWith(
                      color: AppColors.textPrimary,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close_rounded,
                  color: AppColors.textMuted,
                  size: 20.sp,
                ),
                splashRadius: 18.r,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          SizedBox(height: 10.h),

          // ── ROTA & HACİM BİLGİ KUTUSU ──
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.cardBgLight.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.near_me_rounded,
                  size: 14.sp,
                  color: AppColors.gold,
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: AppTextStyles.body.standardCopyWith(
                        fontSize: 12.sp,
                      ),
                      children: [
                        TextSpan(
                          text: widget.sourceCityName,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: ' ➔ ',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(
                          text: widget.targetCityName,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (formattedVolume != null) ...[
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 11.sp,
                          color: AppColors.gold,
                        ),
                        SizedBox(width: 4.w),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 100.w),
                          child: Text(
                            formattedVolume,
                            style: TextStyle(
                              color: AppColors.goldLight,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 8.h),

          // ── FİYAT SIRALAMASI BİLGİ ROZETİ ──
          Row(
            children: [
              Icon(
                Icons.swap_vert_rounded,
                size: 13.sp,
                color: AppColors.textMuted,
              ),
              SizedBox(width: 4.w),
              Text(
                'Fiyata göre sıralandı (En fazla 8 araç)',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight,
                  borderRadius: BorderRadius.circular(6.r),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '${displayOptions.length} Araç',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          // ── UYARI BANNERI ──
          if (widget.unavailableReason != null) ...[
            SizedBox(height: 8.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: AppColors.red.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.red,
                    size: 16.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      widget.unavailableReason!,
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.red,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 12.h),

          // ── ARAÇ LİSTESİ ──
          Expanded(
            child: displayOptions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_shipping_outlined,
                          size: 42.sp,
                          color: AppColors.textMuted.withValues(alpha: 0.4),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Uygun araç bulunamadı.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13.sp,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: displayOptions.length,
                    separatorBuilder: (_, _) => SizedBox(height: 10.h),
                    itemBuilder: (context, index) {
                      final option = displayOptions[index];
                      final isSelected =
                          option.vehicleId == widget.selectedVehicleId;
                      final isCheapest = option.vehicleId == cheapestVehicleId;
                      final isFastest = option.vehicleId == fastestVehicleId;

                      return TransferVehicleOptionCard(
                        vehicleName: option.vehicleName,
                        isRental: option.isRental,
                        capacity: option.capacity,
                        speedKmh: option.speedKmh,
                        distanceKm: option.distanceKm,
                        durationLabel: option.durationLabel,
                        transportCost: option.transportCost,
                        rentalCost: option.rentalCost,
                        fuelCost: option.fuelCost,
                        fuelNeeded: option.fuelNeeded,
                        conditionNeeded: option.conditionNeeded,
                        canSelect: option.canSelect,
                        isSelected: isSelected,
                        isBestPrice: isCheapest,
                        isFastest: isFastest,
                        disabledReason: option.disabledReason,
                        onTap: () {
                          AppHaptic.selection();
                          Navigator.of(context).pop(option.vehicleId);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
