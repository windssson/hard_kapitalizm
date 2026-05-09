import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/features/field/data/field_provider.dart';
import 'package:hard_kapitalizm/features/field/models/field_model.dart';

class FieldScreen extends ConsumerStatefulWidget {
  const FieldScreen({super.key});

  @override
  ConsumerState<FieldScreen> createState() => _FieldScreenState();
}

class _FieldScreenState extends ConsumerState<FieldScreen> {
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
    final fieldsAsync = ref.watch(fieldListStreamProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/fields/new/city'),
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
        extendedPadding: EdgeInsets.symmetric(horizontal: 14.w),
        icon: Icon(Icons.add, size: 16.sp),
        label: Text(
          'YENİ TARLA',
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
            const SecondaryTopBar(title: 'Tarlalarım'),
            Expanded(
              child: fieldsAsync.when(
                data: (fields) => RefreshIndicator(
                  onRefresh: () => ref.refresh(fieldListStreamProvider.future),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                    child: Column(
                      children: [
                        if (fields.isEmpty)
                          _buildEmptyState()
                        else
                          _buildFieldList(fields),
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
                        onPressed: () => ref.refresh(fieldListStreamProvider),
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
          Icon(Icons.grass, color: AppColors.textMuted, size: 80.sp),
          SizedBox(height: 16.h),
          Text('Henüz bir tarlan yok.', style: AppTextStyles.h2.copyWith(color: AppColors.textMuted)),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () => context.push('/fields/new/city'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cardBgLight,
              side: const BorderSide(color: AppColors.gold),
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            ),
            child: Text('İLK TARLANI KUR', style: AppTextStyles.titleGold),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldList(List<FieldModel> fields) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: fields.length,
      itemBuilder: (context, index) {
        final field = fields[index];
        return Container(
          margin: EdgeInsets.only(bottom: 12.h),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: field.isActive ? AppColors.borderGold : AppColors.border),
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
                child: Icon(Icons.grass, color: AppColors.green, size: 28.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(field.name, style: AppTextStyles.h2),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(Icons.layers, color: AppColors.gold, size: 13.sp),
                        SizedBox(width: 4.w),
                        Text('Slot: ${field.currentSlotCount}/${field.maxSlotCount}',
                            style: AppTextStyles.body.copyWith(fontSize: 12.sp)),
                        SizedBox(width: 10.w),
                        Icon(Icons.star, color: AppColors.gold, size: 13.sp),
                        SizedBox(width: 4.w),
                        Text('Lv. ${field.level}',
                            style: AppTextStyles.body.copyWith(fontSize: 12.sp)),
                      ],
                    ),
                  ],
                ),
              ),
              _buildStatusChip(field.isActive),
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
