import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';

class PremiumStoreScreen extends ConsumerWidget {
  const PremiumStoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider).value;
    final goldCount = player?.gold ?? 0;

    final packages = [
      _GoldPackage(
        id: 'gold_100',
        name: 'Avuç Dolusu Altın',
        goldCount: 100,
        priceText: '1.99 \$',
        icon: Icons.monetization_on_outlined,
        color: const Color(0xFFCD7F32), // Bronze
      ),
      _GoldPackage(
        id: 'gold_500',
        name: 'Kese Dolusu Altın',
        goldCount: 500,
        priceText: '7.99 \$',
        icon: Icons.shopping_bag_rounded,
        badge: 'En Popüler',
        color: AppColors.gold,
      ),
      _GoldPackage(
        id: 'gold_1200',
        name: 'Sandık Dolusu Altın',
        goldCount: 1200,
        priceText: '14.99 \$',
        icon: Icons.inventory_2_rounded,
        badge: 'Tasarruf',
        color: AppColors.goldLight,
      ),
      _GoldPackage(
        id: 'gold_3000',
        name: 'Holding Hazine Kasası',
        goldCount: 3000,
        priceText: '29.99 \$',
        icon: Icons.lock_rounded,
        badge: 'Büyük Avantaj',
        color: AppColors.blue,
      ),
      _GoldPackage(
        id: 'gold_7500',
        name: 'İmparatorluk Rezervi',
        goldCount: 7500,
        priceText: '59.99 \$',
        icon: Icons.account_balance_rounded,
        badge: 'En İyi Oran',
        color: AppColors.green,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF030A14),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0C1D33),
              Color(0xFF050B14),
              Color(0xFF02050A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(context, goldCount),

              // Gold benefits note
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBenefitsBanner(),
                      SizedBox(height: 16.h),
                      Text(
                        'ALTIN PAKETLERI',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      // Packages list
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: packages.length,
                        separatorBuilder: (context, index) => SizedBox(height: 12.h),
                        itemBuilder: (context, index) {
                          return _buildPackageCard(context, packages[index]);
                        },
                      ),
                      SizedBox(height: 24.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, double goldCount) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: AppColors.borderGold.withValues(alpha: 0.25),
            width: 1.w,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20.sp),
            onPressed: () => context.pop(),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PREMIUM MAGAZA',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Holdinginizin Hızlı Büyüme Kaynağı',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Current gold display
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.45),
                width: 1.1.w,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.star_rounded, color: AppColors.gold, size: 16.sp),
                SizedBox(width: 4.w),
                Text(
                  goldCount.toStringAsFixed(0),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsBanner() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.borderGold.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.35),
              ),
            ),
            child: Icon(Icons.bolt_rounded, color: AppColors.gold, size: 22.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Premium Altın Avantajları',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Altın kullanarak lojistik transferlerinizi, bina inşaatlarını veya AR-GE araştırmalarını beklemeden anında tamamlayabilir ve kapitalist sistemde rakiplerinizin hemen önüne geçebilirsiniz.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(BuildContext context, _GoldPackage package) {
    final hasBadge = package.badge != null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: package.color.withValues(alpha: 0.42),
          width: hasBadge ? 1.4.w : 1.w,
        ),
        boxShadow: [
          if (hasBadge)
            BoxShadow(
              color: package.color.withValues(alpha: 0.08),
              blurRadius: 12.r,
              spreadRadius: 0.5.r,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.r),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF060F1A).withValues(alpha: 0.8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF091629).withValues(alpha: 0.8),
                const Color(0xFF03070E).withValues(alpha: 0.9),
              ],
            ),
          ),
          padding: EdgeInsets.all(14.w),
          child: Row(
            children: [
              // Package Icon Medallion
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: package.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: package.color.withValues(alpha: 0.35),
                    width: 1.2.w,
                  ),
                ),
                child: Icon(
                  package.icon,
                  color: package.color,
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 12.w),
              // Package details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          package.name,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (hasBadge) ...[
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                            decoration: BoxDecoration(
                              color: package.color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6.r),
                              border: Border.all(
                                color: package.color.withValues(alpha: 0.6),
                                width: 0.8.w,
                              ),
                            ),
                            child: Text(
                              package.badge!,
                              style: TextStyle(
                                color: package.color,
                                fontSize: 7.5.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, color: AppColors.gold, size: 14.sp),
                        SizedBox(width: 3.w),
                        Text(
                          '${package.goldCount.toString()} Altın / Yıldız',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Price and Action Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: package.color.withValues(alpha: 0.16),
                  foregroundColor: package.color,
                  shadowColor: Colors.black.withValues(alpha: 0.4),
                  elevation: 4,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    side: BorderSide(
                      color: package.color.withValues(alpha: 0.65),
                      width: 1.1.w,
                    ),
                  ),
                ),
                onPressed: () => _triggerPurchaseFlow(context, package),
                child: Text(
                  package.priceText,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _triggerPurchaseFlow(BuildContext context, _GoldPackage package) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 28.w),
          child: Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: const Color(0xFF06101B),
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(
                color: AppColors.borderGold.withValues(alpha: 0.55),
                width: 1.2.w,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 20.r,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52.w,
                  height: 52.w,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.45),
                      width: 1.2.w,
                    ),
                  ),
                  child: Icon(
                    Icons.shopping_cart_checkout_rounded,
                    color: AppColors.gold,
                    size: 26.sp,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'SATIN ALMA ISLEMI',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'Google Play Store bağlantısı hazırlanıyor...\n\nGoogle geliştirici hesabı entegrasyonu tamamlandığında, bu paket üzerinden ödeme onaylanarak hesabınıza anında ${package.goldCount} Altın yüklenecektir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
                SizedBox(height: 20.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                      shadowColor: AppColors.gold.withValues(alpha: 0.35),
                      elevation: 6,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        side: BorderSide(
                          color: AppColors.goldLight,
                          width: 1.w,
                        ),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'TAMAM',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GoldPackage {
  final String id;
  final String name;
  final int goldCount;
  final String priceText;
  final IconData icon;
  final String? badge;
  final Color color;

  const _GoldPackage({
    required this.id,
    required this.name,
    required this.goldCount,
    required this.priceText,
    required this.icon,
    this.badge,
    required this.color,
  });
}
