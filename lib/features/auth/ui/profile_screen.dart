import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/managers/auth_manager.dart';
import 'package:hard_kapitalizm/core/managers/session_manager.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/achievement/models/achievement_badge_model.dart';
import 'package:hard_kapitalizm/features/auth/data/auth_identity_provider.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/auth/models/player_model.dart';
import 'package:hard_kapitalizm/features/notification/data/push_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final int _selectedIndex = 4;
  int _activeTab = 0; // 0: Genel Bakış & Varlıklar, 1: Hesap & Güvenlik
  StreamSubscription<AuthState>? _authSubscription;
  bool _isGoogleLinkInProgress = false;
  bool _didShowGoogleLinkSuccess = false;
  bool _isGoogleSignInInProgress = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        final synced = await ref
            .read(authManagerProvider)
            .syncGoogleProfileIfLinked();
        if (synced) {
          _handleCompletedGoogleLink();
          await SessionManager.bootstrapAndRefreshAll(ref);
        }
      } catch (_) {}
    });

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) async {
      final event = data.event;
      if (event != AuthChangeEvent.signedIn &&
          event != AuthChangeEvent.userUpdated &&
          event != AuthChangeEvent.tokenRefreshed) {
        return;
      }

      try {
        await SessionManager.bootstrapAndRefreshAll(ref);
      } catch (_) {}

      if (mounted && _isGoogleSignInInProgress) {
        setState(() {
          _isGoogleSignInInProgress = false;
        });
      }
      _handleCompletedGoogleLink();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

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
            ..._buildSettingsTabContent(authIdentity),
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
                          ? Image.network(
                              player.avatarId,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => CachedAssetImage(
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
  List<Widget> _buildSettingsTabContent(AuthIdentityState? authIdentity) {
    final isGoogleLinked = authIdentity?.isGoogleLinked ?? false;
    final linkedEmail = authIdentity?.effectiveEmail;
    final isBusy = _isGoogleLinkInProgress && !isGoogleLinked;
    final isSignInBusy = _isGoogleSignInInProgress && !isGoogleLinked;

    return [
      // ── GOOGLE AUTH CARD ──
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isGoogleLinked
                ? AppColors.green.withValues(alpha: 0.4)
                : AppColors.gold.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isGoogleLinked
                      ? AppIcons.verifiedUserRounded
                      : AppIcons.shieldOutlined,
                  color: isGoogleLinked ? AppColors.green : AppColors.gold,
                  size: 18.sp,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    isGoogleLinked
                        ? 'Google Hesabı Bağlı'
                        : 'Hesabı Güvenceye Al',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isGoogleLinked)
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      'Güvende',
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.green,
                        fontSize: AppTypography.micro,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              isGoogleLinked
                  ? 'Oyun ilerlemeniz Google bulutunda güvenle saklanmaktadır. Cihaz değiştirseniz bile verileriniz kaybolmaz.'
                  : 'Hesabınızı Google ile bağlayarak ilerlemenizi yedekleyin ve diğer cihazlardan erişin.',
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.caption,
                height: 1.35,
              ),
            ),
            if (linkedEmail != null && linkedEmail.isNotEmpty) ...[
              SizedBox(height: 8.h),
              Text(
                linkedEmail,
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.goldLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            SizedBox(height: 14.h),
            if (!isGoogleLinked) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isBusy || isSignInBusy ? null : _handleGoogleLink,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.textOnAccent,
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  icon: Icon(
                    isBusy
                        ? AppIcons.hourglassTopRounded
                        : AppIcons.gMobiledataRounded,
                    size: 20.sp,
                  ),
                  label: Text(
                    isBusy ? 'Bağlanıyor...' : 'Google ile Bağla',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.textOnAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isBusy || isSignInBusy
                      ? null
                      : () => _handleExistingGoogleSignIn(authIdentity),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.6),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  icon: Icon(
                    isSignInBusy
                        ? AppIcons.hourglassTopRounded
                        : AppIcons.loginRounded,
                    size: 16.sp,
                  ),
                  label: Text(
                    isSignInBusy
                        ? 'Giriş Yapılıyor...'
                        : 'Mevcut Google Hesabına Gir',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _handleGoogleUnlink,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: BorderSide(
                      color: AppColors.red.withValues(alpha: 0.4),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  icon: Icon(
                    AppIcons.linkOffRounded,
                    size: 16.sp,
                    color: AppColors.red,
                  ),
                  label: Text(
                    'Bağlantıyı Kaldır',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.red,
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

      // ── LOGOUT BUTTON ──
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () async {
            try {
              await ref.read(pushNotificationServiceProvider).unregisterToken();
            } catch (_) {}
            await Supabase.instance.client.auth.signOut();
            if (mounted) {
              context.go('/');
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

      // ── DANGER ZONE (DELETE ACCOUNT) ──
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
                await ref.read(playerActionProvider).updateCompanyName(newName);
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
          'widget': Image.network(googleAvatarUrl, fit: BoxFit.cover),
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

  Future<void> _handleGoogleLink() async {
    try {
      setState(() {
        _isGoogleLinkInProgress = true;
        _didShowGoogleLinkSuccess = false;
      });
      await ref.read(authManagerProvider).linkGoogleIdentity();
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message:
            'Google girişi açıldı. Onaydan sonra uygulamaya döndüğünüzde hesap otomatik bağlanacak.',
        type: SnackbarType.info,
      );
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _isGoogleLinkInProgress = false;
        });
      }
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: _friendlyGoogleLinkErrorMessage(e),
        type: SnackbarType.error,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGoogleLinkInProgress = false;
        });
      }
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: e.toString(),
        type: SnackbarType.error,
      );
    }
  }

  String _friendlyGoogleLinkErrorMessage(AuthException error) {
    final raw = error.message.toLowerCase();
    final status = (error.statusCode ?? '').toLowerCase();

    if (status.contains('identity_already_exists') ||
        raw.contains('identity is already linked to another user')) {
      return 'Bu Google hesabı zaten başka bir oyun hesabına bağlı. Farklı bir Google hesabı kullanın.';
    }
    return error.message;
  }

  void _handleCompletedGoogleLink() {
    if (!mounted || _didShowGoogleLinkSuccess) return;
    if (_isGoogleLinkInProgress) {
      setState(() {
        _isGoogleLinkInProgress = false;
        _didShowGoogleLinkSuccess = true;
      });
      AppSnackbar.show(
        context,
        message: 'Google hesabı başarıyla bağlandı!',
        type: SnackbarType.success,
      );
    }
  }

  Future<void> _handleExistingGoogleSignIn(
    AuthIdentityState? authIdentity,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: BorderSide(color: AppColors.gold.withValues(alpha: 0.4)),
        ),
        title: Text(
          'Mevcut Google Hesabına Giriş',
          style: AppTextStyles.title.standardCopyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Google hesabınızdaki kayıtlı ilerlemenize geçiş yapılacak. Devam etmek istiyor musunuz?',
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
            child: const Text('Giriş Yap'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      setState(() {
        _isGoogleSignInInProgress = true;
      });
      await ref.read(authManagerProvider).signInWithGoogle();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGoogleSignInInProgress = false;
        });
        AppSnackbar.show(
          context,
          message: 'Google ile giriş başarısız: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  Future<void> _handleGoogleUnlink() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: BorderSide(color: AppColors.red.withValues(alpha: 0.4)),
        ),
        title: Text(
          'Google Bağlantısını Kaldır',
          style: AppTextStyles.title.standardCopyWith(
            color: AppColors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Google bağlantısını kaldırırsanız oyun verileriniz yalnızca bu cihazda kalacaktır. Onaylıyor musunuz?',
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Bağlantıyı Kaldır'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(authManagerProvider).unlinkGoogleIdentity();
      await SessionManager.bootstrapAndRefreshAll(ref);
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Google bağlantısı kaldırıldı.',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Bağlantı kaldırılamadı: $e',
          type: SnackbarType.error,
        );
      }
    }
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
        await supabase.auth.signOut();
        if (mounted) {
          context.go('/');
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
