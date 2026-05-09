import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';

class StoreDetailScreen extends ConsumerWidget {
  final String storeId;

  const StoreDetailScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(storeDetailProvider(storeId));
    final playerAsync = ref.watch(playerStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: storeAsync.when(
          data: (store) =>
              _buildMainContent(context, ref, store, playerAsync.value),
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          ),
          error: (e, s) => _buildErrorState(ref, e),
        ),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    dynamic player,
  ) {
    return Column(
      children: [
        SecondaryTopBar(title: 'Mağaza Yönetimi'),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 10.h),
                _buildStoreHeader(store),
                SizedBox(height: 16.h),
                _buildMainActionButtons(context, ref, store),
                SizedBox(height: 16.h),
                _buildSlotList(context, ref, store),
                SizedBox(height: 24.h),
                _buildFinancialFooter(store),
                SizedBox(height: 32.h),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStoreHeader(StoreModel store) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            children: [
              // Mağaza İkonu (Görseldeki gibi hafif taşan ve gölgeli)
              Container(
                width: 110.w,
                height: 110.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.2),
                      blurRadius: 15,
                      spreadRadius: -5,
                    ),
                  ],
                ),
                child: CachedAssetImage(
                  fileName: store.storeType.icon,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(width: 16.w),
              // Bilgiler
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            store.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildLevelBadge(store.level),
                      ],
                    ),
                    Text(
                      'Aktif İşletme',
                      style: TextStyle(
                        color: AppColors.green,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    _buildHeaderInfoRow(
                      'Şehir:',
                      store.cityName ?? 'Bilinmiyor',
                    ),
                    _buildHeaderInfoRow('Mağaza Tipi:', store.storeType.name),
                    _buildHeaderInfoRow(
                      'Günlük Kâr:',
                      '+${_formatValue(store.summary.totalStockSaleValue ?? 0)}',
                      valueColor: AppColors.green,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(StoreModel store) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSummaryItem(
            Icons.inventory_2,
            'Stok',
            '${store.summary.totalQuantity}/${store.summary.totalCapacity}',
            showProgress: true,
            progress: store.summary.usedCapacityRatio,
          ),
          _buildVerticalDivider(),
          _buildSummaryItem(
            Icons.pie_chart,
            'Doluluk',
            '%${(store.summary.usedCapacityRatio * 100).toInt()}',
            valueColor: AppColors.gold,
          ),
          _buildVerticalDivider(),
          _buildSummaryItem(
            Icons.grid_view,
            'Slot',
            '${store.slots.length}/${store.maxSlotCount}',
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionButtons(BuildContext context, WidgetRef ref, StoreModel store) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            Icons.trending_up,
            'Yükselt',
            AppColors.gold,
            onTap: () {
              // TODO: Yükseltme mantığı
            },
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _buildActionButton(
            Icons.bar_chart,
            'Rapor',
            AppColors.blue,
            onTap: () {
              // TODO: Rapor ekranına git
            },
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _buildActionButton(
            Icons.add_box,
            'Slot Aç',
            AppColors.gold,
            onTap: () => _handleOpenSlot(context, ref, store),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _buildActionButton(
            Icons.history,
            'Geçmiş',
            AppColors.textPrimary,
            onTap: () {
              // TODO: Geçmiş ekranına git
            },
          ),
        ),
      ],
    );
  }

  Future<void> _handleOpenSlot(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
  ) async {
    // ScaffoldMessenger.of(context).showSnackBar(
    //   const SnackBar(content: Text('Slot açılıyor...')),
    // );

    final result =
        await ref.read(storeActionProvider).addStoreSlot(store.id);

    if (context.mounted) {
      if (result['success'] == true) {
        // Veritabanının güncellenmesi için çok kısa bir süre bekle (Race condition önleyici)
        await Future.delayed(const Duration(milliseconds: 500));
        ref.refresh(storeDetailProvider(store.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yeni slot başarıyla açıldı!'),
            backgroundColor: AppColors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Slot açılırken bir hata oluştu.'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Widget _buildSlotList(BuildContext context, WidgetRef ref, StoreModel store) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10.h,
        crossAxisSpacing: 10.w,
        childAspectRatio: 0.85, // Butonlar için biraz daha uzun kartlar
      ),
      itemCount: store.slots.length,
      itemBuilder: (context, index) {
        return _buildProductSlotCard(
          context,
          ref,
          store,
          index + 1,
          store.slots[index],
        );
      },
    );
  }

  Widget _buildProductSlotCard(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    int index,
    StoreSlotModel slot,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.cardBg, AppColors.cardBg.withValues(alpha: 0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Stack(
        children: [
          // 1. ANA İKON (Arka Planı Doldurur)
          Positioned.fill(
            child: Opacity(
              opacity: slot.isEmpty ? 1.0 : 0.5,
              child: Align(
                alignment: slot.isEmpty 
                    ? const Alignment(0, 0) 
                    : const Alignment(0, -1.2), // Doluyken yukarı kaydır
                child: slot.isEmpty
                    ? Icon(Icons.add_shopping_cart,
                        color: AppColors.gold.withValues(alpha: 0.15), size: 60.sp)
                    : CachedAssetImage(
                        fileName: slot.productIcon ?? 'default',
                        fit: BoxFit.contain,
                      ),
              ),
            ),
          ),

          // 2. KALİTE (Sol Üst - Renkli Segmentli Bar)
          if (!slot.isEmpty)
            Positioned(
              top: 6,
              left: 6,
              child: Builder(
                builder: (context) {
                  final qColor = slot.qualityLevel <= 1 
                      ? AppColors.red 
                      : slot.qualityLevel <= 2 
                          ? Colors.orange 
                          : slot.qualityLevel <= 3 
                              ? Colors.yellow 
                              : slot.qualityLevel <= 4 
                                  ? Colors.lightGreen 
                                  : AppColors.green;
                                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KALİTE',
                        style: TextStyle(
                          color: qColor.withValues(alpha: 0.8),
                          fontSize: 8.sp,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Row(
                        children: List.generate(5, (index) {
                          return Container(
                            width: 8.w,
                            height: 4.h,
                            margin: EdgeInsets.only(right: 2.w),
                            decoration: BoxDecoration(
                              color: index < slot.qualityLevel 
                                  ? qColor 
                                  : Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(1.r),
                              boxShadow: index < slot.qualityLevel ? [
                                BoxShadow(
                                  color: qColor.withValues(alpha: 0.4),
                                  blurRadius: 3,
                                )
                              ] : null,
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                }
              ),
            ),

          // 3. FİYAT VE KALEM (Sağ Üst - Chip Tasarımı)
          if (!slot.isEmpty)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6.r),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${slot.price?.toStringAsFixed(1) ?? '0'}₺',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    GestureDetector(
                      onTap: () {
                        // Fiyat düzenleme diyaloğu açılabilir
                      },
                      child: Icon(
                        Icons.edit,
                        color: AppColors.gold.withValues(alpha: 0.8),
                        size: 10.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 4. ÜRÜN İSMİ (Alt Ortaya Yakın)
          if (!slot.isEmpty)
            Positioned(
              left: 4,
              right: 4,
              bottom: 58.h,
              child: Text(
                slot.productName ?? '',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
            ),

          // 5. STOK/PROGRESS BAR (Butonların Üstü)
          if (!slot.isEmpty)
            Positioned(
              left: 6,
              right: 6,
              bottom: 40.h,
              child: _buildMiniProgress(
                slot.quantity / (slot.capacity > 0 ? slot.capacity : 1),
                '${slot.quantity}/${slot.capacity}',
              ),
            ),

          // 6. BUTONLAR (Ekle / Çıkar)
          if (!slot.isEmpty)
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Row(
                children: [
                  Expanded(
                    child: _buildSmallButton(
                      'Ekle',
                      AppColors.green,
                      onTap: () => _showAddStockDialog(context, ref, store, slot),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: _buildSmallButton(
                      'Çıkar',
                      AppColors.red,
                      onTap: () {
                        // Stok çıkarma veya ürün kaldırma
                      },
                    ),
                  ),
                ],
              ),
            ),

          // 7. TIKLAMA ALANI (Boşsa ekleme)
          if (slot.isEmpty)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16.r),
                  onTap: () => _showProductSelectionDialog(context, ref, store, slot),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 50.h),
                      child: Text(
                        'Ürün Ekle',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.sp,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSmallButton(String label, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 10.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStatus(bool isActive) {
    return Container(
      width: 8.w,
      height: 8.w,
      decoration: BoxDecoration(
        color: isActive ? AppColors.green : AppColors.red,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (isActive ? AppColors.green : AppColors.red).withValues(alpha: 0.5),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  void _showProductSelectionDialog(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 40.h),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.inventory, color: AppColors.gold),
                      SizedBox(width: 12.w),
                      Text(
                        'Ürün Seçimi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Product List
                Flexible(
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: ref
                        .read(storeActionProvider)
                        .getAvailableProductsForStore(store.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(color: AppColors.gold),
                          ),
                        );
                      }

                      if (snapshot.hasError ||
                          snapshot.data?['success'] != true) {
                        return Padding(
                          padding: EdgeInsets.all(20.w),
                          child: Text(
                            'Ürünler yüklenirken hata oluştu: ${snapshot.data?['message'] ?? 'Bilinmeyen hata'}',
                            style: const TextStyle(color: AppColors.red),
                          ),
                        );
                      }

                      final List<dynamic> products =
                          snapshot.data?['products'] ?? [];

                      if (products.isEmpty) {
                        return Padding(
                          padding: EdgeInsets.all(40.w),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline,
                                  color: AppColors.textMuted, size: 48.sp),
                              SizedBox(height: 16.h),
                              Text(
                                'Bu mağaza için uygun veya eklenmemiş ürün bulunamadı.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.all(16.w),
                        itemCount: products.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: 10.h),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return _buildProductSelectionItem(
                            context,
                            ref,
                            store,
                            slot,
                            product,
                          );
                        },
                      );
                    },
                  ),
                ),
                SizedBox(height: 16.h),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductSelectionItem(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    Map<String, dynamic> product,
  ) {
    return GestureDetector(
      onTap: () => _handleProductSelection(context, ref, store, slot, product),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 50.w,
              height: 50.w,
              child: CachedAssetImage(
                fileName: product['icon'] ?? 'default',
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] ?? 'Bilinmeyen Ürün',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Baz Fiyat: ${product['base_price']}₺',
                    style: TextStyle(
                      color: AppColors.gold.withValues(alpha: 0.7),
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.add_circle, color: AppColors.gold, size: 24.sp),
          ],
        ),
      ),
    );
  }

  Future<void> _handleProductSelection(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    Map<String, dynamic> product,
  ) async {
    // Dialog'u kapat
    Navigator.pop(context);

    // İşlemi yap
    final result = await ref.read(storeActionProvider).setStoreSlotProduct(
          slotId: slot.id,
          productId: product['id'],
        );

    if (context.mounted) {
      if (result['success'] == true) {
        // Veritabanının güncellenmesi için çok kısa bir süre bekle (Race condition önleyici)
        await Future.delayed(const Duration(milliseconds: 500));
        ref.refresh(storeDetailProvider(store.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product['name']} başarıyla eklendi!'),
            backgroundColor: AppColors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Ürün eklenirken hata oluştu.'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Widget _buildFinancialFooter(StoreModel store) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildFooterStat(
            Icons.payments,
            'Bugünkü Satış',
            '+${_formatValue(38600)}',
            AppColors.green,
          ),
          _buildFooterStat(
            Icons.pending_actions,
            'Bekleyen Talep',
            '23',
            AppColors.gold,
          ),
          _buildFooterStat(
            Icons.trending_up,
            'Saatlik Satış',
            '4.8K',
            AppColors.blue,
          ),
          _buildFooterStat(
            Icons.percent,
            'Ortalama Marj',
            '%24.7',
            AppColors.gold,
          ),
        ],
      ),
    );
  }

  // HELPER WIDGETS
  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.borderGold.withValues(alpha: 0.3),
          ),
        ),
        child: Icon(icon, color: AppColors.gold, size: 20.sp),
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14.sp),
          SizedBox(width: 4.w),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 4.w),
          Icon(Icons.add, color: AppColors.gold, size: 12.sp),
        ],
      ),
    );
  }

  Widget _buildLevelBadge(int level) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.goldDark, AppColors.gold],
        ),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        'Lv. $level',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildHeaderInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            color: AppColors.gold,
            size: 14.sp,
          ), // Just for icon consistency
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    IconData icon,
    String label,
    String value, {
    bool showProgress = false,
    double progress = 0,
    Color? valueColor,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.gold, size: 12.sp),
              SizedBox(width: 4.w),
              Text(
                label,
                style: TextStyle(color: AppColors.textMuted, fontSize: 9.sp),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (showProgress) ...[
            SizedBox(height: 3.h),
            _buildMiniProgress(progress),
          ],
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 30.h,
      color: AppColors.border.withValues(alpha: 0.3),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16.sp),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4.w,
          height: 16.h,
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildQualityBadge(int level) {
    return Container(
      margin: EdgeInsets.only(top: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
      ),
      child: Text(
        'Kalite $level',
        style: TextStyle(
          color: Colors.blue,
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPriceBadge(double price) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Satış Fiyatı',
            style: TextStyle(color: AppColors.textMuted, fontSize: 9.sp),
          ),
          SizedBox(width: 6.w),
          Icon(Icons.monetization_on, color: AppColors.gold, size: 12.sp),
          SizedBox(width: 2.w),
          Text(
            '${price.toStringAsFixed(1)}₺',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTag(bool isActive) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.green.withValues(alpha: 0.1)
            : AppColors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(
          color: isActive
              ? AppColors.green.withValues(alpha: 0.5)
              : AppColors.red.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        isActive ? 'Aktif' : 'Pasif',
        style: TextStyle(
          color: isActive ? AppColors.green : AppColors.red,
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMiniProgress(double progress, [String? text]) {
    return Container(
      width: 90.w,
      height: 14.h,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Progress Fill
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.goldDark, AppColors.gold.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(3.r),
                ),
              ),
            ),
          ),
          // Text (Sadece verilmişse gösterilir)
          if (text != null)
            Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: 9.sp,
                fontWeight: FontWeight.bold,
                shadows: const [
                  Shadow(color: Colors.black87, blurRadius: 2),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooterStat(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16.sp),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(color: AppColors.textMuted, fontSize: 9.sp),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildGridAction(IconData icon, String label) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.gold, size: 24.sp),
          SizedBox(height: 4.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(WidgetRef ref, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.red, size: 48),
          SizedBox(height: 16.h),
          Text(
            'Bir hata oluştu: $error',
            style: const TextStyle(color: Colors.white),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () => ref.refresh(storeDetailProvider(storeId)),
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  String _formatValue(dynamic amount) {
    if (amount == null) return '0';
    double val = double.parse(amount.toString());
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}K';
    return val.toStringAsFixed(1);
  }
  // --- STOK EKLEME (EKLE BUTONU) MANTIĞI ---

  void _showAddStockDialog(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
  ) async {
    // Yükleniyor göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
    );

    final result = await ref.read(storeActionProvider).getEligibleWarehousesForStock(
          productId: slot.productId!,
          cityId: store.cityId!,
        );

    if (context.mounted) Navigator.pop(context);

    if (result['success'] == true) {
      final List<dynamic> warehouses = result['warehouses'];
      if (warehouses.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bu şehirde bu ürünü içeren uygun deponuz bulunamadı.')),
          );
        }
        return;
      }

      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.background,
          isScrollControlled: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
          builder: (context) => _buildWarehouseSelectionSheet(context, ref, store, slot, warehouses),
        );
      }
    }
  }

  Widget _buildWarehouseSelectionSheet(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    List<dynamic> warehouses,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kaynak Depo Seçin',
            style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4.h),
          Text(
            '${slot.productName} gönderilecek depoyu seçin',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
          ),
          SizedBox(height: 16.h),
          Expanded(
            child: ListView.builder(
              itemCount: warehouses.length,
              itemBuilder: (context, index) {
                final w = warehouses[index];
                final wSlots = w['warehouse_slots'] as List<dynamic>;
                final productSlot = wSlots.firstWhere((s) => s['product_id'] == slot.productId);
                final availableQty = productSlot['quantity'] as int;

                return Card(
                  color: Colors.white.withValues(alpha: 0.05),
                  margin: EdgeInsets.only(bottom: 10.h),
                  child: ListTile(
                    leading: Icon(Icons.warehouse, color: AppColors.gold),
                    title: Text(w['name'], style: const TextStyle(color: Colors.white)),
                    subtitle: Text('Mevcut: $availableQty adet', style: TextStyle(color: AppColors.gold.withValues(alpha: 0.7))),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                    onTap: () {
                      Navigator.pop(context);
                      _showQuantityTransferDialog(context, ref, store, slot, productSlot['id'], availableQty);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showQuantityTransferDialog(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    String warehouseSlotId,
    int availableQty,
  ) {
    final TextEditingController controller = TextEditingController(text: '1');
    final maxCanTake = slot.capacity - slot.quantity;
    final limit = availableQty < maxCanTake ? availableQty : maxCanTake.toInt();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text('Miktar Girin', style: TextStyle(color: Colors.white, fontSize: 18.sp)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${slot.productName} Transferi',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14.sp),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Miktar (Maks: $limit)',
                labelStyle: const TextStyle(color: AppColors.gold),
                enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.gold)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            onPressed: () async {
              final qty = int.tryParse(controller.text) ?? 0;
              if (qty <= 0 || qty > limit) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçersiz miktar!')));
                return;
              }
              Navigator.pop(context);
              _executeTransfer(context, ref, store, warehouseSlotId, slot.id, qty);
            },
            child: const Text('Transfer Et', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _executeTransfer(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    String wSlotId,
    String sSlotId,
    int qty,
  ) async {
    final result = await ref.read(storeActionProvider).transferStockToStore(
          warehouseSlotId: wSlotId,
          storeSlotId: sSlotId,
          quantity: qty,
        );

    if (context.mounted) {
      if (result['success'] == true) {
        await Future.delayed(const Duration(milliseconds: 500));
        ref.refresh(storeDetailProvider(store.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transfer başarıyla tamamlandı!'), backgroundColor: AppColors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${result['message']}'), backgroundColor: AppColors.red),
        );
      }
    }
  }
}
