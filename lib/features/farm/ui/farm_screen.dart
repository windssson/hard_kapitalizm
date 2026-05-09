import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
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
      case 0: context.go('/home'); break;
      case 2: context.go('/store'); break;
      case 4: context.go('/profile'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmsAsync = ref.watch(farmListStreamProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/farms/new/city'),
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
        extendedPadding: EdgeInsets.symmetric(horizontal: 14.w),
        icon: Icon(Icons.add, size: 16.sp),
        label: Text(
          'YENİ ÇİFTLİK',
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
            const SecondaryTopBar(title: 'Çiftliklerim'),
            Expanded(
              child: farmsAsync.when(
                data: (farms) => RefreshIndicator(
                  onRefresh: () => ref.refresh(farmListStreamProvider.future),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                    child: Column(
                      children: [
                        if (farms.isEmpty)
                          _buildEmptyState()
                        else
                          _buildFarmList(farms),
                        SizedBox(height: 80.h),
                      ],
                    ),
                  ),
                ),
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: AppColors.red, size: 48.sp),
                      SizedBox(height: 16.h),
                      Text('Hata: ${error.toString()}',
                          style: AppTextStyles.body.copyWith(color: AppColors.red),
                          textAlign: TextAlign.center),
                      SizedBox(height: 16.h),
                      ElevatedButton(
                        onPressed: () => ref.refresh(farmListStreamProvider),
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          SizedBox(height: 60.h),
          Icon(Icons.agriculture, color: AppColors.textMuted, size: 80.sp),
          SizedBox(height: 16.h),
          Text('Henüz bir çiftliğin yok.', style: AppTextStyles.h2.copyWith(color: AppColors.textMuted)),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () => context.push('/farms/new/city'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cardBgLight,
              side: const BorderSide(color: AppColors.gold),
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            ),
            child: Text('İLK ÇİFTLİĞİNİ KUR', style: AppTextStyles.titleGold),
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
        return Container(
          margin: EdgeInsets.only(bottom: 12.h),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: farm.isActive ? AppColors.borderGold : AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52.w, height: 52.w,
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(Icons.agriculture, color: AppColors.gold, size: 28.sp),
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
                        Text('Slot: ${farm.currentSlotCount}/${farm.maxSlotCount}',
                            style: AppTextStyles.body.copyWith(fontSize: 12.sp)),
                        SizedBox(width: 10.w),
                        Icon(Icons.star, color: AppColors.gold, size: 13.sp),
                        SizedBox(width: 4.w),
                        Text('Lv. ${farm.level}',
                            style: AppTextStyles.body.copyWith(fontSize: 12.sp)),
                      ],
                    ),
                  ],
                ),
              ),
              _buildStatusChip(farm.isActive),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(bool isActive) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: isActive ? AppColors.green.withValues(alpha: 0.1) : AppColors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: isActive ? AppColors.green : AppColors.red, width: 0.5),
      ),
      child: Text(
        isActive ? 'AKTİF' : 'PASİF',
        style: TextStyle(
          color: isActive ? AppColors.green : AppColors.red,
          fontSize: 10.sp, fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
