import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';

class ProductSelectionOption {
  final String id;
  final String title;
  final String subtitle;
  final String iconPath;
  final String? badgeText;
  final String? trailingText;
  final Widget? trailingWidget;
  final bool isDisabled;
  final String? disabledReason;
  final VoidCallback onTap;

  ProductSelectionOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconPath,
    this.badgeText,
    this.trailingText,
    this.trailingWidget,
    this.isDisabled = false,
    this.disabledReason,
    required this.onTap,
  });
}

class ProductSelectionSheet extends StatefulWidget {
  final String title;
  final List<ProductSelectionOption> options;

  const ProductSelectionSheet({
    super.key,
    required this.title,
    required this.options,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required List<ProductSelectionOption> options,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.transparent,
      isScrollControlled: true,
      barrierColor: AppFx.scrim(),
      builder: (sheetContext) => ProductSelectionSheet(
        title: title,
        options: options,
      ),
    );
  }

  @override
  State<ProductSelectionSheet> createState() => _ProductSelectionSheetState();
}

class _ProductSelectionSheetState extends State<ProductSelectionSheet> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredOptions = widget.options.where((option) {
      if (_searchQuery.isEmpty) return true;
      return option.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          option.subtitle.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: AppDecorations.panelGlass(24.r),
          padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 24.h),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Notch Indicator
                Center(
                  child: Container(
                    width: 36.w,
                    height: 4.h,
                    margin: EdgeInsets.only(bottom: 12.h),
                    decoration: BoxDecoration(
                      color: AppFx.softOverlay(0.15),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.title,
                      style: AppTextStyles.h2.standardCopyWith(
                        color: AppColors.goldLight,
                        fontSize: AppTypography.headline,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(AppIcons.close, color: AppColors.textMuted),
                      style: IconButton.styleFrom(
                        backgroundColor: AppFx.softOverlay(0.05),
                        padding: EdgeInsets.all(6.w),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                // Search Bar
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: AppTextStyles.input.standardCopyWith(color: AppColors.white),
                  decoration: AppInputStyles.search(
                    hintText: 'Ürün ara...',
                    prefixIcon: Icon(AppIcons.search, color: AppColors.gold),
                    fillColor: AppFx.panelWash(0.25),
                    borderColor: AppFx.softOverlay(0.06),
                  ),
                ),
                SizedBox(height: 16.h),
                // Options List
                Flexible(
                  child: filteredOptions.isEmpty
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 40.h),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  AppIcons.inventory2Outlined,
                                  color: AppColors.textMuted,
                                  size: AppIconSizes.displayLarge,
                                ),
                                SizedBox(height: 12.h),
                                Text(
                                  'Aramanızla eşleşen ürün bulunamadı.',
                                  style: AppTextStyles.body.standardCopyWith(
                                    color: AppColors.textMuted,
                                    fontSize: AppTypography.body,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: filteredOptions.length,
                          separatorBuilder: (context, index) => SizedBox(height: 10.h),
                          itemBuilder: (context, index) {
                            final option = filteredOptions[index];
                            
                            // Staggered Entrance Animation
                            return TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              duration: Duration(milliseconds: 260 + (index * 40)),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return Transform.translate(
                                  offset: Offset(0, (1 - value) * 15.h),
                                  child: Opacity(
                                    opacity: value.clamp(0.0, 1.0),
                                    child: child,
                                  ),
                                );
                              },
                              child: Material(
                                color: AppColors.transparent,
                                child: InkWell(
                                  onTap: option.isDisabled ? null : option.onTap,
                                  borderRadius: BorderRadius.circular(16.r),
                                  child: Opacity(
                                    opacity: option.isDisabled ? 0.5 : 1.0,
                                    child: Container(
                                      padding: EdgeInsets.all(12.w),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppFx.softOverlay(0.04),
                                            AppFx.softOverlay(0.01),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16.r),
                                        border: Border.all(
                                          color: option.isDisabled
                                              ? AppFx.softOverlay(0.05)
                                              : AppColors.borderGoldLight.withValues(alpha: 0.15),
                                          width: 1.w,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppFx.shadow(0.15),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          // Product Icon
                                          Container(
                                            width: 44.w,
                                            height: 44.w,
                                            padding: EdgeInsets.all(6.w),
                                            decoration: BoxDecoration(
                                              color: AppFx.panelWash(0.35),
                                              borderRadius: BorderRadius.circular(12.r),
                                              border: Border.all(
                                                color: AppFx.softOverlay(0.05),
                                                width: 1.w,
                                              ),
                                            ),
                                            child: CachedAssetImage(
                                              fileName: option.iconPath,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                          SizedBox(width: 12.w),
                                          // Details
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  option.title,
                                                  style: AppTextStyles.title.standardCopyWith(
                                                    color: AppColors.white,
                                                    fontSize: AppTypography.bodyLarge,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                SizedBox(height: 4.h),
                                                Text(
                                                  option.isDisabled && option.disabledReason != null
                                                      ? option.disabledReason!
                                                      : option.subtitle,
                                                  style: AppTextStyles.body.standardCopyWith(
                                                    color: option.isDisabled
                                                        ? AppColors.danger.withValues(alpha: 0.8)
                                                        : AppColors.textMuted,
                                                    fontSize: AppTypography.bodySmall,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(width: 10.w),
                                          // Badges / Trailing Info
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              if (option.badgeText != null) ...[
                                                Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.gold.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(6.r),
                                                    border: Border.all(
                                                      color: AppColors.gold.withValues(alpha: 0.35),
                                                      width: 1.w,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    option.badgeText!,
                                                    style: AppTextStyles.caption.standardCopyWith(
                                                      color: AppColors.goldLight,
                                                      fontSize: AppTypography.caption,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(height: 4.h),
                                              ],
                                              if (option.trailingText != null)
                                                Text(
                                                  option.trailingText!,
                                                  style: AppTextStyles.label.standardCopyWith(
                                                    color: AppColors.goldLight,
                                                    fontSize: AppTypography.bodySmall,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              if (option.trailingWidget != null)
                                                option.trailingWidget!,
                                              if (option.isDisabled && option.trailingWidget == null && option.badgeText == null && option.trailingText == null)
                                                Icon(
                                                  AppIcons.block,
                                                  color: AppColors.danger.withValues(alpha: 0.7),
                                                  size: AppIconSizes.regular,
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
