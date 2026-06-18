import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/managers/auth_manager.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        final synced = await ref.read(authManagerProvider).syncGoogleProfileIfLinked();
        if (synced) {
          ref.invalidate(authIdentityProvider);
          ref.invalidate(playerProvider);
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

      ref.invalidate(authIdentityProvider);
      ref.invalidate(playerProvider);
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
      backgroundColor: Colors.transparent,
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
                  loading: () => Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  ),
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

  void _showAvatarSelectionSheet(BuildContext context, PlayerModel player) {
    final avatars = [
      'ae1.webp',
      'ae2.webp',
      'ae3.webp',
      'ak1.webp',
      'ak2.webp',
      'ak3.webp',
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
              Text('Avatar Sec', style: AppTextStyles.h2),
              SizedBox(height: 16.h),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16.w,
                  mainAxisSpacing: 16.w,
                ),
                itemCount: avatars.length,
                itemBuilder: (context, index) {
                  final avatar = avatars[index];
                  final isSelected = player.avatarId == avatar;
                  return GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      await ref.read(playerActionProvider).setPlayerAvatar(avatar);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppColors.green : AppColors.border,
                          width: isSelected ? 3.w : 1.w,
                        ),
                      ),
                      child: ClipOval(
                        child: CachedAssetImage(
                          fileName: avatar,
                          fit: BoxFit.cover,
                        ),
                      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Profilim', style: AppTextStyles.h1),
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.borderGold),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.gold.withValues(alpha: 0.1),
                AppColors.cardBg,
              ],
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _showAvatarSelectionSheet(context, player),
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
                        child: CachedAssetImage(
                          fileName: player.avatarId,
                          fit: BoxFit.cover,
                          placeholder: Icon(
                            Icons.person,
                            color: AppColors.gold,
                            size: 40.sp,
                          ),
                          errorWidget: Icon(
                            Icons.person,
                            color: AppColors.gold,
                            size: 40.sp,
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
                          Icons.edit,
                          color: AppColors.gold,
                          size: 12.sp,
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
                    Text(
                      player.companyName,
                      style: AppTextStyles.h1.copyWith(fontSize: 20.sp),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'CEO: ${player.playerName}',
                      style: TextStyle(
                        color: AppColors.goldLight,
                        fontSize: 13.sp,
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
                            style: AppTextStyles.titleGold.copyWith(
                              fontSize: 12.sp,
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
        Text('Seviye Ilerlemesi', style: AppTextStyles.h2),
        SizedBox(height: 12.h),
        Container(
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
                      style: AppTextStyles.titleGold.copyWith(fontSize: 12.sp),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${player.currentLevelExperience} / ${player.nextLevelRequiredExperience} XP',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(999.r),
                child: LinearProgressIndicator(
                  value: player.expProgressRatio.clamp(0.0, 1.0),
                  minHeight: 10.h,
                  backgroundColor: AppColors.border.withValues(alpha: 0.35),
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'Sonraki seviyeye kalan XP: ${player.remainingExperienceToNextLevel}',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),
        _buildAccountLinkCard(authIdentity),
        SizedBox(height: 24.h),
        Text('Rozetler ve Basarilar', style: AppTextStyles.h2),
        SizedBox(height: 12.h),
        Container(
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
                  Expanded(
                    child: Text(
                      '${player.achievementUnlockedCount} / ${player.achievementTotalCount} rozet acildi',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/achievements'),
                    child: Text(
                      'Tumunu Gor',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: _buildAchievementStatCard(
                      label: 'Acilan',
                      value: player.achievementUnlockedCount.toString(),
                      color: AppColors.green,
                      icon: Icons.workspace_premium_rounded,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _buildAchievementStatCard(
                      label: 'Kalan',
                      value:
                          (player.achievementTotalCount -
                                  player.achievementUnlockedCount)
                              .clamp(0, player.achievementTotalCount)
                              .toString(),
                      color: AppColors.gold,
                      icon: Icons.lock_open_rounded,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              if (player.featuredBadges.isEmpty)
                Text(
                  'Ilk rozetlerini acmak icin gorevlerini ve buyume adimlarini tamamla.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.sp,
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'One Cikan Rozetler',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    SizedBox(
                      height: 82.h,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: player.featuredBadges.length,
                        separatorBuilder: (_, __) => SizedBox(width: 10.w),
                        itemBuilder: (_, index) =>
                            _buildBadgeChip(player.featuredBadges[index]),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        SizedBox(height: 24.h),
        Text('Finansal Durum', style: AppTextStyles.h2),
        SizedBox(height: 12.h),
        Container(
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
              Text(
                'Sirket Degeri',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                player.companyValue.toStringAsFixed(0),
                style: AppTextStyles.h1.copyWith(
                  fontSize: 24.sp,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            _buildStatCard(
              Icons.attach_money,
              'Nakit',
              player.cash.toString(),
              AppColors.green,
            ),
            SizedBox(width: 12.w),
            _buildStatCard(
              Icons.star,
              'Altin',
              player.gold.toString(),
              AppColors.gold,
            ),
          ],
        ),
        SizedBox(height: 24.h),
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
            icon: Icon(Icons.logout, color: AppColors.red),
            label: Text(
              'Hesaptan Cikis Yap',
              style: TextStyle(
                color: AppColors.red,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
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
                isGoogleLinked ? Icons.verified_user_rounded : Icons.link_rounded,
                color: isGoogleLinked ? AppColors.green : AppColors.gold,
                size: 18.sp,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  isGoogleLinked ? 'Google Hesabi Bagli' : 'Hesabi Guvenceye Al',
                  style: AppTextStyles.h2.copyWith(fontSize: 16.sp),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            isGoogleLinked
                ? 'Hesabin Google ile bagli. Oyuncu verilerin korunur, cihaz degistirdiginde ayni hesaba geri donebilirsin.'
                : 'Gecici cihaz hesabini Google ile baglayarak ilerlemeni guvenceye al. Mevcut oyuncu kaydin aynen korunur.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (linkedEmail != null && linkedEmail.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Text(
              linkedEmail,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            height: 46.h,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isGoogleLinked
                    ? AppColors.green.withValues(alpha: 0.14)
                    : AppColors.cardBgLight,
                side: BorderSide(
                  color: isGoogleLinked
                      ? AppColors.green.withValues(alpha: 0.45)
                      : AppColors.gold.withValues(alpha: 0.35),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              onPressed: isGoogleLinked ? null : _handleGoogleLink,
              icon: Icon(
                isGoogleLinked ? Icons.check_circle_rounded : Icons.g_mobiledata_rounded,
                color: isGoogleLinked ? AppColors.green : Colors.white,
                size: 22.sp,
              ),
              label: Text(
                isGoogleLinked ? 'Google Baglandi' : 'Google Hesabina Bagla',
                style: TextStyle(
                  color: isGoogleLinked ? AppColors.green : Colors.white,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleLink() async {
    try {
      await ref.read(authManagerProvider).linkGoogleIdentity();
      await ref.read(authManagerProvider).syncLinkedGoogleProfileMetadata();
      ref.invalidate(authIdentityProvider);
      ref.invalidate(playerProvider);
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Google hesabi basariyla baglandi.',
        type: SnackbarType.success,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: e.message,
        type: SnackbarType.error,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: e.toString(),
        type: SnackbarType.error,
      );
    }
  }

  Widget _buildStatCard(IconData icon, String label, String value, Color color) {
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
                Icon(icon, color: color, size: 16.sp),
                SizedBox(width: 6.w),
                Text(label, style: AppTextStyles.body),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18.sp,
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
            child: Icon(_badgeIcon(badge.badgeKey), color: color, size: 18.sp),
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
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  badge.categoryLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 9.sp,
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
            child: Icon(icon, color: color, size: 16.sp),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.sp,
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
        return Icons.storefront_rounded;
      case 'warehouse':
        return Icons.warehouse_rounded;
      case 'factory':
        return Icons.precision_manufacturing_rounded;
      case 'field':
      case 'farm':
        return Icons.agriculture_rounded;
      case 'mine':
        return Icons.landscape_rounded;
      case 'builder':
        return Icons.handyman_rounded;
      case 'trade':
        return Icons.point_of_sale_rounded;
      case 'truck':
        return Icons.local_shipping_rounded;
      case 'science':
        return Icons.science_rounded;
      case 'upgrade':
        return Icons.trending_up_rounded;
      case 'crown':
        return Icons.workspace_premium_rounded;
      default:
        return Icons.military_tech_rounded;
    }
  }

  Color _badgeColor(String key) {
    switch (key) {
      case 'blue':
        return Colors.lightBlueAccent;
      case 'red':
        return Colors.redAccent;
      case 'green':
        return Colors.greenAccent;
      case 'lime':
        return Colors.lightGreenAccent;
      case 'slate':
        return Colors.blueGrey;
      case 'orange':
        return Colors.orangeAccent;
      case 'deepOrange':
        return Colors.deepOrangeAccent;
      case 'cyan':
        return Colors.cyanAccent;
      case 'purple':
        return Colors.purpleAccent;
      case 'teal':
        return Colors.tealAccent;
      case 'amber':
      default:
        return Colors.amberAccent;
    }
  }
}
