import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/models/warehouse_model.dart';

class ProductSelectionDialog extends ConsumerStatefulWidget {
  final WarehouseModel warehouse;

  const ProductSelectionDialog({super.key, required this.warehouse});

  @override
  ConsumerState<ProductSelectionDialog> createState() =>
      _ProductSelectionDialogState();
}

class _ProductSelectionDialogState
    extends ConsumerState<ProductSelectionDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final allProductsAsync = ref.watch(allProductsProvider);
    final typeDetailAsync = ref.watch(
      warehouseTypeDetailProvider(widget.warehouse.warehouseTypeId),
    );

    return Container(
      height: 0.8.sh,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          SizedBox(height: 16.h),
          _buildSearchField(),
          SizedBox(height: 16.h),
          Expanded(
            child: typeDetailAsync.when(
              data: (type) => allProductsAsync.when(
                data: (products) => _buildProductList(products, type),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (e, s) =>
                    Center(child: Text('Urunler yuklenemedi: $e')),
              ),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
              error: (e, s) =>
                  const Center(child: Text('Depo tipi detaylari alinamadi.')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Deponun Alabildigi Urunler',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (val) => setState(() => _searchQuery = val),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Urun ara...',
        hintStyle: TextStyle(color: AppColors.textMuted),
        prefixIcon: const Icon(Icons.search, color: AppColors.gold),
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15.r),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildProductList(
    List<ProductModel> allProducts,
    Map<String, dynamic> typeDetail,
  ) {
    final acceptedIds = _parseAcceptedProductIds(
      typeDetail['accepted_product_ids'],
    );

    final filtered = allProducts.where((p) {
      if (acceptedIds.isEmpty) return true;
      return acceptedIds.contains(_normalizeProductId(p.id));
    }).where((p) {
      if (_searchQuery.isEmpty) return true;
      return p.urunAdi.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              color: AppColors.textMuted,
              size: 48.sp,
            ),
            SizedBox(height: 16.h),
            Text(
              'Bu depo tipi icin uygun urun bulunamadi.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final product = filtered[index];
        return ListTile(
          onTap: () => _openMarketForProduct(product),
          contentPadding: EdgeInsets.symmetric(vertical: 8.h),
          leading: Container(
            width: 50.w,
            height: 50.w,
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: CachedAssetImage(
              fileName: product.urunIconu,
              fit: BoxFit.contain,
            ),
          ),
          title: Text(
            product.urunAdi,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            'Birim Hacim: ${product.birimHacim} m3',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
          ),
          trailing: SizedBox(
            width: 86.w,
            child: OutlinedButton(
              onPressed: () => _openMarketForProduct(product),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: AppColors.gold.withValues(alpha: 0.6),
                  width: 1.w,
                ),
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              child: Text(
                'Pazar',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<String> _parseAcceptedProductIds(dynamic rawValue) {
    if (rawValue == null) return const [];

    final cleaned = rawValue
        .toString()
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll('"', '')
        .replaceAll("'", '');

    return cleaned
        .split(',')
        .map((e) => _normalizeProductId(e))
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _normalizeProductId(String value) {
    return value.trim().toUpperCase();
  }

  void _openMarketForProduct(ProductModel product) {
    Navigator.pop(context);
    context.push(
      Uri(
        path: '/market/${product.id}',
        queryParameters: {
          'warehouseId': widget.warehouse.id,
          'playerId': widget.warehouse.playerId,
          'cityId': widget.warehouse.cityId,
        },
      ).toString(),
    );
  }
}
