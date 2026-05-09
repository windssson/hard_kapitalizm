import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/features/mine/data/mine_provider.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_model.dart';

class MineScreen extends ConsumerStatefulWidget {
  const MineScreen({super.key});

  @override
  ConsumerState<MineScreen> createState() => _MineScreenState();
}

class _MineScreenState extends ConsumerState<MineScreen> {
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
    final minesAsync = ref.watch(mineListStreamProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/mines/new/city'),
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
        extendedPadding: EdgeInsets.symmetric(horizontal: 14.w),
        icon: Icon(Icons.add, size: 16.sp),
        label: Text(
          'YENİ MADEN',
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
            const SecondaryTopBar(title: 'Madenlerim'),
            Expanded(
              child: minesAsync.when(
                data: (mines) => RefreshIndicator(
                  onRefresh: () => ref.refresh(mineListStreamProvider.future),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                    child: Column(
                      children: [
                        if (mines.isEmpty)
                          _buildEmptyState()
                        else
                          _buildMineList(mines),
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
                        onPressed: () => ref.refresh(mineListStreamProvider),
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
          Icon(Icons.diamond_outlined, color: AppColors.textMuted, size: 80.sp),
          SizedBox(height: 16.h),
          Text('Henüz bir madeniniz yok.', style: AppTextStyles.h2.copyWith(color: AppColors.textMuted)),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () => context.push('/mines/new/city'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cardBgLight,
              side: const BorderSide(color: AppColors.gold),
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            ),
            child: Text('İLK MADENİNİ KUR', style: AppTextStyles.titleGold),
          ),
        ],
      ),
    );
  }

  Widget _buildMineList(List<MineModel> mines) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: mines.length,
      itemBuilder: (context, index) {
        final mine = mines[index];
        return Container(
          margin: EdgeInsets.only(bottom: 12.h),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: mine.isActive ? AppColors.borderGold : AppColors.border),
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
                child: Icon(Icons.diamond, color: AppColors.goldLight, size: 28.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mine.name, style: AppTextStyles.h2),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(Icons.output, color: AppColors.gold, size: 13.sp),
                        SizedBox(width: 4.w),
                        Text('Kapasite: ${mine.outputCapacity}',
                            style: AppTextStyles.body.copyWith(fontSize: 12.sp)),
                        SizedBox(width: 10.w),
                        Icon(Icons.star, color: AppColors.gold, size: 13.sp),
                        SizedBox(width: 4.w),
                        Text('Lv. ${mine.level}',
                            style: AppTextStyles.body.copyWith(fontSize: 12.sp)),
                      ],
                    ),
                    if (mine.boostMultiplier > 1.0) ...[
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Icon(Icons.bolt, color: AppColors.gold, size: 13.sp),
                          SizedBox(width: 4.w),
                          Text('Boost: x${mine.boostMultiplier.toStringAsFixed(1)}',
                              style: AppTextStyles.body.copyWith(fontSize: 11.sp, color: AppColors.gold)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              _buildStatusChip(mine.isActive),
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
