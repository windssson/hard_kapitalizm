import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/company/data/company_provider.dart';
import 'package:hard_kapitalizm/features/company/models/brand_company_model.dart';
import 'package:hard_kapitalizm/features/company/models/brand_company_product_model.dart';

class CompanyScreen extends ConsumerStatefulWidget {
  const CompanyScreen({super.key});

  @override
  ConsumerState<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends ConsumerState<CompanyScreen> {
  final TextEditingController _brandNameController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _brandNameController.dispose();
    super.dispose();
  }

  void _onNavSelected(int index) {
    if (index == 1) return;
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 2:
        context.go('/transfer-map');
        break;
      case 3:
        context.go('/market');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  Future<void> _createCompany() async {
    final brandName = _brandNameController.text.trim();
    if (brandName.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: 'Marka adi bos olamaz.',
        type: SnackbarType.error,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await ref
        .read(companyActionProvider)
        .createBrandCompany(brandName: brandName);
    if (mounted) {
      setState(() => _isSubmitting = false);
    }

    if (!mounted) return;
    AppSnackbar.show(
      context,
      title: result['success'] == true ? 'Basarili' : 'Hata',
      message: (result['message'] ?? 'Islem tamamlanamadi.').toString(),
      type: result['success'] == true
          ? SnackbarType.success
          : SnackbarType.error,
    );
  }

  Future<void> _patentProduct(String productId) async {
    final result = await ref
        .read(companyActionProvider)
        .patentBrandProduct(productId: productId);
    if (!mounted) return;
    final success = result['success'] == true;
    var message = (result['message'] ?? 'Patent islemi tamamlanamadi.').toString();
    if (success) {
      final syncedFactoryCount =
          (result['synced_factory_count'] as num?)?.toInt() ?? 0;
      final syncedMineCount =
          (result['synced_mine_count'] as num?)?.toInt() ?? 0;
      final syncedSlotCount =
          (result['synced_slot_count'] as num?)?.toInt() ?? 0;
      final syncedOutputInventoryCount =
          (result['synced_output_inventory_count'] as num?)?.toInt() ?? 0;
      final mergedOutputInventoryCount =
          (result['merged_output_inventory_count'] as num?)?.toInt() ?? 0;
      final syncParts = <String>[];
      if (syncedFactoryCount > 0) {
        syncParts.add('$syncedFactoryCount fabrika');
      }
      if (syncedMineCount > 0) {
        syncParts.add('$syncedMineCount maden');
      }
      if (syncedSlotCount > 0) {
        syncParts.add('$syncedSlotCount slot');
      }
      if (syncedOutputInventoryCount > 0) {
        syncParts.add('$syncedOutputInventoryCount output kaydi');
      }
      if (mergedOutputInventoryCount > 0) {
        syncParts.add('$mergedOutputInventoryCount birlesim');
      }
      if (syncParts.isNotEmpty) {
        message = '$message Senkron: ${syncParts.join(', ')}.';
      }
    }
    AppSnackbar.show(
      context,
      title: success ? 'Basarili' : 'Hata',
      message: message,
      type: success ? SnackbarType.success : SnackbarType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(playerBrandCompanyProvider);
    final productsAsync = ref.watch(playerBrandCompanyProductsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 1,
        onItemSelected: _onNavSelected,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Sirket'),
            Expanded(
              child: companyAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (error, _) => _buildError(error.toString()),
                data: (company) {
                  if (company == null) {
                    return _buildSetupState();
                  }

                  return productsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    ),
                    error: (error, _) => _buildError(error.toString()),
                    data: (products) => _buildManagementState(company, products),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Text(
          message,
          style: TextStyle(color: AppColors.red, fontSize: 13.sp),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSetupState() {
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: AppDecorations.panelGlass(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Marka Sirketi Kur',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Kendi markani olustur. Sonrasinda kalite 5 urunleri bu marka altinda patentiyle uretebileceksin.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                ),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: _brandNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Marka adi',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppColors.gold),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _createCompany,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                  child: Text(
                    _isSubmitting ? 'Kuruluyor...' : 'Sirketi Kur',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManagementState(
    BrandCompanyModel company,
    List<BrandCompanyProductModel> products,
  ) {
    final brandedProducts = products.where((item) => item.isBranded).toList();
    final availableProducts = products.where((item) => !item.isBranded).toList();
    final patentReadiness = products.isEmpty
        ? 0.0
        : brandedProducts.length / products.length;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(playerBrandCompanyProvider);
        ref.invalidate(playerBrandCompanyProductsProvider);
      },
      child: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: AppDecorations.panelGlass(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  company.brandName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Aktif markali urun: ${brandedProducts.length}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    _buildStatChip(
                      'Patentli',
                      brandedProducts.length.toString(),
                      AppColors.green,
                    ),
                    _buildStatChip(
                      'Hazir',
                      availableProducts.length.toString(),
                      AppColors.gold,
                    ),
                    _buildStatChip(
                      'Kapsam',
                      '%${(patentReadiness * 100).round()}',
                      AppColors.blue,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: AppDecorations.panelGlass(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sirket Ozeti',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Bu asamada marka adi tum urunlerde ortaktir. Patent aldigin kalite 5 urunler markali uretime otomatik baglanir.',
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
          _buildSectionTitle('Markalanabilir Urunler'),
          SizedBox(height: 8.h),
          if (availableProducts.isEmpty)
            _buildEmptyCard('Kalite 5 seviyesinde patentlenebilir yeni urun yok.')
          else
            ...availableProducts.map(_buildPatentCard),
          SizedBox(height: 16.h),
          _buildSectionTitle('Markali Urunler'),
          SizedBox(height: 8.h),
          if (brandedProducts.isEmpty)
            _buildEmptyCard('Bu marka altinda henuz aktif urun yok.')
          else
            ...brandedProducts.map((item) => _buildPatentCard(item, readOnly: true)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white,
        fontSize: 16.sp,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: AppDecorations.panelGlass(),
      child: Text(
        message,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatentCard(
    BrandCompanyProductModel item, {
    bool readOnly = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.panelGlass(),
      child: Row(
        children: [
          Container(
            width: 50.w,
            height: 50.w,
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: CachedAssetImage(
              fileName: item.productIcon,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Maks kalite: ${item.maxQualityLevel}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          ElevatedButton(
            onPressed: readOnly ? null : () => _patentProduct(item.productId),
            style: ElevatedButton.styleFrom(
              backgroundColor: readOnly ? AppColors.green : AppColors.gold,
              foregroundColor: Colors.black,
            ),
            child: Text(readOnly ? 'Markali' : 'Patent Al'),
          ),
        ],
      ),
    );
  }
}
