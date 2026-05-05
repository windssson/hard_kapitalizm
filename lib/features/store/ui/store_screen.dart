import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  final int _selectedIndex = 1; // İşletmeler/Mağazalar index'i 1

  void _onNavSelected(int index) {
    if (index == _selectedIndex) return;
    
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 2:
        context.go('/store');
        break;
      case 4:
        context.go('/profile');
        break;
      // Diğer sayfalar (1: İşletmeler, 3: Raporlar) eklendikçe buraya eklenecek
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // DESIGN_SYSTEM.md kuralı
      body: SafeArea(
        child: Column(
          children: [
            const AppTopBar(), // ZORUNLU ÜST MENÜ
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mağazalar', style: AppTextStyles.h1),
                    SizedBox(height: 16.h),
                    _buildStoreList(),
                  ],
                ),
              ),
            ),
            AppBottomNav(
              selectedIndex: _selectedIndex,
              onItemSelected: _onNavSelected,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreList() {
    final mockStores = [
      {
        'name': 'Manav',
        'icon': 'manav.webp',
        'cost': '30.0K',
        'level': '1',
      },
      {
        'name': 'Market',
        'icon': 'market.webp',
        'cost': '60.0K',
        'level': '4',
      },
      {
        'name': 'Oto Galeri',
        'icon': 'otogaleri.webp',
        'cost': '12.0M',
        'level': '48',
      },
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: mockStores.length,
      itemBuilder: (context, index) {
        final store = mockStores[index];
        return Container(
          margin: EdgeInsets.only(bottom: 12.h),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.borderGold),
          ),
          child: Row(
            children: [
              // Mağaza Görseli
              Container(
                width: 60.w,
                height: 60.w,
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: CachedAssetImage(
                  fileName: store['icon']!,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(width: 16.w),
              // Mağaza Bilgileri
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store['name']!,
                      style: AppTextStyles.h2,
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(Icons.star, color: AppColors.gold, size: 14.sp),
                        SizedBox(width: 4.w),
                        Text(
                          'Seviye ${store['level']}',
                          style: AppTextStyles.body,
                        ),
                        SizedBox(width: 16.w),
                        Icon(Icons.attach_money, color: AppColors.green, size: 14.sp),
                        Text(
                          store['cost']!,
                          style: TextStyle(
                            color: AppColors.green,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Satın Al Butonu
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cardBgLight,
                  side: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                onPressed: () {},
                child: Text('Kur', style: AppTextStyles.titleGold),
              ),
            ],
          ),
        );
      },
    );
  }
}
