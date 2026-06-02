import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/type_product_preview.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';

class StoreTypeSelectionScreen extends ConsumerStatefulWidget {
  final CityModel selectedCity;

  const StoreTypeSelectionScreen({super.key, required this.selectedCity});

  @override
  ConsumerState<StoreTypeSelectionScreen> createState() =>
      _StoreTypeSelectionScreenState();
}

class _StoreTypeSelectionScreenState
    extends ConsumerState<StoreTypeSelectionScreen> {
  StoreTypeModel? _selectedType;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(storeTypesProvider);
    final playerAsync = ref.watch(playerProvider);
    final catalogsAsync = ref.watch(staticCatalogsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            SecondaryTopBar(title: '${widget.selectedCity.name} - Mağaza Türü'),
            Expanded(
              child: playerAsync.when(
                data: (player) => catalogsAsync.when(
                  data: (catalogs) => typesAsync.when(
                    data: (types) => _buildTypeList(
                      types,
                      catalogs.products,
                      player?.cash ?? 0,
                      player?.level ?? 1,
                    ),
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    ),
                    error: (error, stack) => Center(
                      child: Text(
                        'Hata: $error',
                        style: TextStyle(color: AppColors.red),
                      ),
                    ),
                  ),
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  ),
                  error: (error, stack) => Center(
                    child: Text(
                      'Urun katalogu yuklenemedi.',
                      style: TextStyle(color: AppColors.red),
                    ),
                  ),
                ),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (error, stack) => Center(
                  child: Text(
                    'Oyuncu bilgisi alınamadı.',
                    style: TextStyle(color: AppColors.red),
                  ),
                ),
              ),
            ),
            _buildActionPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeList(
    List<StoreTypeModel> types,
    List<ProductModel> products,
    double playerCash,
    int playerLevel,
  ) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      itemCount: types.length,
      itemBuilder: (context, index) {
        final type = types[index];
        final isSelected = _selectedType?.id == type.id;

        // Kilit kontrolü
        final bool levelLocked = playerLevel < type.requiredLevel;
        final bool cashLocked = playerCash < type.cost;
        final bool isLocked = levelLocked || cashLocked;

        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 500)),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: GestureDetector(
            onTap: isLocked ? null : () => setState(() => _selectedType = type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(bottom: 12.h),
              padding: EdgeInsets.all(12.w),
              decoration: AppDecorations.premiumCard(
                isSelected
                    ? AppColors.gold
                    : (isLocked
                        ? AppColors.border.withValues(alpha: 0.2)
                        : AppColors.border.withValues(alpha: 0.5)),
                16.r,
              ),
            child: Opacity(
              opacity: isLocked ? 0.6 : 1.0,
              child: Row(
                children: [
                  // İkon
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
                            color: isSelected
                                ? AppColors.gold
                                : AppColors.border,
                          ),
                        ),
                        child: CachedAssetImage(
                          fileName: type.icon,
                          fit: BoxFit.contain,
                        ),
                      ),
                      if (isLocked)
                        Container(
                          width: 65.w,
                          height: 65.w,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(
                            Icons.lock,
                            color: AppColors.gold,
                            size: 24.sp,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: 16.w),
                  // Bilgiler
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type.name,
                          style: TextStyle(
                            color: isSelected ? AppColors.gold : Colors.white,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            _buildDetailChip(
                              Icons.monetization_on,
                              _formatMoney(type.cost.toDouble()),
                              cashLocked ? AppColors.red : AppColors.gold,
                            ),
                            SizedBox(width: 8.w),
                            _buildDetailChip(
                              Icons.stars,
                              'Lv. ${type.requiredLevel}',
                              levelLocked ? AppColors.red : Colors.blueAccent,
                            ),
                          ],
                        ),
                        if (isLocked) ...[
                          SizedBox(height: 4.h),
                          Text(
                            levelLocked ? 'Yetersiz Seviye' : 'Yetersiz Para',
                            style: TextStyle(
                              color: AppColors.red,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        SizedBox(height: 10.h),
                        TypeProductPreview(
                          title: 'Satabilecegi urunler',
                          products: resolveAcceptedProducts(
                            type.acceptedProductIds,
                            products,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: AppColors.gold,
                      size: 24.sp,
                    ),
                ],
              ),
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
        Icon(icon, color: color, size: 12.sp),
        SizedBox(width: 4.w),
        Text(
          label,
          style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
        ),
      ],
    );
  }

  Widget _buildActionPanel() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: AppDecorations.panelGlass(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedType != null) ...[
            Text(
              '${widget.selectedCity.name} şehrinde ${_selectedType!.name} kurmak üzeresin.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
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
                disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.r),
                ),
                elevation: _selectedType != null ? 8 : 0,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'MAĞAZAYI KUR',
                      style: TextStyle(
                        color: _selectedType != null
                            ? Colors.black
                            : Colors.white.withValues(alpha: 0.2),
                        fontSize: 16.sp,
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
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}K';
    return val.toStringAsFixed(0);
  }

  Future<void> _handleEstablish() async {
    if (_selectedType == null) return;
    setState(() => _isProcessing = true);
    try {
      final result = await ref
          .read(storeActionProvider)
          .createStore(
            cityId: widget.selectedCity.id,
            typeId: _selectedType!.id,
            name: _selectedType!.name,
          );
      if (result['success'] == true) {
        if (mounted) {
          // Listeyi yenilemesi için provider'ı invalidate et
          await ref.read(storesListProvider.notifier).refresh();
          ref.invalidate(playerProvider);
          
          AppSnackbar.show(
            context,
            title: 'Başarılı',
            message: 'Mağaza inşaatı başarıyla başladı!',
            type: SnackbarType.success,
          );
          context.go('/store');
        }
      } else {
        if (mounted) {
          AppSnackbar.show(
            context,
            title: 'Hata',
            message: result['message'] ?? 'Bir hata oluştu.',
            type: SnackbarType.error,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
