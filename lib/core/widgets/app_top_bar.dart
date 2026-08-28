import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/app_network_image.dart';
import 'package:hard_kapitalizm/core/widgets/animated_count_text.dart';
import 'package:hard_kapitalizm/features/auth/data/auth_identity_provider.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/mission/data/mission_provider.dart';

class AppTopBar extends ConsumerWidget {
  const AppTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider).value;
    final authIdentity = ref.watch(authIdentityProvider).value;
    final missionDashboard = ref.watch(playerMissionDashboardProvider).value;
    final claimableMissionCount = missionDashboard?.claimableCount ?? 0;
    final progress = (player?.expProgressRatio ?? 0).clamp(0.0, 1.0);

    return Container(
      margin: EdgeInsets.fromLTRB(6.w, 8.h, 6.w, 6.h),
      decoration: AppDecorations.card(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kCardRadius.r),
        child: Container(
          decoration: AppDecorations.topBarInner(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 380.w;
              return Padding(
                padding: EdgeInsets.fromLTRB(8.w, 8.h, 8.w, 8.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: compact ? 52 : 54,
                      child: _buildProfilePanel(
                        context: context,
                        player: player,
                        googleAvatarUrl: authIdentity?.avatarUrl,
                        progress: progress,
                        compact: compact,
                      ),
                    ),
                    SizedBox(width: compact ? 4.w : 6.w),
                    Expanded(
                      flex: compact ? 32 : 30,
                      child: _buildResourceColumn(
                        context,
                        player,
                        compact: compact,
                      ),
                    ),
                    SizedBox(width: compact ? 4.w : 6.w),
                    _buildNotificationAction(
                      context: context,
                      claimableMissionCount: claimableMissionCount,
                      compact: compact,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePanel({
    required BuildContext context,
    required dynamic player,
    required String? googleAvatarUrl,
    required double progress,
    required bool compact,
  }) {
    return Row(
      children: [
        _buildAvatarMedallion(
          player,
          googleAvatarUrl: googleAvatarUrl,
          compact: compact,
        ),
        SizedBox(width: compact ? 6.w : 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                player?.companyName ?? 'Yeni Holding',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.title.standardCopyWith(
                  fontSize: compact ? 14.sp : 16.sp,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                player?.playerName ?? 'CEO',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.standardCopyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 9.sp : 10.sp,
                ),
              ),
              SizedBox(height: compact ? 4.h : 5.h),
              FractionallySizedBox(
                widthFactor: compact ? 0.82 : 0.86,
                alignment: Alignment.centerLeft,
                child: AppProgressBar(
                  value: progress,
                  size: compact
                      ? AppProgressSize.compact
                      : AppProgressSize.regular,
                  minHeight: compact ? 8.h : 9.h,
                ),
              ),
              SizedBox(height: compact ? 3.h : 4.h),
              Text(
                '${player?.currentLevelExperience ?? 0} / ${player?.nextLevelRequiredExperience ?? 1} XP',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textPrimary.withValues(alpha: 0.94),
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 7.5.sp : 7.8.sp,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarMedallion(
    dynamic player, {
    required String? googleAvatarUrl,
    required bool compact,
  }) {
    final avatarSize = compact ? 52.w : 60.w;
    final avatarId = player?.avatarId ?? 'ae1.webp';
    final isUrl =
        avatarId.startsWith('http://') || avatarId.startsWith('https://');
    return SizedBox(
      width: avatarSize,
      height: avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.goldLight,
                  AppColors.gold,
                  AppColors.goldDark,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.35),
                  blurRadius: 16.r,
                  spreadRadius: 1.r,
                ),
              ],
            ),
            padding: EdgeInsets.all(3.w),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cardBg,
                border: Border.all(
                  color: AppColors.goldLight.withValues(alpha: 0.55),
                  width: 1.w,
                ),
              ),
              child: ClipOval(
                child: isUrl
                    ? AppNetworkImage(
                        imageUrl: avatarId,
                        width: compact ? 34.r : 44.r,
                        height: compact ? 34.r : 44.r,
                        fit: BoxFit.cover,
                        errorWidget: CachedAssetImage(
                          fileName: 'ae1.webp',
                          fit: BoxFit.cover,
                          placeholder: Icon(
                            AppIcons.person,
                            color: AppColors.gold,
                            size: compact
                                ? AppIconSizes.medium
                                : AppIconSizes.large,
                          ),
                          errorWidget: Icon(
                            AppIcons.person,
                            color: AppColors.gold,
                            size: compact
                                ? AppIconSizes.medium
                                : AppIconSizes.large,
                          ),
                        ),
                      )
                    : CachedAssetImage(
                        fileName: avatarId,
                        fit: BoxFit.cover,
                        placeholder: Icon(
                          AppIcons.person,
                          color: AppColors.gold,
                          size: compact
                              ? AppIconSizes.medium
                              : AppIconSizes.large,
                        ),
                        errorWidget: Icon(
                          AppIcons.person,
                          color: AppColors.gold,
                          size: compact
                              ? AppIconSizes.medium
                              : AppIconSizes.large,
                        ),
                      ),
              ),
            ),
          ),
          Positioned(
            right: -1.w,
            bottom: 2.h,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 6.w : 7.w,
                vertical: compact ? 4.h : 4.5.h,
              ),
              decoration: AppDecorations.badge(
                bgColor: AppColors.cardBgLight,
                borderColor: AppColors.gold.withValues(alpha: 0.5),
                radius: 12.r,
              ),
              child: Text(
                '${player?.level ?? 1}',
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 8.sp : 9.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceColumn(
    BuildContext context,
    dynamic player, {
    required bool compact,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildResourceCard(
          context: context,
          icon: AppIcons.paymentsRounded,
          iconColor: AppColors.green,
          valueWidget: AnimatedCountText(
            value: (player?.cash ?? 0).toDouble(),
            formatter: (val) => _formatMoney(val.roundToDouble()),
            style: AppTextStyles.title.standardCopyWith(
              fontSize: compact ? 10.2.sp : 11.4.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          actionIcon: AppIcons.historyRounded,
          actionColor: AppColors.green,
          onTap: () => context.push('/cash-history'),
          compact: compact,
        ),
        SizedBox(height: compact ? 4.h : 5.h),
        _buildResourceCard(
          context: context,
          icon: AppIcons.starRounded,
          iconColor: AppColors.gold,
          valueWidget: AnimatedCountText(
            value: (player?.gold ?? 0).toDouble(),
            formatter: (val) => val.toStringAsFixed(0),
            style: AppTextStyles.title.standardCopyWith(
              fontSize: compact ? 10.2.sp : 11.4.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          actionIcon: AppIcons.addRounded,
          actionColor: AppColors.goldLight,
          onTap: () => context.push('/premium-store'),
          compact: compact,
        ),
      ],
    );
  }

  Widget _buildResourceCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Widget valueWidget,
    required IconData actionIcon,
    required Color actionColor,
    required VoidCallback onTap,
    required bool compact,
  }) {
    return Container(
      height: compact ? 26.h : 29.h,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5.w : 6.w,
        vertical: compact ? 3.h : 4.h,
      ),
      decoration: AppDecorations.card(),
      child: Row(
        children: [
          Container(
            width: compact ? 18.w : 20.w,
            height: compact ? 18.w : 20.w,
            decoration: AppDecorations.badge(
              bgColor: AppFx.panelWash(0.25),
              borderColor: AppColors.transparent,
              radius: 8.r,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: compact ? AppIconSizes.xSmall : AppIconSizes.small,
            ),
          ),
          SizedBox(width: compact ? 4.w : 5.w),
          Expanded(
            child: valueWidget,
          ),
          SizedBox(width: compact ? 3.w : 4.w),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8.r),
            child: Container(
              width: compact ? 15.w : 17.w,
              height: compact ? 15.w : 17.w,
              decoration: AppDecorations.badge(
                bgColor: AppColors.gold.withValues(alpha: 0.08),
                borderColor: AppColors.gold.withValues(alpha: 0.5),
                radius: 8.r,
              ),
              child: Icon(
                actionIcon,
                color: actionColor,
                size: compact ? AppIconSizes.xxSmall : AppIconSizes.xSmall,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationAction({
    required BuildContext context,
    required int claimableMissionCount,
    required bool compact,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: () => context.push('/missions'),
          borderRadius: BorderRadius.circular(compact ? 12.r : 14.r),
          child: Container(
            width: compact ? 38.w : 42.w,
            height: compact ? 50.h : 56.h,
            decoration: AppDecorations.card(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  AppIcons.assignmentTurnedInRounded,
                  color: AppColors.goldLight,
                  size: compact ? AppIconSizes.regular : AppIconSizes.medium,
                ),
                if (!compact) ...[
                  SizedBox(height: 2.h),
                  Text(
                    'Görev',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: AppTypography.micro,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (claimableMissionCount > 0)
          Positioned(
            right: -3.w,
            top: -5.h,
            child: Container(
              constraints: BoxConstraints(
                minWidth: compact ? 18.w : 20.w,
                minHeight: compact ? 18.w : 20.w,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 4.w : 5.w,
                vertical: 2.h,
              ),
              decoration: BoxDecoration(
                color: AppColors.red,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.textPrimary, width: 1.2.w),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.red.withValues(alpha: 0.3),
                    blurRadius: 8.r,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                claimableMissionCount > 99
                    ? '99+'
                    : claimableMissionCount.toString(),
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textOnAccent,
                  fontSize: compact ? 7.5.sp : 8.sp,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatMoney(dynamic amount) {
    return AppMoney.compact(double.tryParse(amount?.toString() ?? '0') ?? 0);
  }
}
