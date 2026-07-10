import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/type_product_preview.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/mine/data/mine_provider.dart';

class MineTypeSelectionScreen extends ConsumerStatefulWidget {
  final CityModel selectedCity;

  const MineTypeSelectionScreen({super.key, required this.selectedCity});

  @override
  ConsumerState<MineTypeSelectionScreen> createState() =>
      _MineTypeSelectionScreenState();
}

class _MineTypeSelectionScreenState
    extends ConsumerState<MineTypeSelectionScreen> {
  Map<String, dynamic>? _selectedType;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(mineTypesProvider);
    final playerAsync = ref.watch(playerProvider);
    final catalogsAsync = ref.watch(staticCatalogsProvider);

    return Scaffold(
      backgroundColor: AppColors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            SecondaryTopBar(title: '${widget.selectedCity.name} - Maden Turu'),
            Expanded(
              child: playerAsync.when(
                data: (player) => catalogsAsync.when(
                  data: (catalogs) => typesAsync.when(
                    data: (types) => _buildTypeList(
                      types,
                      catalogs.products,
                      (player?.cash ?? 0).toDouble(),
                      player?.level ?? 1,
                    ),
                    loading: () => Center(
                      child: AppLoadingIndicator(color: AppColors.gold),
                    ),
                    error: (error, stack) => Center(
                      child: Text(
                        'Hata: $error',
                        style: AppTextStyles.body.standardCopyWith(color: AppColors.red),
                      ),
                    ),
                  ),
                  loading: () => Center(
                    child: AppLoadingIndicator(color: AppColors.gold),
                  ),
                  error: (error, stack) =>
                      Center(child: Text('Urun katalogu yuklenemedi.')),
                ),
                loading: () => Center(
                  child: AppLoadingIndicator(color: AppColors.gold),
                ),
                error: (error, stack) =>
                    Center(child: Text('Oyuncu bilgisi alinamadi.')),
              ),
            ),
            _buildActionPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeList(
    List<dynamic> types,
    List<ProductModel> products,
    double playerCash,
    int playerLevel,
  ) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      itemCount: types.length,
      itemBuilder: (context, index) {
        final type = Map<String, dynamic>.from(types[index] as Map);
        final isSelected = _selectedType?['id'] == type['id'];

        final levelLocked = playerLevel < (type['required_level'] ?? 1);
        final cashLocked = playerCash < (type['cost'] ?? 0);
        final isLocked = levelLocked || cashLocked;

        return GestureDetector(
          onTap: isLocked ? null : () => setState(() => _selectedType = type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(bottom: 12.h),
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.gold.withValues(alpha: 0.1)
                  : AppColors.cardBg,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: isSelected
                    ? AppColors.gold
                    : AppColors.border.withValues(alpha: isLocked ? 0.2 : 0.5),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Opacity(
              opacity: isLocked ? 0.6 : 1.0,
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 65.w,
                        height: 65.w,
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: AppColors.cardBgLight,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: isSelected ? AppColors.gold : AppColors.border,
                          ),
                        ),
                        child: CachedAssetImage(
                          fileName: (type['icon'] ?? 'mine.webp').toString(),
                          fit: BoxFit.contain,
                        ),
                      ),
                      if (isLocked)
                        Container(
                          width: 65.w,
                          height: 65.w,
                          decoration: BoxDecoration(
                            color: AppFx.panelWash(0.45),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(
                            AppIcons.lock,
                            color: AppColors.gold,
                            size: AppIconSizes.large,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (type['name'] ?? 'Bilinmeyen Maden').toString(),
                          style: AppTextStyles.h2.standardCopyWith(
                            color: isSelected ? AppColors.gold : AppColors.white,
                            fontSize: AppTypography.titleLarge,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Wrap(
                          spacing: 8.w,
                          runSpacing: 4.h,
                          children: [
                            _buildDetailChip(
                              AppIcons.monetizationOn,
                              _formatMoney((type['cost'] ?? 0).toDouble()),
                              cashLocked ? AppColors.red : AppColors.gold,
                            ),
                            _buildDetailChip(
                              AppIcons.inventory2Outlined,
                              '${type['output_capacity'] ?? 0} Kap.',
                              AppColors.blue,
                            ),
                            _buildDetailChip(
                              AppIcons.stars,
                              'Lv. ${type['required_level'] ?? 1}',
                              levelLocked
                                  ? AppColors.red
                                  : AppColors.info,
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        TypeProductPreview(
                          title: 'Uretebilecegi urunler',
                          products: resolveAcceptedProducts(
                            parseAcceptedProductIds(type['accepted_product_ids']),
                            products,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      AppIcons.checkCircle,
                      color: AppColors.gold,
                      size: AppIconSizes.large,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: AppIconSizes.xxSmall),
        SizedBox(width: 4.w),
        Text(
          label,
          style: AppTextStyles.caption.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.label,
          ),
        ),
      ],
    );
  }

  Widget _buildActionPanel() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppFx.shadow(0.54),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedType != null) ...[
            Text(
              '${widget.selectedCity.name} sehrinde ${_selectedType!['name']} insa edilecek.',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.bodySmall,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
          ],
          SizedBox(
            width: double.infinity,
            height: 55.h,
            child: ElevatedButton(
              onPressed: (_selectedType != null && !_isProcessing)
                  ? _handleEstablish
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                disabledBackgroundColor:
                    AppColors.gold.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: _isProcessing
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: AppLoadingIndicator(
                        color: AppColors.textOnAccent,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'MADENI INSA ET',
                      style: AppTextStyles.button.standardCopyWith(
                        color:
                            _selectedType != null
                                ? AppColors.textOnAccent
                                : AppColors.white.withValues(alpha: 0.30),
                        fontSize: AppTypography.title,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMoney(double val) {
    return AppMoney.compact(val);
  }

  Future<void> _handleEstablish() async {
    if (_selectedType == null) return;
    setState(() => _isProcessing = true);
    try {
      final result = await ref.read(mineActionProvider).createMine(
        cityId: widget.selectedCity.id,
        typeId: _selectedType!['id'].toString(),
        name: _selectedType!['name'].toString(),
      );
      if (result['success'] == true) {
        ref.invalidate(playerProvider);
        ref.invalidate(mineListProvider);
        ref.invalidate(mineConstructionProvider);
        if (mounted) {
          AppSnackbar.show(
            context,
            title: 'Basarili',
            message: 'Maden insaati basladi!',
            type: SnackbarType.success,
          );
          context.go('/mines');
        }
      } else {
        if (mounted) {
          AppSnackbar.show(
            context,
            title: 'Hata',
            message: result['message'] ?? 'Islem basarisiz.',
            type: SnackbarType.error,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
