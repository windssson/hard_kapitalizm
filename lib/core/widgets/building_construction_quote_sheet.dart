import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/models/building_construction_quote_model.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/widgets/required_materials_panel.dart';

Future<bool> showBuildingConstructionQuoteSheet({
  required BuildContext context,
  required String buildingName,
  required IconData icon,
  required BuildingConstructionQuoteModel quote,
}) async {
  final approved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.transparent,
    barrierColor: AppFx.scrim(0.72),
    builder: (sheetContext) => Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.88,
      ),
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 22.h),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
        border: Border(top: BorderSide(color: AppColors.borderGold)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(99.r),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: AppFx.goldWash(0.12),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Icon(icon, color: AppColors.gold),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'İnşaat Onayı',
                        style: AppTextStyles.h2.standardCopyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        buildingName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.standardCopyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            _InfoRow(
              label: 'Nakit maliyeti',
              value: AppMoney.compact(quote.cashCost),
              ok: quote.hasRequiredCash,
            ),
            SizedBox(height: 8.h),
            _InfoRow(
              label: 'Mevcut nakit',
              value: AppMoney.compact(quote.playerCash),
              ok: quote.hasRequiredCash,
            ),
            SizedBox(height: 8.h),
            _InfoRow(
              label: 'İnşaat süresi',
              value: '${quote.durationMinutes} dk',
              ok: true,
            ),
            if (quote.requiredMaterials.isNotEmpty) ...[
              SizedBox(height: 18.h),
              RequiredMaterialsPanel(
                materials: quote.requiredMaterials,
                sourceLabel: _materialSourceLabel(quote.materialSource),
              ),
            ],
            if (!quote.canConstruct) ...[
              SizedBox(height: 12.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(11.w),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: AppColors.red.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  _blockMessage(quote.blockReason),
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            SizedBox(height: 18.h),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: quote.canConstruct
                    ? () => Navigator.of(sheetContext).pop(true)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.textOnAccent,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                ),
                icon: Icon(AppIcons.buildRounded, size: AppIconSizes.regular),
                label: Text(
                  quote.canConstruct
                      ? 'İNŞAATI BAŞLAT'
                      : 'GEREKSİNİMLER EKSİK',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  return approved == true;
}

String _materialSourceLabel(String source) {
  switch (source) {
    case 'same_city_general_warehouse':
      return 'Şehir deposu';
    case 'headquarters_general_warehouse':
      return 'Merkez deposu';
    default:
      return source;
  }
}

String _blockMessage(String? reason) {
  switch (reason) {
    case 'cash':
      return 'İnşaat için yeterli nakit yok.';
    case 'materials':
      return 'Gerekli inşaat malzemeleri depoda eksik.';
    case 'level':
      return 'Oyuncu seviyesi bu bina için yeterli değil.';
    case 'tax_blocked':
      return 'Vergi borcu nedeniyle yeni yatırım yapılamıyor.';
    case 'general_warehouse_required':
      return 'Bu şehirde önce aktif bir Genel Depo bulunmalı.';
    case 'active_construction':
      return 'Başka bir bina inşaatı devam ediyor.';
    default:
      return 'İnşaat şu anda başlatılamıyor.';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, required this.ok});

  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.textPrimary : AppColors.red;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          Text(
            value,
            style: AppTextStyles.body.standardCopyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
