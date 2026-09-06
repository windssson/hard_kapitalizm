import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/managers/session_manager.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/app_network_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/features/achievement/models/achievement_badge_model.dart';
import 'package:hard_kapitalizm/features/auth/data/auth_identity_provider.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/auth/models/player_model.dart';
import 'package:hard_kapitalizm/features/notification/data/push_notification_service.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/core/managers/auth_manager.dart';
import 'package:hard_kapitalizm/core/utils/app_haptic.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final int _selectedIndex = 4;
  int _activeTab = 0; // 0: Genel Bakış & Varlıklar, 1: Hesap & Güvenlik

  void _onNavSelected(int index) {
    if (index == _selectedIndex) return;
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/company');
        break;
      case 2:
        context.go('/transfer-map');
        break;
      case 3:
        context.go('/market');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  String _getExecutiveTitle(int level) {
    if (level <= 3) return 'Genç Girişimci';
    if (level <= 7) return 'Şirket Yöneticisi';
    if (level <= 12) return 'Holding Başkanı';
    if (level <= 20) return 'Sanayi Devi';
    if (level <= 30) return 'Finans Baronu';
    return 'Kapitalizm Efsanesi';
  }

  @override
  Widget build(BuildContext context) {
    final playerAsyncValue = ref.watch(playerProvider);
    final authIdentityAsync = ref.watch(authIdentityProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Yönetici Profili'),
            Expanded(
              child: playerAsyncValue.when(
                data: (player) {
                  if (player == null) {
                    return Center(
                      child: Text(
                        'Kullanıcı bulunamadı',
                        style: AppTextStyles.body,
                      ),
                    );
                  }
                  return _buildExecutiveLayout(
                    player,
                    authIdentityAsync.asData?.value,
                  );
                },
                loading: () =>
                    Center(child: AppLoadingIndicator(color: AppColors.gold)),
                error: (err, _) => Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Text('Hata: $err', style: AppTextStyles.body),
                  ),
                ),
              ),
            ),
            AppBottomNav(
              selectedIndex: _selectedIndex,
              onItemSelected: _onNavSelected,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveLayout(
    PlayerModel player,
    AuthIdentityState? authIdentity,
  ) {
    final googleAvatarUrl = authIdentity?.avatarUrl ?? player.googleAvatarUrl;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(playerProvider);
        ref.invalidate(authIdentityProvider);
        await ref.read(playerProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
        children: [
          // ── 1. PRESTİJLİ CEO HERO KARTI ─────────────────────────────────
          _buildExecutiveHeroCard(player, googleAvatarUrl),
          SizedBox(height: 16.h),

          // ── 2. SEGMENTED TAB SWITCHER ───────────────────────────────────
          _buildSegmentedTabSwitcher(),
          SizedBox(height: 16.h),

          // ── 3. AKTİF SEKME İÇERİĞİ ──────────────────────────────────────
          if (_activeTab == 0)
            ..._buildOverviewTabContent(player)
          else
            ..._buildSettingsTabContent(authIdentity, player),
        ],
      ),
    );
  }

  // ── PRESTİJLİ CEO HERO KARTI ──────────────────────────────────────────
  Widget _buildExecutiveHeroCard(PlayerModel player, String? googleAvatarUrl) {
    final isUrl =
        player.avatarId.startsWith('http://') ||
        player.avatarId.startsWith('https://');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0F3652),
            AppColors.cardBg,
            const Color(0xFF051724),
          ],
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── AVATAR WITH VIP GOLD BORDER ──
          GestureDetector(
            onTap: () =>
                _showAvatarSelectionSheet(context, player, googleAvatarUrl),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.goldLight,
                        AppColors.gold,
                        AppColors.goldDark,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(2.5.w),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.cardBg,
                    ),
                    child: ClipOval(
                      child: isUrl
                          ? AppNetworkImage(
                              imageUrl: player.avatarId,
                              width: 80.r,
                              height: 80.r,
                              fit: BoxFit.cover,
                              errorWidget: CachedAssetImage(
                                fileName: 'ae1.webp',
                                fit: BoxFit.cover,
                              ),
                            )
                          : CachedAssetImage(
                              fileName: player.avatarId,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -2.h,
                  right: -2.w,
                  child: Container(
                    padding: EdgeInsets.all(5.w),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold, width: 1.2),
                    ),
                    child: Icon(
                      AppIcons.edit,
                      color: AppColors.gold,
                      size: 13.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 14.w),

          // ── HOLDING & EXECUTIVE DETAILS ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HOLDING NAME & EDIT BUTTON
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        player.companyName,
                        style: AppTextStyles.title.standardCopyWith(
                          color: AppColors.textPrimary,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () =>
                          _showChangeCompanyNameDialog(context, player),
                      borderRadius: BorderRadius.circular(6.r),
                      child: Padding(
                        padding: EdgeInsets.all(4.w),
                        child: Icon(
                          AppIcons.edit,
                          color: AppColors.gold,
                          size: 15.sp,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 3.h),

                // CEO TITLE BADGE
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    _getExecutiveTitle(player.level),
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.goldLight,
                      fontSize: AppTypography.micro,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 6.h),

                // LEVEL & ID ROW
                Row(
                  children: [
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.5.h),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.gold.withValues(alpha: 0.25),
                            AppColors.gold.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'SEVİYE ${player.level}',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.gold,
                          fontSize: AppTypography.micro,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: player.id));
                        AppSnackbar.show(
                          context,
                          message: 'Oyuncu ID panoya kopyalandı.',
                          type: SnackbarType.success,
                        );
                      },
                      borderRadius: BorderRadius.circular(4.r),
                      child: Row(
                        children: [
                          Text(
                            'ID: ${player.id.length >= 6 ? player.id.substring(0, 6) : player.id}...',
                            style: AppTextStyles.caption.standardCopyWith(
                              color: AppColors.textMuted,
                              fontSize: AppTypography.micro,
                            ),
                          ),
                          SizedBox(width: 3.w),
                          Icon(
                            Icons.content_copy_rounded,
                            color: AppColors.textMuted,
                            size: 11.sp,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── SEGMENTED TAB SWITCHER ──────────────────────────────────────────
  Widget _buildSegmentedTabSwitcher() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabBtn(
              index: 0,
              label: 'Varlık & Prestij',
              icon: AppIcons.accountBalanceRounded,
            ),
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: _buildTabBtn(
              index: 1,
              label: 'Hesap & Ayarlar',
              icon: Icons.settings_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBtn({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _activeTab == index;
    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      borderRadius: BorderRadius.circular(10.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 9.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cardBgLight : AppColors.transparent,
          borderRadius: BorderRadius.circular(10.r),
          border: isSelected
              ? Border.all(color: AppColors.gold.withValues(alpha: 0.5))
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16.sp,
              color: isSelected ? AppColors.gold : AppColors.textMuted,
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: AppTextStyles.caption.standardCopyWith(
                color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: AppTypography.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TAB 1: GENEL BAKIŞ & VARLIK PORTFÖYÜ ─────────────────────────────
  List<Widget> _buildOverviewTabContent(PlayerModel player) {
    return [
      // ── NET WORTH & CASH / GOLD ASSETS ──
      _buildNetWorthCard(player),
      SizedBox(height: 14.h),

      // ── LEVEL & CAREER PROGRESSION ──
      _buildCareerProgressCard(player),
      SizedBox(height: 14.h),

      // ── ACHIEVEMENTS & SOCIAL PRESTIGE ──
      _buildAchievementsCard(player),
    ];
  }

  Widget _buildNetWorthCard(PlayerModel player) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.trendingUpRounded,
                color: AppColors.gold,
                size: 16.sp,
              ),
              SizedBox(width: 6.w),
              Text(
                'TOPLAM ŞİRKET DEĞERİ',
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.micro,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            '₺ ${player.companyValue.toStringAsFixed(0)}',
            style: AppTextStyles.h1.standardCopyWith(
              color: AppColors.gold,
              fontSize: 24.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 14.h),
          Divider(color: AppColors.border.withValues(alpha: 0.4), height: 1),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: _buildAssetPill(
                  title: 'Nakit Kasa',
                  value: '₺ ${player.cash.toStringAsFixed(0)}',
                  color: AppColors.green,
                  icon: AppIcons.accountBalanceWallet,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildAssetPill(
                  title: 'Altın Rezervi',
                  value: '⭐ ${player.gold}',
                  color: AppColors.gold,
                  icon: AppIcons.starRounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssetPill({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14.sp),
              SizedBox(width: 4.w),
              Text(
                title,
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.micro,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: AppTextStyles.body.standardCopyWith(
              color: color,
              fontSize: AppTypography.bodySmall,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCareerProgressCard(PlayerModel player) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kariyer & Seviye İlerlemesi',
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.bodySmall,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${player.currentLevelExperience} / ${player.nextLevelRequiredExperience} XP',
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.goldLight,
                  fontSize: AppTypography.micro,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(6.r),
            child: AppProgressBar(
              value: player.expProgressRatio.clamp(0.0, 1.0),
              minHeight: 8.h,
              backgroundColor: AppColors.cardBgLight,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Sonraki seviye için ${player.remainingExperienceToNextLevel} XP gerekli.',
            style: AppTextStyles.caption.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.micro,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsCard(PlayerModel player) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    AppIcons.emojiEventsRounded,
                    color: AppColors.gold,
                    size: 18.sp,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    'Başarılar & Rozetler',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textPrimary,
                      fontSize: AppTypography.bodySmall,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => context.go('/achievements'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Tümünü Gör ➔',
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.gold,
                    fontSize: AppTypography.micro,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            '${player.achievementUnlockedCount} / ${player.achievementTotalCount} Rozet Tamamlandı',
            style: AppTextStyles.caption.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.caption,
            ),
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: AppProgressBar(
              value: player.achievementTotalCount > 0
                  ? (player.achievementUnlockedCount /
                          player.achievementTotalCount)
                      .clamp(0.0, 1.0)
                  : 0.0,
              minHeight: 6.h,
              backgroundColor: AppColors.cardBgLight,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.green),
            ),
          ),
          if (player.featuredBadges.isNotEmpty) ...[
            SizedBox(height: 14.h),
            SizedBox(
              height: 76.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: player.featuredBadges.length,
                separatorBuilder: (_, _) => SizedBox(width: 8.w),
                itemBuilder: (_, index) =>
                    _buildBadgeChip(player.featuredBadges[index]),
              ),
            ),
          ],
          SizedBox(height: 14.h),
          Divider(color: AppColors.border.withValues(alpha: 0.4), height: 1),
          SizedBox(height: 10.h),

          // LİDERLİK TABLOSU QUICK LINK
          InkWell(
            onTap: () => context.go('/leaderboard'),
            borderRadius: BorderRadius.circular(10.r),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      AppIcons.emojiEventsRounded,
                      color: AppColors.gold,
                      size: 16.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Liderlik Sıralaması',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Diğer holdingler arasındaki yerini gör',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.textMuted,
                            fontSize: AppTypography.micro,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    AppIcons.chevronRightRounded,
                    color: AppColors.gold,
                    size: 18.sp,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeChip(AchievementBadgeModel badge) {
    return Container(
      width: 130.w,
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: badge.isUnlocked
              ? AppColors.gold.withValues(alpha: 0.4)
              : AppColors.border.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            badge.isUnlocked
                ? AppIcons.workspacePremiumRounded
                : AppIcons.lockOutline,
            color: badge.isUnlocked ? AppColors.gold : AppColors.textMuted,
            size: 20.sp,
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  badge.title,
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.micro,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  badge.isUnlocked ? 'Açıldı' : badge.progressText,
                  style: AppTextStyles.caption.standardCopyWith(
                    color:
                        badge.isUnlocked ? AppColors.green : AppColors.textMuted,
                    fontSize: 9.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── TAB 2: HESAP & GÜVENLİK ──────────────────────────────────────────
  List<Widget> _buildSettingsTabContent(
    AuthIdentityState? authIdentity,
    PlayerModel player,
  ) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final email = currentUser?.email ??
        authIdentity?.effectiveEmail ??
        'E-posta tanımlı değil';
    final createdAtFormatted =
        '${player.createdAt.day.toString().padLeft(2, '0')}.${player.createdAt.month.toString().padLeft(2, '0')}.${player.createdAt.year}';

    return [
      // ── 1. HESAP BİLGİLERİ KARTI ──
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: AppColors.borderGold.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  AppIcons.verifiedUserRounded,
                  color: AppColors.gold,
                  size: 20.sp,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Hesap Bilgileri',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    'Aktif Hesap',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.green,
                      fontSize: AppTypography.micro,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            _buildAccountInfoRow(
              icon: Icons.email_rounded,
              label: 'Kayıtlı E-posta',
              value: email,
            ),
            SizedBox(height: 10.h),
            _buildAccountInfoRow(
              icon: Icons.apartment_rounded,
              label: 'Holding Şirketi',
              value: player.companyName,
              onTap: () => _showChangeCompanyNameDialog(context, player),
              editIcon: Icons.edit_rounded,
            ),
            SizedBox(height: 10.h),
            _buildAccountInfoRow(
              icon: Icons.location_city_rounded,
              label: 'Merkez Şehir',
              value: player.headquartersCityName ?? 'İstanbul',
              onTap: () => _showChangeCitySheet(context, player),
              editIcon: Icons.edit_location_alt_rounded,
            ),
            SizedBox(height: 10.h),
            _buildAccountInfoRow(
              icon: Icons.calendar_today_rounded,
              label: 'Kayıt Tarihi',
              value: createdAtFormatted,
            ),
            SizedBox(height: 10.h),
            _buildAccountInfoRow(
              icon: Icons.tag_rounded,
              label: 'Oyuncu ID',
              value: player.id.length > 12 ? '${player.id.substring(0, 12)}...' : player.id,
            ),
          ],
        ),
      ),
      SizedBox(height: 14.h),

      // ── 2. GÜVENLİK & ŞİFRE KARTI ──
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  (authIdentity?.isGoogleLinked == true ||
                          currentUser?.appMetadata['provider'] == 'google')
                      ? Icons.verified_user_rounded
                      : Icons.lock_reset_rounded,
                  color: AppColors.gold,
                  size: 20.sp,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Güvenlik & Giriş Yöntemi',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            if (authIdentity?.isGoogleLinked == true ||
                currentUser?.appMetadata['provider'] == 'google') ...[
              Text(
                'Hesabınız Google Güvenlik Protokolü ile korunmaktadır. Şifreye ihtiyaç duymadan cihazınızdaki Google hesabınızla anında ve güvenle giriş yapabilirsiniz.',
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.caption,
                  height: 1.35,
                ),
              ),
              SizedBox(height: 10.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppColors.gold, size: 16.sp),
                    SizedBox(width: 6.w),
                    Text(
                      'Google ile Doğrulandı',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Text(
                'Şifrenizi güvenle güncelleyebilir veya e-posta adresinize sıfırlama bağlantısı isteyebilirsiniz.',
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.caption,
                  height: 1.35,
                ),
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showChangePasswordDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.background,
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      icon: Icon(Icons.lock_reset_rounded, size: 18.sp),
                      label: Text(
                        'Şifre Değiştir',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _handleSendPasswordResetEmail(email),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.gold,
                        side: BorderSide(
                          color: AppColors.gold.withValues(alpha: 0.5),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      icon: Icon(Icons.mark_email_read_rounded, size: 18.sp),
                      label: Text(
                        'E-posta Gönder',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _handleLinkGoogleAccount,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4285F4),
                    side: BorderSide(
                      color: const Color(0xFF4285F4).withValues(alpha: 0.6),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  icon: Icon(AppIcons.gMobiledataRounded, size: 22.sp),
                  label: Text(
                    'Google Hesabını Bağla',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      SizedBox(height: 14.h),

      // ── 3. UYGULAMA TERCİHLERİ KARTI ──
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tune_rounded,
                  color: AppColors.gold,
                  size: 20.sp,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Uygulama Tercihleri',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppColors.cardBgLight,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    Icons.vibration_rounded,
                    color: AppHaptic.isEnabled ? AppColors.gold : AppColors.textMuted,
                    size: 18.sp,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dokunsal Geri Bildirim (Titreşim)',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Buton ve üretim etkileşimlerinde titreşim',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: AppHaptic.isEnabled,
                  activeThumbColor: AppColors.gold,
                  activeTrackColor: AppColors.gold.withValues(alpha: 0.3),
                  onChanged: (val) async {
                    await AppHaptic.setEnabled(val);
                    if (val) {
                      AppHaptic.selection();
                    }
                    setState(() {});
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      SizedBox(height: 14.h),

      // ── 4. LOGOUT BUTTON ──
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: AppColors.cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  side: BorderSide(
                    color: AppColors.borderGold.withValues(alpha: 0.4),
                  ),
                ),
                title: Row(
                  children: [
                    Icon(AppIcons.logout, color: AppColors.gold, size: 22.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'Hesaptan Çıkış',
                      style: AppTextStyles.title.standardCopyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: AppTypography.bodyLarge,
                      ),
                    ),
                  ],
                ),
                content: Text(
                  'Mevcut oturumunuz kapatılacaktır. Şirket ilerlemeniz bulut sunucularında güvendedir, dilediğiniz zaman tekrar giriş yapabilirsiniz.',
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'Vazgeç',
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.textOnAccent,
                    ),
                    child: const Text('Çıkış Yap'),
                  ),
                ],
              ),
            );

            if (confirmed != true) return;

            try {
              await ref.read(pushNotificationServiceProvider).unregisterToken();
            } catch (_) {}
            SessionManager.invalidateAllGameProviders(ref);
            await Supabase.instance.client.auth.signOut();
            if (mounted) {
              context.go('/auth');
            }
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textMuted,
            side: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
            padding: EdgeInsets.symmetric(vertical: 12.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
          icon: Icon(AppIcons.logout, color: AppColors.textMuted, size: 18.sp),
          label: Text(
            'Hesaptan Güvenli Çıkış Yap',
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.bodySmall,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      SizedBox(height: 14.h),

      // ── 4. DANGER ZONE (DELETE ACCOUNT) ──
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.red.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(
              AppIcons.warningAmberRounded,
              color: AppColors.red.withValues(alpha: 0.7),
              size: 18.sp,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hesabı Kalıcı Olarak Sil',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.red.withValues(alpha: 0.8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Tüm şirket varlıkları geri alınamaz şekilde silinir.',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: 10.sp,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _showDeleteAccountConfirmDialog,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.red,
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              ),
              child: Text(
                'Sil',
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildAccountInfoRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    IconData? editIcon,
  }) {
    final rowContent = Row(
      children: [
        Icon(icon, color: AppColors.gold.withValues(alpha: 0.8), size: 16.sp),
        SizedBox(width: 8.w),
        Text(
          '$label: ',
          style: AppTextStyles.caption.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.caption,
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.bodySmall,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (onTap != null) ...[
                SizedBox(width: 4.w),
                Icon(
                  editIcon ?? Icons.edit_rounded,
                  color: AppColors.gold,
                  size: 14.sp,
                ),
              ],
            ],
          ),
        ),
      ],
    );

    if (onTap == null) return rowContent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 2.w),
        child: rowContent,
      ),
    );
  }

  void _showChangeCitySheet(BuildContext context, PlayerModel player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        side: BorderSide(color: AppColors.borderGold.withValues(alpha: 0.3)),
      ),
      builder: (ctx) {
        String searchQuery = '';
        return Consumer(
          builder: (context, ref, _) {
            final citiesAsync = ref.watch(citiesProvider);
            final cities = citiesAsync.value ?? const <CityModel>[];

            final filteredCities = cities.where((c) {
              final q = searchQuery.trim().toLowerCase();
              if (q.isEmpty) return true;
              return c.name.toLowerCase().contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
              child: Column(
                children: [
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          Icons.location_city_rounded,
                          color: AppColors.gold,
                          size: 22.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Holding Merkez Şehrini Değiştir',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Holdinginizin ana yönetim merkezini seçin (81 İl)',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14.h),
                  TextField(
                    onChanged: (val) {
                      (ctx as Element).markNeedsBuild();
                      searchQuery = val;
                    },
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Şehir ara...',
                      hintStyle: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13.sp,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppColors.gold,
                        size: 20.sp,
                      ),
                      filled: true,
                      fillColor: AppColors.cardBgLight,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 12.h,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: AppColors.border.withValues(alpha: 0.6),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: AppColors.gold,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Expanded(
                    child: citiesAsync.isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: AppColors.gold,
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredCities.length,
                            separatorBuilder: (_, _) => Divider(
                              color: AppColors.border.withValues(alpha: 0.3),
                              height: 1,
                            ),
                            itemBuilder: (context, index) {
                              final city = filteredCities[index];
                              final isSelected =
                                  player.headquartersCityId == city.id ||
                                  (player.headquartersCityId == null &&
                                      city.name.toLowerCase() == 'i̇stanbul');

                              return ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 2.h,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: isSelected
                                      ? AppColors.gold
                                      : AppColors.cardBgLight,
                                  radius: 18.r,
                                  child: Icon(
                                    Icons.apartment_rounded,
                                    color: isSelected
                                        ? AppColors.background
                                        : AppColors.gold,
                                    size: 18.sp,
                                  ),
                                ),
                                title: Text(
                                  city.name,
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppColors.gold
                                        : AppColors.textPrimary,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    fontSize: 14.sp,
                                  ),
                                ),
                                subtitle: Text(
                                  'Nüfus: ${AppMoney.full(city.population, withSymbol: false)}',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11.sp,
                                  ),
                                ),
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check_circle_rounded,
                                        color: AppColors.gold,
                                        size: 20.sp,
                                      )
                                    : null,
                                onTap: () async {
                                  Navigator.pop(ctx);
                                  await ref
                                      .read(playerProvider.notifier)
                                      .setHeadquartersCity(
                                        city.id,
                                        cityName: city.name,
                                      );
                                  if (context.mounted) {
                                    AppSnackbar.show(
                                      context,
                                      title: 'Merkez Şehir Güncellendi',
                                      message:
                                          'Holdinginizin ana merkezi artık ${city.name}.',
                                      type: SnackbarType.success,
                                    );
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleSendPasswordResetEmail(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      AppSnackbar.show(
        context,
        message: 'Geçerli bir e-posta adresi bulunamadı.',
        type: SnackbarType.error,
      );
      return;
    }

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'E-posta Gönderildi',
        message: 'Şifre sıfırlama bağlantısı $email adresinize iletildi.',
        type: SnackbarType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: 'Sıfırlama e-postası gönderilemedi: $e',
        type: SnackbarType.error,
      );
    }
  }

  void _showChangePasswordDialog(BuildContext context) {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isObscuredNew = true;
    bool isObscuredConfirm = true;
    bool isSubmitting = false;
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.r),
            side: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
          ),
          title: Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: AppColors.gold, size: 22.sp),
              SizedBox(width: 8.w),
              Text(
                'Şifre Değiştir',
                style: AppTextStyles.title.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: AppTypography.bodyLarge,
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yeni şifrenizi belirleyin. Şifreniz en az 6 karakter olmalıdır.',
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                SizedBox(height: 14.h),
                TextFormField(
                  controller: newPasswordController,
                  obscureText: isObscuredNew,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14.sp),
                  decoration: InputDecoration(
                    labelText: 'Yeni Şifre',
                    labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
                    prefixIcon: Icon(Icons.lock_outline_rounded, color: AppColors.gold, size: 18.sp),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isObscuredNew ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: AppColors.textMuted,
                        size: 18.sp,
                      ),
                      onPressed: () => setDialogState(() => isObscuredNew = !isObscuredNew),
                    ),
                    filled: true,
                    fillColor: AppColors.cardBgLight,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                  validator: (val) {
                    if (val == null || val.length < 6) {
                      return 'En az 6 karakter olmalıdır.';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12.h),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: isObscuredConfirm,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14.sp),
                  decoration: InputDecoration(
                    labelText: 'Yeni Şifre Tekrar',
                    labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
                    prefixIcon: Icon(Icons.lock_rounded, color: AppColors.gold, size: 18.sp),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isObscuredConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: AppColors.textMuted,
                        size: 18.sp,
                      ),
                      onPressed: () => setDialogState(() => isObscuredConfirm = !isObscuredConfirm),
                    ),
                    filled: true,
                    fillColor: AppColors.cardBgLight,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                  validator: (val) {
                    if (val != newPasswordController.text) {
                      return 'Şifreler uyuşmuyor.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Vazgeç',
                style: AppTextStyles.caption.standardCopyWith(color: AppColors.textMuted),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSubmitting = true);
                      AppHaptic.selection();
                      try {
                        await ref.read(authManagerProvider).updatePassword(
                              newPasswordController.text.trim(),
                            );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        AppHaptic.medium();
                        AppSnackbar.show(
                          context,
                          title: 'Başarılı',
                          message: 'Şifreniz başarıyla güncellendi.',
                          type: SnackbarType.success,
                        );
                      } catch (e) {
                        if (!ctx.mounted) return;
                        setDialogState(() => isSubmitting = false);
                        AppSnackbar.show(
                          context,
                          title: 'Hata',
                          message: 'Şifre güncellenemedi: $e',
                          type: SnackbarType.error,
                        );
                      }
                    },
              child: isSubmitting
                  ? SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background),
                    )
                  : const Text('Güncelle', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLinkGoogleAccount() async {
    AppHaptic.selection();
    try {
      await ref.read(authManagerProvider).linkGoogleIdentity();
      ref.invalidate(authIdentityProvider);
      ref.invalidate(playerProvider);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      if (msg.contains('canceled') || msg.contains('cancelled') || msg.contains('code: 16')) {
        return;
      }

      String userFriendlyMessage = 'Google hesabı bağlanamadı: $e';
      if (msg.contains('already linked') ||
          msg.contains('identity_already_exists') ||
          msg.contains('duplicate')) {
        userFriendlyMessage = 'Bu Google hesabı zaten başka bir oyuncu hesabına bağlı.';
      } else if (msg.contains('network') ||
          msg.contains('socketexception') ||
          msg.contains('clientexception')) {
        userFriendlyMessage = 'İnternet bağlantınızı kontrol edin.';
      }

      AppSnackbar.show(
        context,
        title: 'Google Bağlama',
        message: userFriendlyMessage,
        type: SnackbarType.error,
      );
    }
  }

  // ── DIALOGS & ACTION HANDLERS ───────────────────────────────────────
  void _showChangeCompanyNameDialog(BuildContext context, PlayerModel player) {
    final controller = TextEditingController(text: player.companyName);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: BorderSide(color: AppColors.gold.withValues(alpha: 0.4)),
        ),
        title: Text(
          'Holding Adını Değiştir',
          style: AppTextStyles.title.standardCopyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yeni holding adını girin:',
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textMuted,
              ),
            ),
            SizedBox(height: 10.h),
            TextFormField(
              controller: controller,
              style: AppTextStyles.input,
              maxLength: 25,
              decoration: InputDecoration(
                hintText: 'Örn: Anadolu Holding',
                filled: true,
                fillColor: AppColors.cardBgLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.5),
                  ),
                ),
                counterStyle: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Vazgeç',
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) {
                AppSnackbar.show(
                  context,
                  message: 'Holding adı boş bırakılamaz.',
                  type: SnackbarType.error,
                );
                return;
              }
              Navigator.pop(context);

              try {
                await ref
                    .read(playerProvider.notifier)
                    .updateCompanyName(newName);
                ref.invalidate(playerProvider);
                if (context.mounted) {
                  AppSnackbar.show(
                    context,
                    message: 'Holding adı başarıyla güncellendi.',
                    type: SnackbarType.success,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  AppSnackbar.show(
                    context,
                    message: 'Hata: $e',
                    type: SnackbarType.error,
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.textOnAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
  }

  void _showAvatarSelectionSheet(
    BuildContext context,
    PlayerModel player,
    String? googleAvatarUrl,
  ) {
    final avatars = [
      'ae1.webp',
      'ae2.webp',
      'ae3.webp',
      'ak1.webp',
      'ak2.webp',
      'ak3.webp',
    ];

    final hasGoogle =
        googleAvatarUrl != null && googleAvatarUrl.trim().isNotEmpty;
    final List<Map<String, dynamic>> options = [
      if (hasGoogle)
        {
          'id': googleAvatarUrl,
          'widget': AppNetworkImage(
            imageUrl: googleAvatarUrl,
            fit: BoxFit.cover,
          ),
        },
      ...avatars.map(
        (av) => {
          'id': av,
          'widget': CachedAssetImage(fileName: av, fit: BoxFit.cover),
        },
      ),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Yönetici Avatarı Seç',
                style: AppTextStyles.title.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16.h),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16.w,
                  mainAxisSpacing: 16.w,
                ),
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  final optionId = option['id'] as String;
                  final optionWidget = option['widget'] as Widget;
                  final isSelected = player.avatarId == optionId;
                  return GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      await ref
                          .read(playerActionProvider)
                          .setPlayerAvatar(optionId);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.gold
                              : AppColors.border.withValues(alpha: 0.4),
                          width: isSelected ? 3.w : 1.w,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      child: ClipOval(child: optionWidget),
                    ),
                  );
                },
              ),
              SizedBox(height: 16.h),
            ],
          ),
        );
      },
    );
  }
  Future<void> _showDeleteAccountConfirmDialog() async {
    bool? confirm1 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: BorderSide(color: AppColors.red.withValues(alpha: 0.3)),
        ),
        title: Row(
          children: [
            Icon(AppIcons.warningAmberRounded, color: AppColors.red),
            SizedBox(width: 8.w),
            Text(
              'Hesabınızı Silin',
              style: AppTextStyles.title.standardCopyWith(color: AppColors.red),
            ),
          ],
        ),
        content: Text(
          'Hesabınızı silmek istediğinize emin misiniz?\n\nBu işlem şirket ilerlemenizi, madenlerinizi, fabrikalarınızı ve tüm oyun varlıklarınızı kalıcı olarak silecektir. Bu işlem geri alınamaz.',
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Vazgeç',
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );

    if (confirm1 != true) return;
    if (!mounted) return;

    bool? confirm2 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: BorderSide(color: AppColors.red.withValues(alpha: 0.5)),
        ),
        title: Text(
          'Son Onay',
          style: AppTextStyles.title.standardCopyWith(color: AppColors.red),
        ),
        content: Text(
          'Tüm kişisel verileriniz (e-posta, isim, avatar) veritabanından kalıcı olarak silinecek ve hesabınız kapatılacaktır. Onaylıyor musunuz?',
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Vazgeç',
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kalıcı Olarak Sil'),
          ),
        ],
      ),
    );

    if (confirm2 != true) return;

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.rpc('delete_own_account');
      final result = Map<String, dynamic>.from(response as Map);

      if (result['success'] == true) {
        try {
          await ref.read(pushNotificationServiceProvider).unregisterToken();
        } catch (_) {}
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('device_uuid');
          await prefs.remove('google_link_celebration');
        } catch (_) {}
        SessionManager.invalidateAllGameProviders(ref);
        await supabase.auth.signOut();
        if (mounted) {
          context.go('/auth');
          AppSnackbar.show(
            context,
            title: 'Hesap Silindi',
            message: 'Hesabınız ve tüm verileriniz başarıyla silindi.',
            type: SnackbarType.success,
          );
        }
      } else {
        if (mounted) {
          AppSnackbar.show(
            context,
            title: 'Hata',
            message: result['message']?.toString() ?? 'Hesap silinemedi.',
            type: SnackbarType.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          title: 'Hata',
          message: e.toString(),
          type: SnackbarType.error,
        );
      }
    }
  }
}
