import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/construction_countdown_card.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/farm/data/farm_provider.dart';
import 'package:hard_kapitalizm/features/farm/models/farm_model.dart';

class FarmScreen extends ConsumerStatefulWidget {
  const FarmScreen({super.key});

  @override
  ConsumerState<FarmScreen> createState() => _FarmScreenState();
}

class _FarmScreenState extends ConsumerState<FarmScreen> {
  final int _selectedIndex = 1;

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
    ref.invalidate(farmListStreamProvider);
    ref.invalidate(farmConstructionProvider);
  }

  Future<void> _completeConstruction(String constructionId) async {
    final result = await ref
        .read(farmActionProvider)
        .completeConstruction(constructionId);

    ref.invalidate(farmConstructionProvider);
    ref.invalidate(farmListStreamProvider);

    if (!mounted) return;
    if (result['success'] != true) {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: result['message'] ?? 'Tarla insaati tamamlanamadi.',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _finishConstructionWithGold(String constructionId) async {
    final result = await ref
        .read(farmActionProvider)
        .finishConstructionWithGold(constructionId);

    ref.invalidate(farmConstructionProvider);
    ref.invalidate(farmListStreamProvider);

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

  @override
  Widget build(BuildContext context) {
    final farmsAsync = ref.watch(farmListStreamProvider);
    final constructionAsync = ref.watch(farmConstructionProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/farms/new/city'),
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
        extendedPadding: EdgeInsets.symmetric(horizontal: 14.w),
        icon: Icon(Icons.add, size: 16.sp),
        label: Text(
          'YENI TARLA',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.sp),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedIndex,
        onItemSelected: _onNavSelected,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Tarlalarim'),
            Expanded(
              child: farmsAsync.when(
                data: (farms) => constructionAsync.when(
                  data: (construction) => RefreshIndicator(
                    onRefresh: _refreshAll,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 12.h,
                      ),
                      child: Column(
                        children: [
                          if (construction != null)
                            _buildConstructionCard(construction),
                          if (farms.isEmpty && construction == null)
                            _buildEmptyState()
                          else if (farms.isNotEmpty)
                            _buildFarmList(farms),
                          SizedBox(height: 80.h),
                        ],
                      ),
                    ),
                  ),
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  ),
                  error: (error, stack) => _buildErrorState(
                    error,
                    onRetry: () => ref.refresh(farmConstructionProvider),
                  ),
                ),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (error, stack) => _buildErrorState(
                  error,
                  onRetry: () => ref.refresh(farmListStreamProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConstructionCard(Map<String, dynamic> construction) {
    final finishAtRaw = construction['finish_at'];
    final finishAt = DateTime.tryParse(finishAtRaw?.toString() ?? '');
    final constructionId = construction['id']?.toString();
    final name = construction['name']?.toString();

    if (finishAt == null || constructionId == null) {
      return const SizedBox.shrink();
    }

    final starCost = _calculateStarCost(finishAt.toLocal());

    return Column(
      children: [
        ConstructionCountdownCard(
          title: name?.isNotEmpty == true ? name! : 'Yeni Tarla',
          subtitle: 'Tarla insaati devam ediyor',
          finishAt: finishAt.toLocal(),
          icon: Icons.agriculture,
          onFinished: () => _completeConstruction(constructionId),
        ),
        if (starCost > 0)
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _finishConstructionWithGold(constructionId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                icon: Icon(Icons.star, size: 16.sp),
                label: Text(
                  '$starCost yildiz ile bitir',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  int _calculateStarCost(DateTime finishAt) {
    final remaining = finishAt.difference(DateTime.now());
    if (remaining.inSeconds <= 0) return 0;
    return (remaining.inMinutes / 10).ceil().clamp(1, 999999);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          SizedBox(height: 60.h),
          Icon(Icons.agriculture, color: AppColors.textMuted, size: 80.sp),
          SizedBox(height: 16.h),
          Text(
            'Henuz bir tarlan yok.',
            style: AppTextStyles.h2.copyWith(color: AppColors.textMuted),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () => context.push('/farms/new/city'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cardBgLight,
              side: const BorderSide(color: AppColors.gold),
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            ),
            child: Text('ILK TARLANI KUR', style: AppTextStyles.titleGold),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmList(List<FarmModel> farms) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: farms.length,
      itemBuilder: (context, index) {
        final farm = farms[index];
        return InkWell(
          onTap: () => context.push('/farms/${farm.id}'),
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            margin: EdgeInsets.only(bottom: 12.h),
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: farm.isActive ? AppColors.borderGold : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52.w,
                  height: 52.w,
                  decoration: BoxDecoration(
                    color: AppColors.cardBgLight,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(
                    Icons.agriculture,
                    color: AppColors.gold,
                    size: 28.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(farm.name, style: AppTextStyles.h2),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Icon(Icons.layers, color: AppColors.gold, size: 13.sp),
                          SizedBox(width: 4.w),
                          Text(
                            'Slot: ${farm.currentSlotCount}/${farm.maxSlotCount}',
                            style: AppTextStyles.body.copyWith(fontSize: 12.sp),
                          ),
                          SizedBox(width: 10.w),
                          Icon(Icons.star, color: AppColors.gold, size: 13.sp),
                          SizedBox(width: 4.w),
                          Text(
                            'Lv. ${farm.level}',
                            style: AppTextStyles.body.copyWith(fontSize: 12.sp),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(farm.isActive),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(bool isActive) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.green.withValues(alpha: 0.1)
            : AppColors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(
          color: isActive ? AppColors.green : AppColors.red,
          width: 0.5,
        ),
      ),
      child: Text(
        isActive ? 'AKTIF' : 'PASIF',
        style: TextStyle(
          color: isActive ? AppColors.green : AppColors.red,
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error, {required VoidCallback onRetry}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: AppColors.red, size: 48.sp),
          SizedBox(height: 16.h),
          Text(
            'Hata: ${error.toString()}',
            style: AppTextStyles.body.copyWith(color: AppColors.red),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }
}
