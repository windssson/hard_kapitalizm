import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';

List<String> parseAcceptedProductIds(dynamic rawValue) {
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
      .map((e) => e.trim().toUpperCase())
      .where((e) => e.isNotEmpty)
      .toList();
}

String _normalizeProductId(String value) {
  return value
      .trim()
      .toUpperCase()
      .replaceAll('\u0130', 'I')
      .replaceAll('I\u0307', 'I')
      .replaceAll('\u011E', 'G')
      .replaceAll('\u00DC', 'U')
      .replaceAll('\u015E', 'S')
      .replaceAll('\u00D6', 'O')
      .replaceAll('\u00C7', 'C');
}

List<ProductModel> resolveAcceptedProducts(
  List<String> acceptedIds,
  List<ProductModel> products,
) {
  if (acceptedIds.isEmpty) return const [];

  final productById = <String, ProductModel>{};
  for (final product in products) {
    final rawId = product.id.trim().toUpperCase();
    productById[rawId] = product;
    productById[_normalizeProductId(rawId)] = product;
  }

  return acceptedIds
      .map(
        (id) =>
            productById[id.trim().toUpperCase()] ??
            productById[_normalizeProductId(id)],
      )
      .whereType<ProductModel>()
      .toList();
}

class TypeProductPreview extends StatelessWidget {
  final String title;
  final List<ProductModel> products;

  const TypeProductPreview({
    super.key,
    required this.title,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Text(
        'Bu tur icin urun listesi bulunamadi.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 6.h),
        SizedBox(
          height: 78.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: products.length,
            separatorBuilder: (_, __) => SizedBox(width: 8.w),
            itemBuilder: (context, index) {
              final product = products[index];
              return Container(
                width: 58.w,
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9.r),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CachedAssetImage(
                      fileName: product.urunIconu.isEmpty
                          ? 'default.webp'
                          : product.urunIconu,
                      width: 38.w,
                      height: 38.w,
                      fit: BoxFit.contain,
                      placeholder: Icon(
                        Icons.inventory_2_rounded,
                        color: AppColors.gold.withValues(alpha: 0.65),
                        size: 20.sp,
                      ),
                      errorWidget: Icon(
                        Icons.inventory_2_rounded,
                        color: AppColors.gold,
                        size: 20.sp,
                      ),
                    ),
                    SizedBox(height: 5.h),
                    Text(
                      product.urunAdi,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 8.sp,
                        fontWeight: FontWeight.w600,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
