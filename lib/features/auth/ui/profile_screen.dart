import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/auth/models/player_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final int _selectedIndex = 4; // Profil index'i

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

  @override
  Widget build(BuildContext context) {
    final playerAsyncValue = ref.watch(playerStreamProvider);

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
                      return Center(child: Text('Kullanıcı bulunamadı', style: AppTextStyles.body));
                    }
                    return _buildProfileContent(player);
                  },
                  loading: () => Center(child: CircularProgressIndicator(color: AppColors.gold)),
                  error: (err, stack) => Center(child: Text('Hata: $err', style: AppTextStyles.body)),
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
    final avatars = ['ae1.webp', 'ae2.webp', 'ae3.webp', 'ak1.webp', 'ak2.webp', 'ak3.webp'];
    
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
                itemCount: avatars.length,
                itemBuilder: (context, index) {
                  final avatar = avatars[index];
                  final isSelected = player.avatarId == avatar;
                  return GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      await Supabase.instance.client
                          .from('players')
                          .update({'avatar_id': avatar})
                          .eq('id', player.id);
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

  Widget _buildProfileContent(PlayerModel player) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Profilim', style: AppTextStyles.h1),
        SizedBox(height: 16.h),
        
        // Kimlik Kartı
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.borderGold),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.gold.withValues(alpha: 0.1), AppColors.cardBg],
            ),
          ),
          child: Row(
            children: [
              // Avatar
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
                          placeholder: Icon(Icons.person, color: AppColors.gold, size: 40.sp),
                          errorWidget: Icon(Icons.person, color: AppColors.gold, size: 40.sp),
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
                        child: Icon(Icons.edit, color: AppColors.gold, size: 12.sp),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16.w),
              // Bilgiler
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
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: AppColors.navBg,
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            'Seviye ${player.level}',
                            style: AppTextStyles.titleGold.copyWith(fontSize: 12.sp),
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

        // Ekonomi Özeti
        Text('Finansal Durum', style: AppTextStyles.h2),
        SizedBox(height: 12.h),
        Row(
          children: [
            _buildStatCard(Icons.attach_money, 'Nakit', player.cash.toString(), AppColors.green),
            SizedBox(width: 12.w),
            _buildStatCard(Icons.star, 'Altın', player.gold.toString(), AppColors.gold),
          ],
        ),
        SizedBox(height: 24.h),

        // Çıkış Butonu
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
              'Hesaptan Çıkış Yap',
              style: TextStyle(color: AppColors.red, fontSize: 14.sp, fontWeight: FontWeight.bold),
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
}
