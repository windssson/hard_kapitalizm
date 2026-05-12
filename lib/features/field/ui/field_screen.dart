import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/construction_countdown_card.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/field/data/field_provider.dart';
import 'package:hard_kapitalizm/features/field/models/field_model.dart';

class FieldScreen extends ConsumerStatefulWidget {
  const FieldScreen({super.key});

  @override
  ConsumerState<FieldScreen> createState() => _FieldScreenState();
}

class _FieldScreenState extends ConsumerState<FieldScreen> {
  final int _selectedIndex = 1;
  String _selectedFilter = 'Tumu';

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
    ref.invalidate(fieldListStreamProvider);
    ref.invalidate(fieldConstructionProvider);
  }

  Future<void> _completeConstruction(String constructionId) async {
    final result = await ref
        .read(fieldActionProvider)
        .completeConstruction(constructionId);

    ref.invalidate(fieldConstructionProvider);
    ref.invalidate(fieldListStreamProvider);

    if (!mounted) return;
    if (result['success'] != true) {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: result['message'] ?? 'Ciftlik insaati tamamlanamadi.',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _finishConstructionWithGold(String constructionId) async {
    final result = await ref
        .read(fieldActionProvider)
        .finishConstructionWithGold(constructionId);

    ref.invalidate(fieldConstructionProvider);
    ref.invalidate(fieldListStreamProvider);

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
    final fieldsAsync = ref.watch(fieldListStreamProvider);
    final constructionAsync = ref.watch(fieldConstructionProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/fields/new/city'),
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
        extendedPadding: EdgeInsets.symmetric(horizontal: 14.w),
        icon: Icon(Icons.add, size: 16.sp),
        label: Text(
          'YENI CIFTLIK',
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
            const SecondaryTopBar(title: 'Ciftliklerim'),
            Expanded(
              child: fieldsAsync.when(
                data: (fields) => constructionAsync.when(
                  data: (construction) => RefreshIndicator(
                    onRefresh: _refreshAll,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 12.h,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatsHeader(fields),
                          SizedBox(height: 16.h),
                          _buildFilters(),
                          SizedBox(height: 16.h),
                          if (construction != null)
                            _buildConstructionCard(construction),
                          if (_getFilteredFields(fields).isEmpty &&
                              construction == null)
                            _buildEmptyState()
                          else if (_getFilteredFields(fields).isNotEmpty)
                            _buildFieldList(_getFilteredFields(fields)),
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
                    onRetry: () => ref.refresh(fieldConstructionProvider),
                  ),
                ),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (error, stack) => _buildErrorState(
                  error,
                  onRetry: () => ref.refresh(fieldListStreamProvider),
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
          title: name?.isNotEmpty == true ? name! : 'Yeni Ciftlik',
          subtitle: 'Ciftlik insaati devam ediyor',
          finishAt: finishAt.toLocal(),
          icon: Icons.grass,
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

  List<FieldModel> _getFilteredFields(List<FieldModel> fields) {
    return fields.where((field) {
      if (_selectedFilter == 'Aktif') return field.isActive;
      if (_selectedFilter == 'Pasif') return !field.isActive;
      return true;
    }).toList();
  }

  Widget _buildStatsHeader(List<FieldModel> fields) {
    final activeCount = fields.where((field) => field.isActive).length;
    final totalSlots = fields.fold<int>(
      0,
      (sum, field) => sum + field.maxSlotCount,
    );
    final totalOutputCapacity = fields.fold<int>(
      0,
      (sum, field) => sum + field.outputCapacity,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.borderGoldLight.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem(
            Icons.grass,
            AppColors.green,
            'Toplam',
            fields.length.toString(),
            Colors.white,
          ),
          Container(width: 1, height: 40.h, color: AppColors.border),
          _buildStatItem(
            Icons.check_circle,
            AppColors.gold,
            'Aktif',
            activeCount.toString(),
            AppColors.gold,
          ),
          Container(width: 1, height: 40.h, color: AppColors.border),
          _buildStatItem(
            Icons.layers,
            Colors.blueAccent,
            'Slot',
            totalSlots.toString(),
            Colors.white,
          ),
          Container(width: 1, height: 40.h, color: AppColors.border),
          _buildStatItem(
            Icons.inventory_2,
            AppColors.green,
            'Output',
            _formatCompact(totalOutputCapacity),
            Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    Color iconColor,
    String label,
    String value,
    Color valueColor,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 18.sp),
        ),
        SizedBox(width: 8.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp),
            ),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        _buildFilterChip('Tumu', null),
        SizedBox(width: 8.w),
        _buildFilterChip('Aktif', AppColors.green),
        SizedBox(width: 8.w),
        _buildFilterChip('Pasif', AppColors.red),
      ],
    );
  }

  Widget _buildFilterChip(String label, Color? dotColor) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isSelected ? AppColors.gold : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            if (dotColor != null) ...[
              Container(
                width: 6.w,
                height: 6.w,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 6.w),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.gold : AppColors.textMuted,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13.sp,
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
          Text(
            'Henuz bir ciftligin yok.',
            style: AppTextStyles.h2.copyWith(color: AppColors.textMuted),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () => context.push('/fields/new/city'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cardBgLight,
              side: const BorderSide(color: AppColors.gold),
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            ),
            child: Text('ILK CIFTLIGINI KUR', style: AppTextStyles.titleGold),
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
        return _buildAdvancedFieldCard(field);
      },
    );
  }

  Widget _buildAdvancedFieldCard(FieldModel field) {
    final slotRatio = field.maxSlotCount > 0
        ? (field.currentSlotCount / field.maxSlotCount).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: () => context.push('/fields/${field.id}'),
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: AppColors.borderGoldLight.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 92.w,
              height: 92.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.25),
                  width: 0.8,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.green.withValues(alpha: 0.14),
                    AppColors.cardBgLight.withValues(alpha: 0.35),
                  ],
                ),
              ),
              child: Icon(Icons.grass, color: AppColors.green, size: 46.sp),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          field.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      _buildStatusChip(field.isActive),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  _buildMetricRow(
                    Icons.layers,
                    'Slot',
                    '${field.currentSlotCount}/${field.maxSlotCount}',
                  ),
                  SizedBox(height: 4.h),
                  _buildMetricRow(
                    Icons.star,
                    'Seviye',
                    'Lv. ${field.level}',
                  ),
                  SizedBox(height: 4.h),
                  _buildMetricRow(
                    Icons.input,
                    'Input',
                    _formatCompact(field.inputCapacity),
                  ),
                  SizedBox(height: 4.h),
                  _buildMetricRow(
                    Icons.outbox,
                    'Output',
                    _formatCompact(field.outputCapacity),
                  ),
                  SizedBox(height: 10.h),
                  _buildSlotProgressBar(slotRatio, field),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textMuted, size: 13.sp),
        SizedBox(width: 6.w),
        Text(
          '$label:',
          style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
        ),
        SizedBox(width: 8.w),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildSlotProgressBar(double ratio, FieldModel field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999.r),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8.h,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(_getRatioColor(ratio)),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          'Slot doluluk: %${(ratio * 100).round()}',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 10.sp,
          ),
        ),
      ],
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

  Color _getRatioColor(double ratio) {
    if (ratio >= 0.8) return AppColors.green;
    if (ratio >= 0.4) return Colors.orange;
    return AppColors.red;
  }

  String _formatCompact(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
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
