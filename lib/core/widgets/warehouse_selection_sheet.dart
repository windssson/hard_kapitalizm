import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/utils/app_haptic.dart';

class WarehouseSelectionProductPreview {
  final String icon;
  final double quantity;
  final int quality;
  final String? name;

  WarehouseSelectionProductPreview({
    required this.icon,
    required this.quantity,
    required this.quality,
    this.name,
  });
}

class WarehouseSelectionOption {
  final String id;
  final String title;
  final String subtitle;
  final String? cityName;
  final bool? isStoreWarehouse;
  final String? badgeText;
  final String? infoText;
  final bool isHighlightBadge;
  final double? capacityRatio;
  final String? capacityLabel;
  final String? freeCapacityLabel;
  final int? occupiedSlots;
  final int? totalSlots;
  final String? distanceLabel;
  final String? durationLabel;
  final List<WarehouseSelectionProductPreview>? productPreviews;
  final VoidCallback onTap;

  WarehouseSelectionOption({
    required this.id,
    required this.title,
    required this.subtitle,
    this.cityName,
    this.isStoreWarehouse,
    this.badgeText,
    this.infoText,
    this.isHighlightBadge = false,
    this.capacityRatio,
    this.capacityLabel,
    this.freeCapacityLabel,
    this.occupiedSlots,
    this.totalSlots,
    this.distanceLabel,
    this.durationLabel,
    this.productPreviews,
    required this.onTap,
  });
}

class WarehouseSelectionSheet extends StatefulWidget {
  final String title;
  final List<WarehouseSelectionOption> options;

  const WarehouseSelectionSheet({
    super.key,
    required this.title,
    required this.options,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required List<WarehouseSelectionOption> options,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.transparent,
      isScrollControlled: true,
      barrierColor: AppFx.scrim(),
      builder: (sheetContext) => WarehouseSelectionSheet(
        title: title,
        options: options,
      ),
    );
  }

  @override
  State<WarehouseSelectionSheet> createState() => _WarehouseSelectionSheetState();
}

