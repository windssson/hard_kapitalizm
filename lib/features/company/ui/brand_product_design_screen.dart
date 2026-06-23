import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/branded_product_image.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/company/data/company_provider.dart';
import 'package:hard_kapitalizm/features/company/models/brand_company_product_model.dart';

class BrandProductDesignScreen extends ConsumerStatefulWidget {
  const BrandProductDesignScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<BrandProductDesignScreen> createState() =>
      _BrandProductDesignScreenState();
}

class _BrandProductDesignScreenState
    extends ConsumerState<BrandProductDesignScreen> {
  String? _selectedWatermark;
  bool _didInitialize = false;
  bool _isSaving = false;

  Color _parseHexColor(String hex, {Color fallback = AppColors.gold}) {
    try {
      var hexColor = hex.replaceAll('#', '');
      if (hexColor.length == 6) {
        hexColor = 'FF$hexColor';
      }
      if (hexColor.length == 8) {
        return Color(int.parse(hexColor, radix: 16));
      }
    } catch (_) {}
    return fallback;
  }

  void _syncSelection(String? currentWatermark) {
    if (_didInitialize) return;
    _selectedWatermark = currentWatermark;
    _didInitialize = true;
  }

  Future<void> _saveWatermark(String productId) async {
    setState(() => _isSaving = true);
    final result = await ref
        .read(companyActionProvider)
        .setBrandProductWatermark(
          productId: productId,
          watermarkAssetId: _selectedWatermark,
        );
    if (mounted) {
      setState(() => _isSaving = false);
    }

    if (!mounted) return;
    final success = result['success'] == true;
    AppSnackbar.show(
      context,
      title: success ? 'Basarili' : 'Hata',
      message: (result['message'] ?? 'Islem tamamlanamadi.').toString(),
      type: success ? SnackbarType.success : SnackbarType.error,
    );
    if (success) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(playerBrandCompanyProvider);
    final productsAsync = ref.watch(playerBrandCompanyProductsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Urun Tasarimi'),
            Expanded(
              child: companyAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (error, _) => _buildErrorState(error.toString()),
                data: (company) {
                  if (company == null) {
                    return _buildErrorState('Aktif marka bulunamadi.');
                  }

                  final brandColor = _parseHexColor(company.themeColor);

                  return productsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    ),
                    error: (error, _) => _buildErrorState(error.toString()),
                    data: (products) {
                      BrandCompanyProductModel? product;
                      for (final item in products) {
                        if (item.productId == widget.productId &&
                            item.isBranded) {
                          product = item;
                          break;
                        }
                      }

                      if (product == null) {
                        return _buildErrorState(
                          'Markali urun bulunamadi veya tasarim acik degil.',
                        );
                      }

                      _syncSelection(product.watermarkAssetId);

                      return ListView(
                        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              vertical: 20.h,
                              horizontal: 16.w,
                            ),
                            decoration: AppDecorations.panelGlass(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  product.productName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 14.h),
                                Container(
                                  width: 160.w,
                                  height: 160.w,
                                  padding: EdgeInsets.all(16.w),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(24.r),
                                    border: Border.all(
                                      color: brandColor.withValues(alpha: 0.25),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: BrandedProductImage(
                                    fileName: product.productIcon,
                                    brandId: company.id,
                                    brandName: company.brandName,
                                    watermarkAssetId: _selectedWatermark,
                                    productId: product.productId,
                                    fit: BoxFit.contain,
                                    watermarkSizeRatio: 0.65,
                                    fontSizeRatio: 0.11,
                                  ),
                                ),
                                SizedBox(height: 14.h),
                                Text(
                                  'Bu sayfa urune atanacak filigrani duzenlemek icin hazirlandi.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11.sp,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16.h),
                          _buildSectionTitle('Filigran Secimi'),
                          SizedBox(height: 10.h),
                          SizedBox(
                            height: 90.h,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _watermarkOptions.length + 1,
                              itemBuilder: (context, index) {
                                final isNone = index == 0;
                                final watermark = isNone
                                    ? null
                                    : _watermarkOptions[index - 1];
                                final isSelected =
                                    _selectedWatermark == watermark;
                                return GestureDetector(
                                  onTap: () => setState(
                                    () => _selectedWatermark = watermark,
                                  ),
                                  child: Container(
                                    margin: EdgeInsets.only(right: 12.w),
                                    width: 72.w,
                                    height: 72.h,
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(
                                        color: isSelected
                                            ? brandColor
                                            : AppColors.border.withValues(
                                                alpha: 0.5,
                                              ),
                                        width: isSelected ? 2.5 : 1,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: brandColor.withValues(
                                                  alpha: 0.28,
                                                ),
                                                blurRadius: 10,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10.r),
                                      child: isNone
                                          ? Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.block,
                                                    color:
                                                        AppColors.textSecondary,
                                                    size: 20.sp,
                                                  ),
                                                  SizedBox(height: 4.h),
                                                  Text(
                                                    'Yok',
                                                    style: TextStyle(
                                                      color: AppColors
                                                          .textSecondary,
                                                      fontSize: 10.sp,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                Container(
                                                  color: Colors.black38,
                                                ),
                                                Opacity(
                                                  opacity: 0.7,
                                                  child: CachedAssetImage(
                                                    fileName: watermark!,
                                                    fit: BoxFit.cover,
                                                    placeholder:
                                                        const SizedBox.shrink(),
                                                    errorWidget: const Icon(
                                                      Icons.broken_image,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  bottom: 4.h,
                                                  left: 4.w,
                                                  right: 4.w,
                                                  child: Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          vertical: 2.h,
                                                        ),
                                                    color: Colors.black54,
                                                    child: Text(
                                                      'Filigran $index',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 9.sp,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(height: 24.h),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSaving
                                  ? null
                                  : () => _saveWatermark(product!.productId),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brandColor,
                                foregroundColor: Colors.black,
                                padding: EdgeInsets.symmetric(vertical: 14.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                elevation: 5,
                                shadowColor: brandColor.withValues(alpha: 0.3),
                              ),
                              child: Text(
                                _isSaving
                                    ? 'Kaydediliyor...'
                                    : 'Filigrani Kaydet',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white,
        fontSize: 15.sp,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.red, fontSize: 13.sp),
        ),
      ),
    );
  }
}

const List<String> _watermarkOptions = [
  'filigran1.webp',
  'filigran2.webp',
  'filigran3.webp',
  'filigran4.webp',
  'filigran5.webp',
  'filigran6.webp',
  'filigran7.webp',
  'filigran8.webp',
  'filigran9.webp',
  'filigran10.webp',
];
