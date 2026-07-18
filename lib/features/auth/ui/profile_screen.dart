import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/managers/auth_manager.dart';
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
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final int _selectedIndex = 4;
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
          ref.invalidate(authIdentityProvider);
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
        await ref.read(authManagerProvider).syncLinkedGoogleProfileMetadata();
      } catch (_) {}

      if (mounted && _isGoogleSignInInProgress) {
        setState(() {
          _isGoogleSignInInProgress = false;
        });
      }
      _handleCompletedGoogleLink();
      ref.invalidate(authIdentityProvider);
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

  @override
  Widget build(BuildContext context) {
    final playerAsyncValue = ref.watch(playerProvider);
    final authIdentityAsync = ref.watch(authIdentityProvider);

    return Scaffold(
      backgroundColor: AppColors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Profil'),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                child: playerAsyncValue.when(
                  data: (player) {
                    if (player == null) {
                      return Center(
                        child: Text(
                          'Kullanici bulunamadi',
                          style: AppTextStyles.body,
                        ),
                      );
                    }
                    return _buildProfileContent(
                      player,
                      authIdentityAsync.asData?.value,
                    );
                  },
                  loading: () =>
                      Center(child: AppLoadingIndicator(color: AppColors.gold)),
                  error: (err, stack) => Center(
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

  void _showChangeCompanyNameDialog(BuildContext context, PlayerModel player) {
    final controller = TextEditingController(text: player.companyName);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.r),
          side: BorderSide(color: AppColors.cardBorder),
        ),
        title: Text(
          'Holding Adını Değiştir',
          style: AppTextStyles.title.standardCopyWith(
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yeni holding adını girin:',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: controller,
              style: AppTextStyles.input,
              maxLength: 25,
              decoration: InputDecoration(
                hintText: 'Holding Adı',
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
              style: AppTextStyles.label.standardCopyWith(
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
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Avatar Seç', style: AppTextStyles.h2),
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
                              ? AppColors.green
                              : AppColors.border,
                          width: isSelected ? 3.w : 1.w,
                        ),
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

  Widget _buildProfileContent(
    PlayerModel player,
    AuthIdentityState? authIdentity,
  ) {
    final googleAvatarUrl = authIdentity?.avatarUrl ?? player.googleAvatarUrl;
    final isUrl =
        player.avatarId.startsWith('http://') ||
        player.avatarId.startsWith('https://');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Profilim', style: AppTextStyles.h1),
        SizedBox(height: 16.h),
        
        // --- SECTION 1: HEADER CARD ---
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.4)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.gold.withValues(alpha: 0.1), AppColors.cardBg],
            ),
          ),
          child: Row(
            children: [
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
                        color: AppColors.cardBgLight,
                        border: Border.all(color: AppColors.gold, width: 2.w),
                      ),
                      child: ClipOval(
                        child: isUrl
                            ? Image.network(
                                player.avatarId,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => CachedAssetImage(
                                  fileName: 'ae1.webp',
                                  fit: BoxFit.cover,
                                  placeholder: Icon(
                                    AppIcons.person,
                                    color: AppColors.gold,
                                    size: AppIconSizes.displayLarge,
                                  ),
                                  errorWidget: Icon(
                                    AppIcons.person,
                                    color: AppColors.gold,
                                    size: AppIconSizes.displayLarge,
                                  ),
                                ),
                              )
                            : CachedAssetImage(
                                fileName: player.avatarId,
                                fit: BoxFit.cover,
                                placeholder: Icon(
                                  AppIcons.person,
                                  color: AppColors.gold,
                                  size: AppIconSizes.displayLarge,
                                ),
                                errorWidget: Icon(
                                  AppIcons.person,
                                  color: AppColors.gold,
                                  size: AppIconSizes.displayLarge,
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(4.w),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.gold, width: 1.w),
                        ),
                        child: Icon(
                          AppIcons.edit,
                          color: AppColors.gold,
                          size: AppIconSizes.xSmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            player.companyName,
                            style: AppTextStyles.h1.standardCopyWith(
                              fontSize: AppTypography.displaySmall,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            AppIcons.edit,
                            color: AppColors.gold,
                            size: 20.r,
                          ),
                          onPressed: () =>
                              _showChangeCompanyNameDialog(context, player),
                          tooltip: 'Holding Adını Değiştir',
                        ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'CEO: ${player.playerName}',
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.goldLight,
                        fontSize: AppTypography.bodyLarge,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.navBg,
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            'Seviye ${player.level}',
                            style: AppTextStyles.titleGold.standardCopyWith(
                              fontSize: AppTypography.body,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'ID: ${player.id.substring(0, 8)}...',
                          style: AppTextStyles.body,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),

        // --- SECTION 2: CORPORATE FINANCES (Unified Card) ---
        Text('Finansal Durum', style: AppTextStyles.h2),
        SizedBox(height: 12.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sirket Degeri',
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.body,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                '₺${player.companyValue.toStringAsFixed(0)}',
                style: AppTextStyles.h1.standardCopyWith(
                  fontSize: AppTypography.display,
                  color: AppColors.gold,
                ),
              ),
              SizedBox(height: 16.h),
              Divider(color: AppColors.border, height: 1),
              SizedBox(height: 16.h),
              Row(
                children: [
                  _buildStatCard(
                    AppIcons.attachMoney,
                    'Nakit',
                    player.cash.toString(),
                    AppColors.green,
                  ),
                  SizedBox(width: 12.w),
                  _buildStatCard(
                    AppIcons.star,
                    'Altin',
                    player.gold.toString(),
                    AppColors.gold,
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),

        // --- SECTION 3: LEVEL PROGRESS ---
        Text('Seviye Ilerlemesi', style: AppTextStyles.h2),
        SizedBox(height: 12.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.navBg,
                      borderRadius: BorderRadius.circular(999.r),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      'LV ${player.level}',
                      style: AppTextStyles.titleGold.standardCopyWith(
                        fontSize: AppTypography.body,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${player.currentLevelExperience} / ${player.nextLevelRequiredExperience} XP',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textPrimary,
                      fontSize: AppTypography.body,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(999.r),
                child: AppProgressBar(
                  value: player.expProgressRatio.clamp(0.0, 1.0),
                  minHeight: 10.h,
                  backgroundColor: AppColors.border.withValues(alpha: 0.35),
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'Sonraki seviyeye kalan XP: ${player.remainingExperienceToNextLevel}',
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.body,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),

        // --- SECTION 4: ACHIEVEMENTS & LEADERBOARD (Unified Social Card) ---
        Text('Basarilar ve Siralama', style: AppTextStyles.h2),
        SizedBox(height: 12.h),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${player.achievementUnlockedCount} / ${player.achievementTotalCount} rozet acildi',
                        style: AppTextStyles.body.standardCopyWith(
                          color: AppColors.textPrimary,
                          fontSize: AppTypography.bodyLarge,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/achievements'),
                      child: Text(
                        'Tumunu Gor',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.gold,
                          fontSize: AppTypography.bodySmall,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildAchievementStatCard(
                        label: 'Acilan',
                        value: player.achievementUnlockedCount.toString(),
                        color: AppColors.green,
                        icon: AppIcons.workspacePremiumRounded,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _buildAchievementStatCard(
                        label: 'Kalan',
                        value: (player.achievementTotalCount -
                                player.achievementUnlockedCount)
                            .clamp(0, player.achievementTotalCount)
                            .toString(),
                        color: AppColors.gold,
                        icon: AppIcons.lockOpenRounded,
                      ),
                    ),
                  ],
                ),
              ),
              if (player.featuredBadges.isNotEmpty) ...[
                SizedBox(height: 16.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Text(
                    'One Cikan Rozetler',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: AppTypography.bodySmall,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
                SizedBox(
                  height: 82.h,
                  child: ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    scrollDirection: Axis.horizontal,
                    itemCount: player.featuredBadges.length,
                    separatorBuilder: (context, index) => SizedBox(width: 10.w),
                    itemBuilder: (_, index) => _buildBadgeChip(player.featuredBadges[index]),
                  ),
                ),
              ] else ...[
                SizedBox(height: 12.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Text(
                    'Ilk rozetlerini acmak icin gorevlerini ve buyume adimlarini tamamla.',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: AppTypography.body,
                    ),
                  ),
                ),
              ],
              SizedBox(height: 16.h),
              Divider(color: AppColors.border, height: 1),
              Material(
                color: AppColors.transparent,
                child: InkWell(
                  onTap: () => context.go('/leaderboard'),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16.r),
                    bottomRight: Radius.circular(16.r),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Row(
                      children: [
                        Container(
                          width: 36.w,
                          height: 36.w,
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            AppIcons.emojiEventsRounded,
                            color: AppColors.gold,
                            size: AppIconSizes.regular,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Liderlik Tablosu',
                                style: AppTextStyles.body.standardCopyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: AppTypography.bodyLarge,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Diger oyuncular arasindaki yerini gor',
                                style: AppTextStyles.body.standardCopyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: AppTypography.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          AppIcons.chevronRightRounded,
                          color: AppColors.gold,
                          size: AppIconSizes.medium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),

        // --- SECTION 5: ACCOUNT LINKAGE (Google Auth at the bottom) ---
        _buildAccountLinkCard(authIdentity),
        SizedBox(height: 24.h),

        // --- LOGOUT BUTTON ---
        SizedBox(
          width: double.infinity,
          height: 48.h,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cardBg,
              side: BorderSide(color: AppColors.red.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            icon: Icon(AppIcons.logout, color: AppColors.red),
            label: Text(
              'Hesaptan Cikis Yap',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.red,
                fontSize: AppTypography.title,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                context.go('/');
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAccountLinkCard(AuthIdentityState? authIdentity) {
    final isGoogleLinked = authIdentity?.isGoogleLinked ?? false;
    final linkedEmail = authIdentity?.effectiveEmail;
    final isBusy = _isGoogleLinkInProgress && !isGoogleLinked;
    final isSignInBusy = _isGoogleSignInInProgress && !isGoogleLinked;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isGoogleLinked
                    ? AppIcons.verifiedUserRounded
                    : AppIcons.linkRounded,
                color: isGoogleLinked ? AppColors.green : AppColors.gold,
                size: AppIconSizes.regular,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  isGoogleLinked
                      ? 'Google Hesabi Bagli'
                      : 'Hesabi Guvenceye Al',
                  style: AppTextStyles.h2.standardCopyWith(
                    fontSize: AppTypography.titleLarge,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            isGoogleLinked
                ? 'Hesabin Google ile bagli. Oyuncu verilerin korunur, cihaz degistirdiginde ayni hesaba geri donebilirsin.'
                : 'Gecici cihaz hesabini Google ile baglayarak ilerlemeni guvenceye al. Mevcut oyuncu kaydin aynen korunur.',
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.body,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (linkedEmail != null && linkedEmail.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Text(
              linkedEmail,
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.bodyLarge,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          SizedBox(height: 12.h),
          if (!isGoogleLinked) ...[
            SizedBox(
              width: double.infinity,
              height: 42.h,
              child: OutlinedButton.icon(
                onPressed: isBusy || isSignInBusy
                    ? null
                    : () => _handleExistingGoogleSignIn(authIdentity),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.blue,
                  side: BorderSide(
                    color: AppColors.blue.withValues(alpha: 0.35),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                icon: Icon(
                  isSignInBusy
                      ? AppIcons.hourglassTopRounded
                      : AppIcons.loginRounded,
                  size: AppIconSizes.regular,
                ),
                label: Text(
                  isSignInBusy
                      ? 'Giris Bekleniyor'
                      : 'Var Olan Google Hesabina Gir',
                  style: AppTextStyles.body.standardCopyWith(
                    fontSize: AppTypography.body,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            SizedBox(height: 12.h),
          ],
          SizedBox(
            width: double.infinity,
            height: 46.h,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isGoogleLinked
                    ? AppColors.green.withValues(alpha: 0.14)
                    : isBusy
                    ? AppColors.gold.withValues(alpha: 0.16)
                    : AppColors.cardBgLight,
                side: BorderSide(
                  color: isGoogleLinked
                      ? AppColors.green.withValues(alpha: 0.45)
                      : isBusy
                      ? AppColors.gold.withValues(alpha: 0.45)
                      : AppColors.gold.withValues(alpha: 0.35),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              onPressed: isGoogleLinked || isBusy ? null : _handleGoogleLink,
              icon: Icon(
                isGoogleLinked
                    ? AppIcons.checkCircleRounded
                    : isBusy
                    ? AppIcons.hourglassTopRounded
                    : AppIcons.gMobiledataRounded,
                color: isGoogleLinked
                    ? AppColors.green
                    : isBusy
                    ? AppColors.gold
                    : AppColors.textPrimary,
                size: AppIconSizes.mediumLarge,
              ),
              label: Text(
                isGoogleLinked
                    ? 'Google Baglandi'
                    : isBusy
                    ? 'Baglanti Bekleniyor'
                    : 'Google Hesabina Bagla',
                style: AppTextStyles.body.standardCopyWith(
                  color: isGoogleLinked
                      ? AppColors.green
                      : isBusy
                      ? AppColors.gold
                      : AppColors.textPrimary,
                  fontSize: AppTypography.bodyLarge,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (isGoogleLinked) ...[
            SizedBox(height: 10.h),
            SizedBox(
              width: double.infinity,
              height: 42.h,
              child: OutlinedButton.icon(
                onPressed: _handleGoogleUnlink,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: BorderSide(
                    color: AppColors.red.withValues(alpha: 0.35),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                icon: Icon(AppIcons.linkOffRounded, size: AppIconSizes.regular),
                label: Text(
                  'Google Baglantisini Kaldir',
                  style: AppTextStyles.body.standardCopyWith(
                    fontSize: AppTypography.body,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
          if (isBusy) ...[
            SizedBox(height: 10.h),
            Text(
              'Tarayici veya Google penceresinden onay verip oyuna geri don. Baglanti tamamlaninca durum otomatik guncellenecek.',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.goldLight,
                fontSize: AppTypography.bodySmall,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
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
            'Google girisi acildi. Onaydan sonra uygulamaya dondugunde hesap otomatik baglanacak.',
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
      return 'Bu Google hesabi zaten baska bir oyun hesabina bagli. Farkli bir Google hesabi kullanin veya once eski baglantiyi kaldirin.';
    }

    if (raw.contains('popup closed') || raw.contains('cancelled')) {
      return 'Google baglama islemi iptal edildi.';
    }

    return error.message;
  }

  Future<void> _handleExistingGoogleSignIn(
    AuthIdentityState? authIdentity,
  ) async {
    final shouldContinue = await _confirmExistingAccountSignIn();
    if (!shouldContinue) return;

    try {
      setState(() {
        _isGoogleSignInInProgress = true;
      });
      await ref.read(authManagerProvider).signInWithGoogle();
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message:
            'Google girisi acildi. Dondugunuzde kayitli hesabiniza gecis yapilacak.',
        type: SnackbarType.info,
      );
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _isGoogleSignInInProgress = false;
        });
      }
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: _friendlyGoogleSignInErrorMessage(e),
        type: SnackbarType.error,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGoogleSignInInProgress = false;
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

  Future<bool> _confirmExistingAccountSignIn() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
        ),
        title: Text(
          'Kayitli Hesaba Gec',
          style: AppTextStyles.h2.standardCopyWith(
            fontSize: AppTypography.headline,
          ),
        ),
        content: Text(
          'Bu islem mevcut cihaz oturumundan cikarak Google hesabina bagli kayitli oyun hesabina gecis yapar.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Vazgec',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.textOnAccent,
            ),
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  String _friendlyGoogleSignInErrorMessage(AuthException error) {
    final raw = error.message.toLowerCase();

    if (raw.contains('popup closed') || raw.contains('cancelled')) {
      return 'Google ile giris islemi iptal edildi.';
    }

    return error.message;
  }

  Future<void> _handleGoogleUnlink() async {
    try {
      final removed = await ref
          .read(authManagerProvider)
          .unlinkGoogleIdentity();
      ref.invalidate(authIdentityProvider);
      if (!mounted) return;

      AppSnackbar.show(
        context,
        message: removed
            ? 'Google baglantisi kaldirildi.'
            : 'Kaldirilacak bir Google baglantisi bulunamadi.',
        type: removed ? SnackbarType.success : SnackbarType.info,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, message: e.message, type: SnackbarType.error);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: e.toString(),
        type: SnackbarType.error,
      );
    }
  }

  void _handleCompletedGoogleLink() {
    if (!mounted) return;

    final user = Supabase.instance.client.auth.currentUser;
    final identities = user?.identities ?? const <UserIdentity>[];
    final hasGoogleIdentity = identities.any(
      (identity) => identity.provider == 'google',
    );

    if (!hasGoogleIdentity) return;
    final shouldShowSuccess = _isGoogleLinkInProgress;

    if (_isGoogleLinkInProgress) {
      setState(() {
        _isGoogleLinkInProgress = false;
      });
    }

    if (!shouldShowSuccess) return;
    if (_didShowGoogleLinkSuccess) return;
    _didShowGoogleLinkSuccess = true;

    AppSnackbar.show(
      context,
      message: 'Google hesabi basariyla baglandi.',
      type: SnackbarType.success,
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: AppIconSizes.compact),
                SizedBox(width: 6.w),
                Text(label, style: AppTextStyles.body),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              value,
              style: AppTextStyles.h2.standardCopyWith(
                color: color,
                fontSize: AppTypography.headline,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeChip(AchievementBadgeModel badge) {
    final color = _badgeColor(badge.badgeColor);

    return Container(
      width: 164.w,
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: AppColors.navBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(
              _badgeIcon(badge.badgeKey),
              color: color,
              size: AppIconSizes.regular,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.bodySmall,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  badge.categoryLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.standardCopyWith(
                    color: color,
                    fontSize: AppTypography.caption,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementStatCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 30.w,
            height: 30.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: AppIconSizes.compact),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.bodyLarge,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: AppTypography.label,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _badgeIcon(String key) {
    switch (key) {
      case 'store':
        return AppIcons.storefrontRounded;
      case 'warehouse':
        return AppIcons.warehouseRounded;
      case 'factory':
        return AppIcons.precisionManufacturingRounded;
      case 'field':
      case 'farm':
        return AppIcons.agricultureRounded;
      case 'mine':
        return AppIcons.landscapeRounded;
      case 'builder':
        return AppIcons.handymanRounded;
      case 'trade':
        return AppIcons.pointOfSaleRounded;
      case 'truck':
        return AppIcons.localShippingRounded;
      case 'science':
        return AppIcons.scienceRounded;
      case 'upgrade':
        return AppIcons.trendingUpRounded;
      case 'crown':
        return AppIcons.workspacePremiumRounded;
      default:
        return AppIcons.militaryTechRounded;
    }
  }

  Color _badgeColor(String key) {
    return AppColorPresets.badge(key);
  }
}