class _WarehouseSelectionSheetState extends State<WarehouseSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'same_city', 'store', 'normal'

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final query = _searchController.text.trim().toLowerCase();
      if (query != _searchQuery) {
        setState(() {
          _searchQuery = query;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<WarehouseSelectionOption> _filterOptions() {
    return widget.options.where((opt) {
      // 1. Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final matchesTitle = opt.title.toLowerCase().contains(_searchQuery);
        final matchesSubtitle = opt.subtitle.toLowerCase().contains(_searchQuery);
        final matchesCity = opt.cityName?.toLowerCase().contains(_searchQuery) ?? false;
        if (!matchesTitle && !matchesSubtitle && !matchesCity) {
          return false;
        }
      }

      // 2. Category Filter
      if (_selectedFilter == 'same_city') {
        return opt.isHighlightBadge;
      } else if (_selectedFilter == 'store') {
        final isStore = opt.isStoreWarehouse ??
            (opt.title.toLowerCase().contains('mağaza') ||
                opt.title.toLowerCase().contains('magaza') ||
                opt.title.toLowerCase().contains('bakkal') ||
                opt.title.toLowerCase().contains('market') ||
                opt.subtitle.toLowerCase().contains('mağaza') ||
                opt.subtitle.toLowerCase().contains('magaza'));
        return isStore;
      } else if (_selectedFilter == 'normal') {
        final isStore = opt.isStoreWarehouse ??
            (opt.title.toLowerCase().contains('mağaza') ||
                opt.title.toLowerCase().contains('magaza') ||
                opt.title.toLowerCase().contains('bakkal') ||
                opt.title.toLowerCase().contains('market') ||
                opt.subtitle.toLowerCase().contains('mağaza') ||
                opt.subtitle.toLowerCase().contains('magaza'));
        return !isStore;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredOptions = _filterOptions();
    final hasMultipleOptions = widget.options.length > 3;

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

                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                          SizedBox(height: 2.h),
                          Text(
                            'Çoklu transfer için hedef veya kaynak deponuzu seçin.',
                            style: AppTextStyles.caption.standardCopyWith(
                              color: AppColors.textMuted,
                              fontSize: AppTypography.caption,
                            ),
                          ),
                        ],
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

                // Search & Filter Section (Shown when player has multiple warehouses)
                if (hasMultipleOptions) ...[
                  // Search Box
                  Container(
                    height: 38.h,
                    decoration: BoxDecoration(
                      color: AppFx.softOverlay(0.05),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.borderGoldLight.withValues(alpha: 0.15),
                        width: 1.w,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.white,
                        fontSize: AppTypography.bodySmall,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Depo veya şehir adı ile ara...',
                        hintStyle: AppTextStyles.body.standardCopyWith(
                          color: AppColors.textMuted.withValues(alpha: 0.6),
                          fontSize: AppTypography.bodySmall,
                        ),
                        prefixIcon: Icon(
                          AppIcons.search,
                          color: AppColors.textMuted,
                          size: AppIconSizes.compact,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  AppIcons.close,
                                  color: AppColors.textMuted,
                                  size: AppIconSizes.xSmall,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8.h),
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('Tümü', 'all'),
                        SizedBox(width: 6.w),
                        _buildFilterChip('⚡ Aynı Şehir', 'same_city'),
                        SizedBox(width: 6.w),
                        _buildFilterChip('🏪 Mağaza Depoları', 'store'),
                        SizedBox(width: 6.w),
                        _buildFilterChip('🏢 Genel Depolar', 'normal'),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                ],

                // Content List or Empty State
                if (widget.options.isEmpty) ...[
                  _buildEmptyState(
                    title: 'Uygun Depo Bulunamadı',
                    message: 'Bu işlem için uygun veya aktif bir deponuz bulunmuyor.',
                  ),
                ] else if (filteredOptions.isEmpty) ...[
                  _buildEmptyState(
                    title: 'Aramaya Uygun Depo Yok',
                    message: 'Seçili filtrelere veya arama terimine uyan bir depo bulunamadı.',
                  ),
                ] else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: filteredOptions.length,
                      separatorBuilder: (context, index) => SizedBox(height: 10.h),
                      itemBuilder: (context, index) {
                        final option = filteredOptions[index];
                        return _buildWarehouseCard(option, index);
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

  Widget _buildFilterChip(String label, String filterKey) {
    final isSelected = _selectedFilter == filterKey;
    return InkWell(
      onTap: () {
        AppHaptic.selection();
        setState(() {
          _selectedFilter = filterKey;
        });
      },
      borderRadius: BorderRadius.circular(20.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.18)
              : AppFx.softOverlay(0.04),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected
                ? AppColors.gold
                : AppColors.borderGoldLight.withValues(alpha: 0.12),
            width: 1.w,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.standardCopyWith(
            color: isSelected ? AppColors.goldLight : AppColors.textMuted,
            fontSize: AppTypography.caption,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildWarehouseCard(WarehouseSelectionOption option, int index) {
    final isStore = option.isStoreWarehouse ??
        (option.title.toLowerCase().contains('mağaza') ||
            option.title.toLowerCase().contains('magaza') ||
            option.title.toLowerCase().contains('bakkal') ||
            option.title.toLowerCase().contains('market') ||
            option.subtitle.toLowerCase().contains('mağaza') ||
            option.subtitle.toLowerCase().contains('magaza'));

    final isNearFull = (option.capacityRatio ?? 0.0) >= 0.85;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 220 + (index * 40)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 16.h),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: () {
            AppHaptic.light();
            option.onTap();
          },
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: option.isHighlightBadge
                    ? [
                        AppColors.green.withValues(alpha: 0.08),
                        AppFx.softOverlay(0.02),
                      ]
                    : [
                        AppFx.softOverlay(0.05),
                        AppFx.softOverlay(0.02),
                      ],
              ),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: option.isHighlightBadge
                    ? AppColors.green.withValues(alpha: 0.45)
                    : AppColors.borderGoldLight.withValues(alpha: 0.15),
                width: 1.2.w,
              ),
              boxShadow: [
                BoxShadow(
                  color: option.isHighlightBadge
                      ? AppColors.green.withValues(alpha: 0.05)
                      : AppFx.shadow(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header: Icon + Name & City + Logistics Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Warehouse Icon Container
                    Container(
                      padding: EdgeInsets.all(9.w),
                      decoration: BoxDecoration(
                        color: AppFx.panelWash(0.45),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: (option.isHighlightBadge ? AppColors.green : AppColors.gold)
                              .withValues(alpha: 0.35),
                          width: 1.2.w,
                        ),
                      ),
                      child: Icon(
                        isStore ? AppIcons.storeOutlined : AppIcons.warehouseOutlined,
                        color: option.isHighlightBadge ? AppColors.green : AppColors.gold,
                        size: AppIconSizes.medium,
                      ),
                    ),
                    SizedBox(width: 12.w),

                    // Name, City & Warehouse Type
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  option.title,
                                  style: AppTextStyles.title.standardCopyWith(
                                    color: AppColors.white,
                                    fontSize: AppTypography.bodyLarge,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 3.h),
                          Row(
                            children: [
                              Icon(
                                AppIcons.locationOnOutlined,
                                color: AppColors.textMuted,
                                size: AppIconSizes.xSmall,
                              ),
                              SizedBox(width: 3.w),
                              Text(
                                option.subtitle,
                                style: AppTextStyles.body.standardCopyWith(
                                  color: AppColors.textMuted,
                                  fontSize: AppTypography.caption,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(width: 8.w),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                                decoration: BoxDecoration(
                                  color: isStore
                                      ? AppColors.gold.withValues(alpha: 0.10)
                                      : AppFx.softOverlay(0.06),
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Text(
                                  isStore ? 'Mağaza Deposu' : 'Genel Depo',
                                  style: AppTextStyles.caption.standardCopyWith(
                                    color: isStore ? AppColors.goldLight : AppColors.textMuted,
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),

                    // Logistics / Transfer Badge
                    if (option.badgeText != null)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: (option.isHighlightBadge ? AppColors.green : AppColors.gold)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: (option.isHighlightBadge ? AppColors.green : AppColors.gold)
                                .withValues(alpha: 0.35),
                            width: 1.w,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              option.isHighlightBadge
                                  ? AppIcons.boltRounded
                                  : AppIcons.localShippingRounded,
                              color: option.isHighlightBadge ? AppColors.green : AppColors.goldLight,
                              size: 11.sp,
                            ),
                            SizedBox(width: 3.w),
                            Text(
                              option.badgeText!,
                              style: AppTextStyles.label.standardCopyWith(
                                color: option.isHighlightBadge ? AppColors.green : AppColors.goldLight,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // 2. Capacity & Free Space Progress Strip
                if (option.capacityRatio != null) ...[
                  SizedBox(height: 10.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
                    decoration: BoxDecoration(
                      color: AppFx.softOverlay(0.04),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: AppColors.borderGoldLight.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isNearFull ? AppIcons.warningRounded : AppIcons.checkCircleRounded,
                                  color: isNearFull ? AppColors.danger : AppColors.green,
                                  size: 12.sp,
                                ),
                                SizedBox(width: 5.w),
                                Text(
                                  option.freeCapacityLabel ??
                                      (isNearFull ? 'Depo Dolmak Üzere!' : 'Kullanılabilir Boş Alan'),
                                  style: AppTextStyles.caption.standardCopyWith(
                                    color: isNearFull ? AppColors.danger : AppColors.white,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              option.capacityLabel ??
                                  '${(option.capacityRatio! * 100).toStringAsFixed(0)}% Dolu',
                              style: AppTextStyles.caption.standardCopyWith(
                                color: isNearFull ? AppColors.danger : AppColors.goldLight,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 5.h),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999.r),
                          child: LinearProgressIndicator(
                            value: option.capacityRatio!.clamp(0.0, 1.0),
                            minHeight: 4.h,
                            backgroundColor: AppFx.softOverlay(0.10),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              option.capacityRatio! > 0.85
                                  ? AppColors.danger
                                  : option.capacityRatio! > 0.65
                                      ? AppColors.warning
                                      : AppColors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 3. Product Slots Previews (Mevcut Stoklar & Boş Slotlar)
                if (option.productPreviews != null && option.productPreviews!.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  SizedBox(
                    height: 24.h,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      shrinkWrap: true,
                      itemCount: option.productPreviews!.length,
                      separatorBuilder: (context, index) => SizedBox(width: 6.w),
                      itemBuilder: (context, idx) {
                        final preview = option.productPreviews![idx];
                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: AppFx.softOverlay(0.06),
                            borderRadius: BorderRadius.circular(6.r),
                            border: Border.all(
                              color: AppColors.borderGoldLight.withValues(alpha: 0.15),
                              width: 0.8.w,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CachedAssetImage(
                                fileName: preview.icon.isNotEmpty ? preview.icon : 'default.webp',
                                width: 14.w,
                                height: 14.w,
                                fit: BoxFit.contain,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                _formatPreviewQuantity(preview.quantity),
                                style: AppTextStyles.caption.standardCopyWith(
                                  color: AppColors.white,
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (preview.quality > 0) ...[
                                SizedBox(width: 3.w),
                                Text(
                                  '⭐${preview.quality}',
                                  style: AppTextStyles.caption.standardCopyWith(
                                    color: AppColors.gold,
                                    fontSize: 8.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // 4. Action Context Info (Transfer Uygunluğu)
                if (option.infoText != null && option.infoText!.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          option.infoText!,
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.goldLight.withValues(alpha: 0.85),
                            fontSize: AppTypography.caption,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        AppIcons.chevronRight,
                        color: AppColors.goldLight.withValues(alpha: 0.6),
                        size: AppIconSizes.xSmall,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({required String title, required String message}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 36.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: AppFx.softOverlay(0.04),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.borderGoldLight.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppIcons.warehouseOutlined,
              color: AppColors.gold,
              size: 36.r,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            title,
            style: AppTextStyles.title.standardCopyWith(
              color: AppColors.white,
              fontSize: AppTypography.title,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.bodySmall,
            ),
          ),
          SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.black,
              ),
              onPressed: () {
                Navigator.pop(context);
                context.go('/warehouses');
              },
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Depolara Git'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPreviewQuantity(double qty) {
    if (qty >= 1000000) {
      return '${(qty / 1000000).toStringAsFixed(1)}M';
    } else if (qty >= 1000) {
      return '${(qty / 1000).toStringAsFixed(1)}k';
    } else {
      return qty.toStringAsFixed(0);
    }
  }
}
