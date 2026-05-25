import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/navigation/route_refresh_mixin.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/construction_countdown_card.dart';
import 'package:hard_kapitalizm/core/widgets/gold_finish_button.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/mine/data/mine_provider.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_list_item_model.dart';

class MineScreen extends ConsumerStatefulWidget {
  const MineScreen({super.key});

  @override
  ConsumerState<MineScreen> createState() => _MineScreenState();
}

class _MineScreenState extends ConsumerState<MineScreen>
    with SingleTickerProviderStateMixin, RouteRefreshMixin<MineScreen> {
  final int _selectedIndex = 1;
  String _selectedFilter = 'Tumu';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => refreshRouteData());
  }

  @override
  void refreshRouteData() {
    ref.invalidate(mineListProvider);
    ref.invalidate(mineConstructionProvider);
    ref.read(mineListProvider.future);
    ref.read(mineConstructionProvider.future);
  }

  // Filtre seçenekleri
  static const _filters = ['Tümü', 'Aktif', 'Pasif'];

  void _onNavSelected(int index) {
    if (index == _selectedIndex) return;
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 2:
        context.go('/transfer-map');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  Future<void> _refreshAll() async {
    ref.invalidate(mineListProvider);
    ref.invalidate(mineConstructionProvider);
  }

  Future<void> _completeConstruction(String constructionId) async {
    final result = await ref
        .read(mineActionProvider)
        .completeConstruction(constructionId);

    ref.invalidate(mineConstructionProvider);
    ref.invalidate(mineListProvider);

    if (!mounted) return;
    if (result['success'] != true) {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: result['message'] ?? 'Maden insaati tamamlanamadi.',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _finishConstructionWithGold(String constructionId) async {
    final result = await ref
        .read(mineActionProvider)
        .finishConstructionWithGold(constructionId);

    ref.invalidate(mineConstructionProvider);
    ref.invalidate(mineListProvider);

    if (!mounted) return;
    if (result['success'] == true) {
      AppSnackbar.show(
        context,
        title: 'Tamamlandi',
        message: 'Insaat aninda tamamlandi.',
        type: SnackbarType.success,
      );
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: result['message'] ?? 'Yildiz ile bitirme basarisiz oldu.',
      type: SnackbarType.error,
    );
  }

  List<MineListItemModel> _getFilteredMines(List<MineListItemModel> mines) {
    return mines.where((item) {
      if (_selectedFilter == 'Aktif') return item.mine.isActive;
      if (_selectedFilter == 'Pasif') return !item.mine.isActive;
      return true;
    }).toList();
  }

  int _calculateStarCost(DateTime finishAt) {
    final remaining = finishAt.difference(DateTime.now());
    if (remaining.inSeconds <= 0) return 0;
    return (remaining.inMinutes / 10).ceil().clamp(1, 999999);
  }

  // ─── format yardımcısı ───────────────────────────────────────
  String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }

  // ─── renk yardımcısı ────────────────────────────────────────
  Color _ratioColor(double r) {
    if (r >= 0.8) return AppColors.green;
    if (r >= 0.4) return Colors.orange;
    return AppColors.red;
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final minesAsync = ref.watch(mineListProvider);
    final constructionAsync = ref.watch(mineConstructionProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      // ── FAB ──────────────────────────────────────────────────
      floatingActionButton: _fab(),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedIndex,
        onItemSelected: _onNavSelected,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Madenlerim'),
            Expanded(
              child: minesAsync.when(
                data: (mines) => constructionAsync.when(
                  data: (construction) {
                    final filtered = _getFilteredMines(mines);
                    return RefreshIndicator(
                      color: AppColors.gold,
                      backgroundColor: AppColors.cardBg,
                      onRefresh: _refreshAll,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          // ── Özet banner ──────────────────────
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(12.w, 14.h, 12.w, 0),
                            sliver: SliverToBoxAdapter(
                              child: _statsBar(mines),
                            ),
                          ),
                          // ── Filtre çipleri ───────────────────
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 0),
                            sliver: SliverToBoxAdapter(
                              child: _filterRow(),
                            ),
                          ),
                          // ── İnşaat kartı ─────────────────────
                          if (construction != null)
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(12.w, 14.h, 12.w, 0),
                              sliver: SliverToBoxAdapter(
                                child: _constructionCard(construction),
                              ),
                            ),
                          // ── Liste ────────────────────────────
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                                12.w, 14.h, 12.w, 100.h),
                            sliver: filtered.isEmpty
                                ? SliverToBoxAdapter(
                                    child: construction == null
                                        ? _emptyState()
                                        : const SizedBox.shrink(),
                                  )
                                : SliverList.separated(
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, b) =>
                                        SizedBox(height: 12.h),
                                    itemBuilder: (_, i) =>
                                        _mineCard(filtered[i]),
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => _loader(),
                  error: (e, _) => _error(e,
                      onRetry: () =>
                          ref.refresh(mineConstructionProvider)),
                ),
                loading: () => _loader(),
                error: (e, _) =>
                    _error(e, onRetry: () => ref.refresh(mineListProvider)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  FAB
  // ════════════════════════════════════════════════════════════
  Widget _fab() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.r),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD060), Color(0xFFE5A800)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.40),
            blurRadius: 18.r,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/mines/new/city'),
          borderRadius: BorderRadius.circular(14.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 13.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: Colors.black, size: 18.sp),
                SizedBox(width: 6.w),
                Text(
                  'YENİ MADEN',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  ÖZET BANNER
  // ════════════════════════════════════════════════════════════
  Widget _statsBar(List<MineListItemModel> mines) {
    final total = mines.length;
    final active = mines.where((m) => m.mine.isActive).length;
    final assigned =
        mines.where((m) => m.mine.productId?.isNotEmpty == true).length;
    final totalOutput =
        mines.fold<int>(0, (s, m) => s + m.outputStockQuantity);

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFF0A111F),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFF6B5120).withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.05),
            blurRadius: 16.r,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _statCell(
            icon: Icons.diamond_rounded,
            iconColor: AppColors.gold,
            label: 'Toplam',
            value: total.toString(),
          ),
          _statDivider(),
          _statCell(
            icon: Icons.bolt_rounded,
            iconColor: AppColors.green,
            label: 'Aktif',
            value: active.toString(),
            valueColor: AppColors.green,
          ),
          _statDivider(),
          _statCell(
            icon: Icons.settings_rounded,
            iconColor: AppColors.blue,
            label: 'Ayarlı',
            value: assigned.toString(),
            valueColor: AppColors.blue,
          ),
          _statDivider(),
          _statCell(
            icon: Icons.inventory_2_rounded,
            iconColor: AppColors.diamond,
            label: 'Output',
            value: _fmt(totalOutput),
          ),
        ],
      ),
    );
  }

  Widget _statCell({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 16.sp),
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 15.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 9.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1.w,
      height: 42.h,
      color: AppColors.border.withValues(alpha: 0.4),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  FİLTRE SATIRI
  // ════════════════════════════════════════════════════════════
  Widget _filterRow() {
    const dotColors = {
      'Tümü': null,
      'Aktif': AppColors.green,
      'Pasif': AppColors.red,
    };

    return Row(
      children: _filters.map((f) {
        final sel = f == 'Tümü'
            ? _selectedFilter == 'Tumu'
            : _selectedFilter == f;
        final dot = dotColors[f];

        return Padding(
          padding: EdgeInsets.only(
              right: f == _filters.last ? 0 : 8.w),
          child: GestureDetector(
            onTap: () => setState(() {
              _selectedFilter = f == 'Tümü' ? 'Tumu' : f;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: sel
                    ? AppColors.gold.withValues(alpha: 0.12)
                    : const Color(0xFF0A111F),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: sel
                      ? AppColors.gold.withValues(alpha: 0.70)
                      : AppColors.border.withValues(alpha: 0.45),
                  width: sel ? 1.4 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dot != null) ...[
                    Container(
                      width: 6.w,
                      height: 6.w,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: dot.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 6.w),
                  ],
                  Text(
                    f,
                    style: TextStyle(
                      color: sel
                          ? AppColors.goldLight
                          : AppColors.textSecondary,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  İNŞAAT KARTI
  // ════════════════════════════════════════════════════════════
  Widget _constructionCard(Map<String, dynamic> construction) {
    final finishAt =
        DateTime.tryParse(construction['finish_at']?.toString() ?? '');
    final constructionId = construction['id']?.toString();
    final name = construction['name']?.toString();

    if (finishAt == null || constructionId == null) {
      return const SizedBox.shrink();
    }

    final starCost = _calculateStarCost(finishAt.toLocal());

    return Column(
      children: [
        ConstructionCountdownCard(
          title: name?.isNotEmpty == true ? name! : 'Yeni Maden',
          subtitle: 'Maden inşaatı devam ediyor',
          finishAt: finishAt.toLocal(),
          icon: Icons.diamond,
          onFinished: () => _completeConstruction(constructionId),
        ),
        if (starCost > 0)
          Padding(
            padding: EdgeInsets.only(top: 6.h),
            child: GoldFinishButton(
              starCost: starCost,
              onPressed: () => _finishConstructionWithGold(constructionId),
            ),
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  MADEN KARTI  –  tamamen yeni tasarım
  // ════════════════════════════════════════════════════════════
  Widget _mineCard(MineListItemModel item) {
    final mine = item.mine;
    final ratio = item.outputStockRatio;
    final ratioColor = _ratioColor(ratio);


    // Renk tonu: aktif → altın border, pasif → gri border
    final borderColor = mine.isActive
        ? AppColors.borderGold.withValues(alpha: 0.55)
        : AppColors.border.withValues(alpha: 0.30);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16.r),
      child: InkWell(
        onTap: () => context.push('/mines/${mine.id}'),
        borderRadius: BorderRadius.circular(16.r),
        splashColor: AppColors.gold.withValues(alpha: 0.08),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A111F),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: borderColor, width: 1.w),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10.r,
                offset: const Offset(0, 4),
              ),
              if (mine.isActive)
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.04),
                  blurRadius: 14.r,
                  spreadRadius: 2.r,
                ),
            ],
          ),
          child: Column(
            children: [
              // ── Üst: İkon + Bilgi + Badge ─────────────────
              Padding(
                padding: EdgeInsets.all(14.w),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // İkon kutusu
                    _mineIconBox(item),
                    SizedBox(width: 14.w),
                    // Başlık + şehir + tip
                    Expanded(child: _mineInfo(item)),
                    SizedBox(width: 8.w),
                    // Sağ: durum + seviye
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _badge(
                          mine.isActive ? 'Aktif' : 'Pasif',
                          mine.isActive ? AppColors.green : AppColors.red,
                        ),
                        SizedBox(height: 6.h),
                        _badge('Lv ${mine.level}', Colors.orangeAccent),
                        if (mine.boostMultiplier > 1.0) ...[
                          SizedBox(height: 6.h),
                          _badge(
                            '⚡ ×${mine.boostMultiplier.toStringAsFixed(1)}',
                            AppColors.gold,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // ── Ürün satırı ───────────────────────────────
              _productRow(item),

              // ── Kapasite bar ──────────────────────────────
              _capacityBar(item, ratioColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mineIconBox(MineListItemModel item) {
    return Container(
      width: 68.w,
      height: 68.w,
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.25),
          width: 1.w,
        ),
      ),
      child: CachedAssetImage(
        fileName: item.mineTypeIcon,
        fit: BoxFit.contain,
        errorWidget: Icon(Icons.diamond, color: AppColors.gold, size: 32.sp),
      ),
    );
  }

  Widget _mineInfo(MineListItemModel item) {
    final mine = item.mine;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          mine.name,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 4.h),
        Row(
          children: [
            Icon(Icons.location_on_rounded,
                color: AppColors.gold, size: 11.sp),
            SizedBox(width: 3.w),
            Expanded(
              child: Text(
                item.cityName,
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(height: 3.h),
        Text(
          item.mineTypeName,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 10.sp,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // Ürün / kaynak satırı
  Widget _productRow(MineListItemModel item) {
    final hasProduct = item.hasSelectedProduct;
    final product = item.selectedProduct;
    final mine = item.mine;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.w),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: hasProduct
            ? AppColors.green.withValues(alpha: 0.06)
            : AppColors.gold.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: hasProduct
              ? AppColors.green.withValues(alpha: 0.18)
              : AppColors.borderGold.withValues(alpha: 0.20),
          width: 1.w,
        ),
      ),
      child: Row(
        children: [
          // Ürün ikonu
          Container(
            width: 38.w,
            height: 38.w,
            padding: EdgeInsets.all(hasProduct ? 5.w : 9.w),
            decoration: BoxDecoration(
              color: hasProduct
                  ? AppColors.green.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: hasProduct
                    ? AppColors.green.withValues(alpha: 0.30)
                    : AppColors.borderGold.withValues(alpha: 0.20),
                width: 1.w,
              ),
            ),
            child: hasProduct
                ? CachedAssetImage(
                    fileName: product!.urunIconu,
                    fit: BoxFit.contain,
                  )
                : Icon(
                    Icons.add_circle_outline_rounded,
                    color: AppColors.gold.withValues(alpha: 0.45),
                    size: 18.sp,
                  ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasProduct ? 'Çıkarılan Kaynak' : 'Kaynak Ayarı Gerekli',
                  style: TextStyle(
                    color: hasProduct
                        ? AppColors.textMuted
                        : AppColors.gold.withValues(alpha: 0.80),
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  hasProduct ? product!.urunAdi : 'Kaynak seçilmedi',
                  style: TextStyle(
                    color: hasProduct
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (hasProduct)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Kalite ${mine.qualityLevel}',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9.sp,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  '${product!.uretimAdedi}/sa',
                  style: TextStyle(
                    color: AppColors.green,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // Kapasite bar bölümü
  Widget _capacityBar(MineListItemModel item, Color ratioColor) {
    final ratio = item.outputStockRatio;
    final isFull = ratio >= 0.9;

    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 14.h),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.inventory_2_rounded,
                    color: AppColors.textMuted,
                    size: 12.sp,
                  ),
                  SizedBox(width: 5.w),
                  Text(
                    'Depo Kapasitesi',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.sp,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (isFull)
                    Container(
                      margin: EdgeInsets.only(right: 6.w),
                      padding: EdgeInsets.symmetric(
                          horizontal: 5.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4.r),
                        border: Border.all(
                            color: AppColors.red.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'DOLU',
                        style: TextStyle(
                          color: AppColors.red,
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  Text(
                    '${_fmt(item.outputStockQuantity)} / ${_fmt(item.mine.outputCapacity)}',
                    style: TextStyle(
                      color: isFull ? AppColors.red : AppColors.textSecondary,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 8.h),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: Stack(
              children: [
                Container(
                  height: 6.h,
                  width: double.infinity,
                  color: Colors.black.withValues(alpha: 0.4),
                ),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    height: 6.h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ratioColor.withValues(alpha: 0.65),
                          ratioColor,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ratioColor.withValues(alpha: 0.40),
                          blurRadius: 6.r,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Badge ──────────────────────────────────────────────────
  Widget _badge(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.40)),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  BOŞ DURUM
  // ════════════════════════════════════════════════════════════
  Widget _emptyState() {
    return Padding(
      padding: EdgeInsets.only(top: 60.h),
      child: Column(
        children: [
          Container(
            width: 90.w,
            height: 90.w,
            decoration: BoxDecoration(
              color: AppColors.cardBgLight,
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.borderGold.withValues(alpha: 0.4)),
            ),
            child: Icon(Icons.diamond_outlined,
                color: AppColors.textMuted, size: 44.sp),
          ),
          SizedBox(height: 18.h),
          Text(
            'Henüz bir madenin yok',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Kaynak çıkarmak için ilk madenini kur.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12.sp,
            ),
          ),
          SizedBox(height: 24.h),
          GestureDetector(
            onTap: () => context.push('/mines/new/city'),
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.gold),
                borderRadius: BorderRadius.circular(10.r),
                color: AppColors.gold.withValues(alpha: 0.08),
              ),
              child: Text(
                'İLK MADENİNİ KUR',
                style: TextStyle(
                  color: AppColors.goldLight,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  YÜKLEME / HATA
  // ════════════════════════════════════════════════════════════
  Widget _loader() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.gold,
        strokeWidth: 2,
      ),
    );
  }

  Widget _error(Object error, {required VoidCallback onRetry}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              color: AppColors.red, size: 48.sp),
          SizedBox(height: 14.h),
          Text(
            'Bir hata oluştu',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            error.toString(),
            style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20.h),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.gold),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                'Tekrar Dene',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
