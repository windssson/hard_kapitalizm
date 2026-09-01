import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/features/notification/data/notification_provider.dart';
import 'package:hard_kapitalizm/features/notification/models/game_notification_model.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(notificationsProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final selectedCategory = ref.watch(notificationCategoryFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, unreadCount),
            _buildCategoryFilter(selectedCategory),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.gold,
                backgroundColor: AppColors.cardBg,
                onRefresh: () async {
                  await ref.read(notificationsProvider.notifier).loadInitial();
                  await ref
                      .read(unreadNotificationCountProvider.notifier)
                      .refresh();
                },
                child: state.isLoading && state.items.isEmpty
                    ? Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      )
                    : state.items.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            controller: _scrollController,
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 8.h,
                            ),
                            itemCount: state.items.length + (state.hasMore ? 1 : 0),
                            separatorBuilder: (context, index) =>
                                SizedBox(height: 6.h),
                            itemBuilder: (context, index) {
                              if (index >= state.items.length) {
                                return Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(12.w),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.gold,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final item = state.items[index];
                              return _buildNotificationCard(context, item);
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int unreadCount) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(
          bottom: BorderSide(
            color: AppColors.cardBorder.withValues(alpha: 0.5),
            width: 1.w,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
          SizedBox(width: 4.w),
          Text(
            'Bildirimler',
            style: AppTextStyles.title.standardCopyWith(
              fontSize: 14.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (unreadCount > 0) ...[
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: AppColors.red,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: TextStyle(
                  fontSize: 7.5.sp,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textOnAccent,
                ),
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            tooltip: 'Tümünü Okundu Say',
            icon: Icon(
              Icons.done_all_rounded,
              color: AppColors.green,
              size: 20,
            ),
            onPressed: () async {
              await ref.read(notificationsProvider.notifier).markAllAsRead();
            },
          ),
          IconButton(
            tooltip: 'Temizle',
            icon: Icon(
              Icons.delete_sweep_rounded,
              color: AppColors.red,
              size: 20,
            ),
            onPressed: () => _confirmClearDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(String selectedCategory) {
    final categories = [
      ('all', 'Tümü', Icons.filter_list_rounded),
      ('trade', 'Ticaret', Icons.store_rounded),
      ('logistics', 'Lojistik', Icons.local_shipping_rounded),
      ('production', 'Üretim', Icons.factory_rounded),
      ('building', 'İnşaat', Icons.domain_rounded),
      ('system', 'Sistem', Icons.notifications_active_rounded),
    ];

    return Container(
      height: 38.h,
      margin: EdgeInsets.symmetric(vertical: 6.h),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        itemCount: categories.length,
        separatorBuilder: (_, _) => SizedBox(width: 6.w),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = selectedCategory == cat.$1;

          return InkWell(
            onTap: () {
              ref
                  .read(notificationCategoryFilterProvider.notifier)
                  .setCategory(cat.$1);
            },
            borderRadius: BorderRadius.circular(10.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.gold.withValues(alpha: 0.16)
                    : AppColors.cardBg,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: isSelected
                      ? AppColors.gold
                      : AppColors.cardBorder.withValues(alpha: 0.4),
                  width: 1.w,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    cat.$3,
                    size: 13.sp,
                    color: isSelected ? AppColors.gold : AppColors.textMuted,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    cat.$2,
                    style: TextStyle(
                      fontSize: 8.5.sp,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                      color: isSelected ? AppColors.gold : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, GameNotification item) {
    final color = item.categoryColor;

    return Container(
      decoration: BoxDecoration(
        color: item.isRead
            ? AppColors.cardBg.withValues(alpha: 0.6)
            : AppColors.cardBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: item.isRead
              ? AppColors.cardBorder.withValues(alpha: 0.3)
              : color.withValues(alpha: 0.45),
          width: 1.w,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (!item.isRead) {
            ref.read(notificationsProvider.notifier).markAsRead(item.id);
          }
          _navigateToEntity(context, item);
        },
        borderRadius: BorderRadius.circular(14.r),
        child: Padding(
          padding: EdgeInsets.all(10.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: item.isRead ? 0.08 : 0.18),
                  borderRadius: BorderRadius.circular(9.r),
                  border: Border.all(
                    color: color.withValues(alpha: item.isRead ? 0.2 : 0.5),
                    width: 1.w,
                  ),
                ),
                child: Icon(
                  item.categoryIcon,
                  color: color,
                  size: 17.sp,
                ),
              ),
              SizedBox(width: 9.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.categoryLabel.toUpperCase(),
                          style: TextStyle(
                            fontSize: 7.sp,
                            fontWeight: FontWeight.w900,
                            color: color,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          item.timeAgo,
                          style: TextStyle(
                            fontSize: 7.sp,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (!item.isRead) ...[
                          SizedBox(width: 6.w),
                          Container(
                            width: 6.w,
                            height: 6.w,
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      item.title,
                      style: AppTextStyles.body.standardCopyWith(
                        fontSize: 9.sp,
                        fontWeight: item.isRead ? FontWeight.w700 : FontWeight.w900,
                        color: item.isRead
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      item.message,
                      style: AppTextStyles.caption.standardCopyWith(
                        fontSize: 7.8.sp,
                        color: item.isRead
                            ? AppColors.textMuted
                            : AppColors.textSecondary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(18.w),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.cardBorder.withValues(alpha: 0.4),
                width: 1.w,
              ),
            ),
            child: Icon(
              Icons.notifications_off_rounded,
              size: 40.sp,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'Henüz bildiriminiz yok',
            style: AppTextStyles.title.standardCopyWith(
              fontSize: 12.sp,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Oyun içindeki tüm önemli olaylar burada listelenir.',
            style: AppTextStyles.caption.standardCopyWith(
              fontSize: 8.sp,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToEntity(BuildContext context, GameNotification item) {
    if (item.entityType == null) return;

    switch (item.entityType!.toLowerCase()) {
      case 'market':
      case 'trade':
        context.push('/market');
        break;
      case 'transfer':
      case 'logistics':
        context.push('/logistics');
        break;
      case 'factory':
        context.push('/factory');
        break;
      case 'field':
      case 'farm':
        context.push('/agriculture');
        break;
      case 'tender':
        context.push('/tenders');
        break;
      case 'arge':
      case 'research':
        context.push('/arge');
        break;
      case 'construction':
      case 'building_upgrade':
      case 'upgrade':
        context.push('/home');
        break;
      default:
        break;
    }
  }

  void _confirmClearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: Text(
          'Bildirimleri Temizle',
          style: AppTextStyles.title.standardCopyWith(fontSize: 13.sp),
        ),
        content: Text(
          'Hangi bildirimleri silmek istiyorsunuz?',
          style: AppTextStyles.body.standardCopyWith(fontSize: 9.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('İptal', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(notificationsProvider.notifier).clearAll(onlyRead: true);
            },
            child: Text('Okunmuşları Sil', style: TextStyle(color: AppColors.gold)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(notificationsProvider.notifier).clearAll(onlyRead: false);
            },
            child: Text('Tümünü Sil', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }
}
