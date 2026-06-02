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

List<ProductModel> resolveAcceptedProducts(
  List<String> acceptedIds,
  List<ProductModel> products,
) {
  if (acceptedIds.isEmpty) return const [];

  final productById = {
    for (final product in products) product.id.trim().toUpperCase(): product,
  };

  return acceptedIds
      .map((id) => productById[id])
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
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 10.sp,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 8.h),
        SizedBox(
          height: 106.h,
          child: GridView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8.w,
              crossAxisSpacing: 8.h,
              childAspectRatio: 2.9,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28.w,
                      height: 28.w,
                      padding: EdgeInsets.all(4.w),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: CachedAssetImage(
                        fileName: product.urunIconu,
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        product.urunAdi,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                        ),
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
