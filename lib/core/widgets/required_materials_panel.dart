import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/models/required_material_model.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';

class RequiredMaterialsPanel extends StatelessWidget {
  const RequiredMaterialsPanel({
    super.key,
    required this.materials,
    this.title = 'GEREKLİ MALZEMELER',
    this.sourceLabel,
  });

  final List<RequiredMaterialModel> materials;
  final String title;
  final String? sourceLabel;

  @override
  Widget build(BuildContext context) {
    if (materials.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.overline.standardCopyWith(
                  color: AppColors.gold,
                ),
              ),
            ),
            if (sourceLabel != null && sourceLabel!.isNotEmpty)
              Text(
                sourceLabel!,
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
        SizedBox(height: 8.h),
        ...materials.map(
          (material) => Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: _MaterialRow(material: material),
          ),
        ),
      ],
    );
  }
}

class _MaterialRow extends StatelessWidget {
  const _MaterialRow({required this.material});

  final RequiredMaterialModel material;

  @override
  Widget build(BuildContext context) {
    final accent = material.hasEnough ? AppColors.green : AppColors.red;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            padding: EdgeInsets.all(5.w),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(9.r),
            ),
            child: material.productIcon.isEmpty
                ? Icon(AppIcons.inventory2Outlined, color: accent)
                : CachedAssetImage(
                    fileName: material.productIcon,
                    fit: BoxFit.contain,
                  ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  material.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  material.hasEnough
                      ? 'Depoda yeterli'
                      : '${_format(material.missingQuantity)} adet eksik',
                  style: AppTextStyles.caption.standardCopyWith(color: accent),
                ),
              ],
            ),
          ),
          Text(
            '${_format(material.availableQuantity)} / ${_format(material.requiredQuantity)}',
            style: AppTextStyles.body.standardCopyWith(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _format(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }
}
