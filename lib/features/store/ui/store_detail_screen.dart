import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/market/models/market_transfer_vehicle_option_model.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';
import 'package:hard_kapitalizm/features/store/models/store_sale_result_model.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';

final storeSalesCheckDoneProvider = Provider.autoDispose.family<ValueNotifier<bool>, String>(
  (ref, storeId) => ValueNotifier<bool>(false),
);

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
          data: (store) {
            _scheduleStoreSalesCheck(context, ref, store);
            return _buildMainContent(context, ref, store, playerAsync.value);
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          ),
          error: (e, s) => _buildErrorState(ref, e),
        ),
      ),
    );
  }

  void _scheduleStoreSalesCheck(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
  ) {
    final salesCheckNotifier = ref.read(
      storeSalesCheckDoneProvider(store.id),
    );
    final alreadyChecked = salesCheckNotifier.value;
    if (alreadyChecked) return;
    salesCheckNotifier.value = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;

      final result = await ref
          .read(storeActionProvider)
          .processStoreSalesOnEntry(store.id);

      if (!context.mounted) {
        return;
      }

      if (result.success != true) {
        salesCheckNotifier.value = false;
        return;
      }

      if (result.processed) {
        ref.invalidate(storeDetailProvider(store.id));
        ref.invalidate(playerStreamProvider);
      }

      if (!result.processed || !result.hasVisibleSales) {
        return;
      }

      await _showStoreSalesSummaryDialog(context, result);
    });
  }

  Future<void> _showStoreSalesSummaryDialog(
    BuildContext context,
    StoreSaleResultModel result,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          'Satis Ozeti',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 420.h, maxWidth: 340.w),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSalesSummaryRow(
                  'Gecen Sure',
                  _formatElapsedSalesDuration(result.elapsedMinutes),
                ),
                _buildSalesSummaryRow(
                  'Satilan Adet',
                  result.totalSoldQuantity.toString(),
                ),
                _buildSalesSummaryRow(
                  'Toplam Ciro',
                  '${result.totalRevenue.toStringAsFixed(1)}',
                  valueColor: AppColors.green,
                ),
                _buildSalesSummaryRow(
                  'Toplam Kar',
                  '${result.totalProfit.toStringAsFixed(1)}',
                  valueColor: AppColors.gold,
                ),
                SizedBox(height: 14.h),
                Text(
                  'Urun Bazli Sonuc',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10.h),
                ...result.items.map(
                  (item) => Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(bottom: 10.h),
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'Slot ${item.slotIndex} | Kalite ${item.qualityLevel}',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11.sp,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Satilan: ${item.soldQuantity} | Tutar: ${item.revenue.toStringAsFixed(1)} | Kar: ${item.profit.toStringAsFixed(1)}',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesSummaryRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12.sp,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatElapsedSalesDuration(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainMinutes = minutes % 60;
      if (remainMinutes == 0) return '${hours}s';
      return '${hours}s ${remainMinutes}dk';
    }
    return '${minutes}dk';
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
              child: _buildMiniProgressStacked(
                slot.quantity / (slot.capacity > 0 ? slot.capacity : 1),
                text:
                    '${slot.quantity}+${slot.pendingQuantity}/${slot.capacity}',
                reservedProgress:
                    slot.pendingQuantity /
                    (slot.capacity > 0 ? slot.capacity : 1),
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
                      onTap: () => _startStoreTransferFlow(context, ref, store, slot),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: _buildSmallButton(
                      'Gönder',
                      AppColors.red,
                      onTap: () => _startStoreOutboundFlow(
                        context,
                        ref,
                        store,
                        slot,
                      ),
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
      onTap: () => _handleProductSelectionAndTransfer(context, ref, store, slot, product),
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

  Future<void> _handleProductSelectionAndTransfer(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    Map<String, dynamic> product,
  ) async {
    Navigator.pop(context);

    final preparedSlot = StoreSlotModel(
      id: slot.id,
      storeId: slot.storeId,
      slotIndex: slot.slotIndex,
      productId: (product['id'] ?? '').toString(),
      productName: (product['name'] ?? '').toString(),
      productIcon: (product['icon'] ?? 'default').toString(),
      quantity: slot.quantity,
      pendingQuantity: slot.pendingQuantity,
      qualityLevel: 0,
      price: slot.price,
      cost: slot.cost,
      capacity: slot.capacity,
      boostMultiplier: slot.boostMultiplier,
      pendingSale: slot.pendingSale,
      isActive: slot.isActive,
      isEmpty: false,
      usedCapacityRatio: slot.usedCapacityRatio,
      product: slot.product,
    );

    _startStoreTransferFlow(context, ref, store, preparedSlot);
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
    final productId = slot.productId;
    final cityId = store.cityId;

    if (productId == null || productId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Once gecerli bir urun secin.'),
            backgroundColor: AppColors.red,
          ),
        );
      }
      return;
    }

    if (cityId == null || cityId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Magaza sehri bulunamadi.'),
            backgroundColor: AppColors.red,
          ),
        );
      }
      return;
    }
    // Yükleniyor göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
    );

    final result = await ref.read(storeActionProvider).getEligibleWarehousesForStock(
          productId: productId,
          cityId: cityId,
          qualityLevel: slot.qualityLevel > 0 ? slot.qualityLevel : null,
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
                return Column(
                  children: wSlots.map<Widget>((productSlot) {
                    final availableQty = productSlot['quantity'] as int;
                    final qualityLevel =
                        (productSlot['quality_level'] as num?)?.toInt() ?? 1;

                    return Card(
                      color: Colors.white.withValues(alpha: 0.05),
                      margin: EdgeInsets.only(bottom: 10.h),
                      child: ListTile(
                        leading: Icon(Icons.warehouse, color: AppColors.gold),
                        title: Text(w['name'], style: const TextStyle(color: Colors.white)),
                        subtitle: Text(
                          'Kalite: $qualityLevel | Mevcut: $availableQty adet',
                          style: TextStyle(color: AppColors.gold.withValues(alpha: 0.7)),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                        onTap: () {
                          Navigator.pop(context);
                          _showQuantityTransferDialog(
                            context,
                            ref,
                            store,
                            slot,
                            productSlot['id'],
                            availableQty,
                            qualityLevel,
                          );
                        },
                      ),
                    );
                  }).toList(),
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
    int selectedQualityLevel,
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
              _executeTransfer(
                context,
                ref,
                store,
                slot,
                warehouseSlotId,
                qty,
                selectedQualityLevel,
              );
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
    StoreSlotModel slot,
    String wSlotId,
    int qty,
    int selectedQualityLevel,
  ) async {
    final needsSlotSetup =
        slot.productId == null || slot.qualityLevel != selectedQualityLevel;

    if (needsSlotSetup) {
      final productId = slot.productId;
      if (productId == null || productId.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transfer icin urun bilgisi bulunamadi.'),
              backgroundColor: AppColors.red,
            ),
          );
        }
        return;
      }

      final setupResult = await ref.read(storeActionProvider).setStoreSlotProduct(
            slotId: slot.id,
            productId: productId,
            qualityLevel: selectedQualityLevel,
          );

      if (context.mounted && setupResult['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: ${setupResult['message']}'),
            backgroundColor: AppColors.red,
          ),
        );
        return;
      }
    }

    final result = await ref.read(storeActionProvider).transferStockToStore(
          warehouseSlotId: wSlotId,
          storeSlotId: slot.id,
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

  void _startStoreTransferFlow(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
  ) {
    final productId = slot.productId;
    if (productId == null || productId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Once gecerli bir urun secin.'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kaynak Secin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                '${slot.productName ?? 'Urun'} icin tedarik kaynagini secin',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
              ),
              SizedBox(height: 16.h),
              _buildSourceChoiceTileV2(
                icon: Icons.warehouse_outlined,
                title: 'Depolarimdan',
                subtitle: 'Kendi depolarinizdan lojistik transfer baslatin',
                color: AppColors.gold,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openWarehouseSourceFlowV2(context, ref, store, slot);
                },
              ),
              SizedBox(height: 10.h),
              _buildSourceChoiceTileV2(
                icon: Icons.public,
                title: 'Pazardan',
                subtitle: 'Bu urunu global pazardan satin alin',
                color: AppColors.blue,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openMarketSourceFlowV2(context, store, slot);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniProgressStacked(
    double progress, {
    String? text,
    double reservedProgress = 0,
  }) {
    final stockRatio = progress.clamp(0.0, 1.0);
    final reserveRatio = reservedProgress.clamp(0.0, 1.0);

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
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3.r),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final stockWidth = totalWidth * stockRatio;
                  final reserveWidth = totalWidth * reserveRatio;

                  return Stack(
                    children: [
                      if (stockWidth > 0)
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: stockWidth,
                          child: Container(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      if (reserveWidth > 0)
                        Positioned(
                          left: stockWidth,
                          top: 0,
                          bottom: 0,
                          width: reserveWidth,
                          child: Container(
                            color: Colors.orange.withValues(alpha: 0.9),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
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

  Widget _buildSourceChoiceTileV2({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: color),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }

  bool _shouldLockStoreSlotQualityV2(StoreSlotModel slot) {
    return (slot.quantity > 0 || slot.pendingQuantity > 0) &&
        slot.qualityLevel > 0;
  }

  Future<void> _openWarehouseSourceFlowV2(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
  ) async {
    final productId = slot.productId;
    if (productId == null || productId.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      ),
    );

    final result = await ref.read(storeActionProvider).getEligibleWarehousesForStock(
          productId: productId,
          qualityLevel:
              _shouldLockStoreSlotQualityV2(slot) ? slot.qualityLevel : null,
        );

    if (context.mounted) Navigator.pop(context);

    if (result['success'] != true) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Depolar yuklenemedi.'),
            backgroundColor: AppColors.red,
          ),
        );
      }
      return;
    }

    final warehouses = result['warehouses'] as List<dynamic>? ?? const [];
    if (warehouses.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu urunu iceren uygun deponuz bulunamadi.'),
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) => _buildWarehouseSelectionSheetV2(
        sheetContext,
        ref,
        store,
        slot,
        warehouses,
      ),
    );
  }

  void _openMarketSourceFlowV2(
    BuildContext context,
    StoreModel store,
    StoreSlotModel slot,
  ) {
    final productId = slot.productId;
    if (productId == null || productId.isEmpty) return;

    context.push(
      Uri(
        path: '/market/$productId',
        queryParameters: {
          'targetType': 'store',
          'storeId': store.id,
          'storeSlotId': slot.id,
          'cityId': store.cityId ?? '',
          'playerId': '',
        },
      ).toString(),
    );
  }

  Widget _buildWarehouseSelectionSheetV2(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    List<dynamic> warehouses,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kaynak Depo Secin',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '${slot.productName} gonderecek depoyu secin',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
          ),
          SizedBox(height: 16.h),
          Expanded(
            child: ListView.builder(
              itemCount: warehouses.length,
              itemBuilder: (context, index) {
                final warehouse = warehouses[index];
                final warehouseSlots =
                    warehouse['warehouse_slots'] as List<dynamic>? ?? const [];
                return Column(
                  children: warehouseSlots.map<Widget>((productSlot) {
                    final availableQty =
                        (productSlot['quantity'] as num?)?.toInt() ?? 0;
                    final qualityLevel =
                        (productSlot['quality_level'] as num?)?.toInt() ?? 1;
                    final cityName =
                        (warehouse['city']?['name'] ?? 'Bilinmeyen Sehir')
                            .toString();

                    return Card(
                      color: Colors.white.withValues(alpha: 0.05),
                      margin: EdgeInsets.only(bottom: 10.h),
                      child: ListTile(
                        leading: Icon(Icons.warehouse, color: AppColors.gold),
                        title: Text(
                          (warehouse['name'] ?? 'Depo').toString(),
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          '$cityName | Kalite: $qualityLevel | Mevcut: $availableQty adet',
                          style: TextStyle(
                            color: AppColors.gold.withValues(alpha: 0.7),
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.white54,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _showQuantityTransferDialogV2(
                            context,
                            ref,
                            store,
                            slot,
                            productSlot['id'].toString(),
                            availableQty,
                            qualityLevel,
                            cityName,
                          );
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showQuantityTransferDialogV2(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    String warehouseSlotId,
    int availableQty,
    int selectedQualityLevel,
    String sourceCityName,
  ) {
    final controller = TextEditingController(text: '1');
    final maxCanTake = slot.capacity - slot.quantity - slot.pendingQuantity;
    final limit = availableQty < maxCanTake ? availableQty : maxCanTake.toInt();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          'Miktar Girin',
          style: TextStyle(color: Colors.white, fontSize: 18.sp),
        ),
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
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.gold),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            onPressed: () {
              final qty = int.tryParse(controller.text) ?? 0;
              if (qty <= 0 || qty > limit) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gecersiz miktar!')),
                );
                return;
              }
              Navigator.pop(context);
              _showVehicleSelectionSheetV2(
                context,
                ref,
                store,
                slot,
                warehouseSlotId,
                qty,
                selectedQualityLevel,
                sourceCityName,
              );
            },
            child: const Text(
              'Devam Et',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showVehicleSelectionSheetV2(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    String warehouseSlotId,
    int quantity,
    int selectedQualityLevel,
    String sourceCityName,
  ) async {
    final isSameCity =
        (store.cityName ?? '').trim().toLowerCase() ==
        sourceCityName.trim().toLowerCase();

    if (isSameCity) {
      _startWarehouseTransferV2(
        context,
        ref,
        store,
        slot,
        warehouseSlotId,
        quantity,
        selectedQualityLevel,
        null,
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      ),
    );

    List<MarketTransferVehicleOptionModel> options = const [];
    try {
      options = await ref.read(storeActionProvider).getStoreTransferVehicleOptions(
            storeSlotId: slot.id,
            warehouseSlotId: warehouseSlotId,
            quantity: quantity,
          );
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Araclar alinamadi: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
      return;
    }

    if (context.mounted) Navigator.pop(context);

    if (options.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu transfer icin uygun arac bulunamadi.'),
            backgroundColor: AppColors.red,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) => Container(
        padding: EdgeInsets.all(16.w),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Arac Secin',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              '$quantity adet urun icin uygun araci secin',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: ListView.separated(
                itemCount: options.length,
                separatorBuilder: (_, __) => SizedBox(height: 10.h),
                itemBuilder: (_, index) {
                  final option = options[index];
                  final color =
                      option.canSelect ? AppColors.green : AppColors.red;
                  return InkWell(
                    onTap: option.canSelect
                        ? () {
                            Navigator.pop(sheetContext);
                            _startWarehouseTransferV2(
                              context,
                              ref,
                              store,
                              slot,
                              warehouseSlotId,
                              quantity,
                              selectedQualityLevel,
                              option.vehicleId,
                            );
                          }
                        : null,
                    borderRadius: BorderRadius.circular(14.r),
                    child: Container(
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(color: color.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_shipping, color: color),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Text(
                                  option.vehicleName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                option.isRental ? 'Kiralik' : 'Kendi',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'Kapasite: ${option.capacity} | Mesafe: ${option.distanceKm.toStringAsFixed(0)} km | Sure: ${_formatTransferDurationV2(option.estimatedDurationSeconds)}',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11.sp,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Yakit: ${option.fuelNeeded.toStringAsFixed(0)} | Kondisyon: ${option.conditionNeeded.toStringAsFixed(0)} | Kira: ${option.rentalCost.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11.sp,
                            ),
                          ),
                          if (!option.canSelect &&
                              option.disabledReason != null) ...[
                            SizedBox(height: 6.h),
                            Text(
                              option.disabledReason!,
                              style: TextStyle(
                                color: AppColors.red,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTransferDurationV2(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) return '${hours}s ${minutes}dk';
    return '${duration.inMinutes}dk';
  }

  Future<void> _startWarehouseTransferV2(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    String warehouseSlotId,
    int quantity,
    int selectedQualityLevel,
    String? vehicleId,
  ) async {
    final productId = slot.productId;
    final needsSlotSetup =
        !_shouldLockStoreSlotQualityV2(slot) &&
        productId != null &&
        productId.isNotEmpty &&
        (slot.productId == null || slot.qualityLevel != selectedQualityLevel);

    if (needsSlotSetup) {
      final setupResult = await ref.read(storeActionProvider).setStoreSlotProduct(
            slotId: slot.id,
            productId: productId,
            qualityLevel: selectedQualityLevel,
          );

      if (setupResult['success'] != true) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: ${setupResult['message']}'),
            backgroundColor: AppColors.red,
          ),
        );
        return;
      }
    }

    final result = await ref.read(storeActionProvider).startWarehouseToStoreTransfer(
          storeSlotId: slot.id,
          warehouseSlotId: warehouseSlotId,
          quantity: quantity,
          vehicleId: vehicleId,
        );

    if (!context.mounted) return;

    if (result['success'] == true) {
      await Future.delayed(const Duration(milliseconds: 300));
      ref.invalidate(storeDetailProvider(store.id));
      final isInstant = result['mode']?.toString() == 'instant';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isInstant
                ? 'Ayni sehir transferi aninda tamamlandi.'
                : 'Transfer baslatildi. Arac yola cikti.',
          ),
          backgroundColor: AppColors.green,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Hata: ${result['message']}'),
        backgroundColor: AppColors.red,
      ),
    );
  }

  Future<void> _startStoreOutboundFlow(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
  ) async {
    if ((slot.quantity) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gonderilecek stok bulunmuyor.'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      ),
    );

    List<Map<String, dynamic>> warehouses = const [];
    try {
      warehouses = await ref.read(storeActionProvider).getPlayerWarehouses();
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Depolar alinamadi: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
      return;
    }

    if (context.mounted) Navigator.pop(context);

    if (warehouses.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uygun hedef deponuz bulunamadi.'),
            backgroundColor: AppColors.red,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) => _buildOutboundWarehouseSheet(
        sheetContext,
        ref,
        store,
        slot,
        warehouses,
      ),
    );
  }

  Widget _buildOutboundWarehouseSheet(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    List<Map<String, dynamic>> warehouses,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hedef Depo Secin',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '${slot.productName ?? 'Urun'} gondereceginiz depoyu secin',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
          ),
          SizedBox(height: 16.h),
          Expanded(
            child: ListView.separated(
              itemCount: warehouses.length,
              separatorBuilder: (_, __) => SizedBox(height: 10.h),
              itemBuilder: (context, index) {
                final warehouse = warehouses[index];
                final cityName =
                    (warehouse['city']?['name'] ?? 'Bilinmeyen Sehir')
                        .toString();

                return Card(
                  color: Colors.white.withValues(alpha: 0.05),
                  child: ListTile(
                    leading: Icon(Icons.warehouse, color: AppColors.gold),
                    title: Text(
                      (warehouse['name'] ?? 'Depo').toString(),
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      cityName,
                      style: TextStyle(
                        color: AppColors.gold.withValues(alpha: 0.7),
                      ),
                    ),
                    trailing:
                        const Icon(Icons.chevron_right, color: Colors.white54),
                    onTap: () {
                      Navigator.pop(context);
                      _showOutboundQuantityDialog(
                        context,
                        ref,
                        store,
                        slot,
                        warehouse,
                        cityName,
                      );
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

  void _showOutboundQuantityDialog(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    Map<String, dynamic> warehouse,
    String warehouseCityName,
  ) {
    final controller = TextEditingController(text: '1');
    final limit = slot.quantity;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          'Miktar Girin',
          style: TextStyle(color: Colors.white, fontSize: 18.sp),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${slot.productName} -> ${(warehouse['name'] ?? 'Depo').toString()}',
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
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.gold),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            onPressed: () {
              final qty = int.tryParse(controller.text) ?? 0;
              if (qty <= 0 || qty > limit) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gecersiz miktar!')),
                );
                return;
              }
              Navigator.pop(context);
              _maybeStartStoreOutboundTransfer(
                context,
                ref,
                store,
                slot,
                warehouse,
                warehouseCityName,
                qty,
              );
            },
            child: const Text(
              'Devam Et',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _maybeStartStoreOutboundTransfer(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    Map<String, dynamic> warehouse,
    String warehouseCityName,
    int quantity,
  ) async {
    final sameCity =
        ((store.cityId ?? '').isNotEmpty &&
            store.cityId == (warehouse['city_id']?.toString() ?? '')) ||
        (store.cityId == null &&
            (store.cityName ?? '').trim().toLowerCase() ==
                warehouseCityName.trim().toLowerCase());

    if (sameCity) {
      await _startStoreOutboundTransfer(
        context,
        ref,
        store,
        slot,
        warehouse['id'].toString(),
        quantity,
        null,
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      ),
    );

    List<MarketTransferVehicleOptionModel> options = const [];
    try {
      options = await ref.read(storeActionProvider).getStoreToWarehouseVehicleOptions(
            storeSlotId: slot.id,
            warehouseId: warehouse['id'].toString(),
            quantity: quantity,
          );
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Araclar alinamadi: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
      return;
    }

    if (context.mounted) Navigator.pop(context);

    if (options.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu transfer icin uygun arac bulunamadi.'),
            backgroundColor: AppColors.red,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) => Container(
        padding: EdgeInsets.all(16.w),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Arac Secin',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              '$quantity adet urun icin uygun araci secin',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: ListView.separated(
                itemCount: options.length,
                separatorBuilder: (_, __) => SizedBox(height: 10.h),
                itemBuilder: (_, index) {
                  final option = options[index];
                  final color =
                      option.canSelect ? AppColors.green : AppColors.red;
                  return InkWell(
                    onTap: option.canSelect
                        ? () {
                            Navigator.pop(sheetContext);
                            _startStoreOutboundTransfer(
                              context,
                              ref,
                              store,
                              slot,
                              warehouse['id'].toString(),
                              quantity,
                              option.vehicleId,
                            );
                          }
                        : null,
                    borderRadius: BorderRadius.circular(14.r),
                    child: Container(
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(color: color.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_shipping, color: color),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Text(
                                  option.vehicleName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                option.isRental ? 'Kiralik' : 'Kendi',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'Kapasite: ${option.capacity} | Mesafe: ${option.distanceKm.toStringAsFixed(0)} km | Sure: ${_formatTransferDurationV2(option.estimatedDurationSeconds)}',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11.sp,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Yakit: ${option.fuelNeeded.toStringAsFixed(0)} | Kondisyon: ${option.conditionNeeded.toStringAsFixed(0)} | Kira: ${option.rentalCost.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11.sp,
                            ),
                          ),
                          if (!option.canSelect &&
                              option.disabledReason != null) ...[
                            SizedBox(height: 6.h),
                            Text(
                              option.disabledReason!,
                              style: TextStyle(
                                color: AppColors.red,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startStoreOutboundTransfer(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    String warehouseId,
    int quantity,
    String? vehicleId,
  ) async {
    final result = await ref.read(storeActionProvider).startStoreToWarehouseTransfer(
          storeSlotId: slot.id,
          warehouseId: warehouseId,
          quantity: quantity,
          vehicleId: vehicleId,
        );

    if (!context.mounted) return;

    if (result['success'] == true) {
      await Future.delayed(const Duration(milliseconds: 300));
      ref.invalidate(storeDetailProvider(store.id));
      final isInstant = result['mode']?.toString() == 'instant';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isInstant
                ? 'Ayni sehir gonderimi aninda tamamlandi.'
                : 'Transfer baslatildi. Arac yola cikti.',
          ),
          backgroundColor: AppColors.green,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Hata: ${result['message']}'),
        backgroundColor: AppColors.red,
      ),
    );
  }
}
