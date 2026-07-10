import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/core/managers/asset_manager.dart';
import 'package:hard_kapitalizm/core/managers/auth_manager.dart';
import 'package:hard_kapitalizm/features/notification/data/notification_provider.dart';
import 'package:hard_kapitalizm/features/notification/data/push_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/core/data/player_active_products_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  int _totalFiles = 0;
  int _currentFile = 0;
  bool _isStarting = false;

  String? _error;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    if (_isStarting) return;
    _isStarting = true;
    try {
      final authManager = ref.read(authManagerProvider);
      await authManager.signInAnonymouslyIfNeeded();
      try {
        await authManager.syncGoogleProfileIfLinked();
      } catch (_) {
        // Google bagli olsa da profil senkronu basarisizsa girisi bloklama.
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          await Supabase.instance.client.rpc('bootstrap_game_session');
        } catch (_) {
          // Bootstrap basarisiz olsa bile asset yukleme ve giris akisina devam ediyoruz.
        }
      }

      await ref.read(staticCatalogsProvider.future);

      if (user != null) {
        try {
          await ref.read(pushNotificationServiceProvider).initialize();
        } catch (_) {
          // Firebase/heartbeat registration failed, proceed anyway
        }
        try {
          await ref.read(notificationActionProvider).refreshAttention();
        } catch (_) {
          // Bildirim attention refresh basarisiz olsa da giris akisina devam.
        }
        try {
          await ref.read(playerActiveProductsProvider.future);
        } catch (_) {
          // Aktif urunleri on yukleme basarisiz olsa da giris akisina devam.
        }
      }

      final assetManager = ref.read(assetManagerProvider);

      await assetManager.prefetchAssets((current, total, fileName) {
        if (mounted) {
          setState(() {
            _currentFile = current;
            _totalFiles = total;
          });
        }
      });

      // İndirme bittikten sonra barın %100 olduğunu göstermek için state'i güncelle
      if (mounted) {
        setState(() {
          // Eğer totalFiles 0 geldiyse bile (RLS vs yüzünden) barı dolu göster
          if (_totalFiles == 0) {
            _totalFiles = 1;
            _currentFile = 1;
          } else {
            _currentFile = _totalFiles;
          }
        });
        // %100 doluluk animasyonunun görünmesi için yarım saniye bekle
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      _isStarting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalFiles > 0 ? _currentFile / _totalFiles : 0.0;

    return Scaffold(
      backgroundColor: AppColors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.06,
              child: Image.asset('assets/back.png', fit: BoxFit.cover),
            ),
          ),
          Center(
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutExpo,
              tween: Tween<double>(begin: 0, end: 1),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.95 + (0.05 * value),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(24.w),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.cardBg, AppColors.cardBgLight],
                        ),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/splashlogo.webp',
                        width: 80.sp,
                        height: 80.sp,
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(height: 40.h),
                    Text(
                      'HARD',
                      style: AppTextStyles.largeTitle.standardCopyWith(
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.heroLarge,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                      ),
                    ),
                    Text(
                      'KAPITALIZM',
                      style: AppTextStyles.largeTitle.standardCopyWith(
                        color: AppColors.gold,
                        fontSize: AppTypography.heroLarge,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                    SizedBox(height: 60.h),
                    if (_error != null) ...[
                      Icon(
                        AppIcons.errorOutline,
                        color: AppColors.red,
                        size: AppIconSizes.displayLarge,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.title.standardCopyWith(
                          color: AppColors.red,
                        ),
                      ),
                      SizedBox(height: 24.h),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.textPrimary,
                          padding: EdgeInsets.symmetric(
                            horizontal: 32.w,
                            vertical: 12.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        onPressed: () {
                          setState(() => _error = null);
                          _startDownload();
                        },
                        child: Text(
                          'Tekrar Dene',
                          style: AppTextStyles.button.standardCopyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: AppTypography.title,
                          ),
                        ),
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            progress == 1.0
                                ? 'Hazir!'
                                : 'Sunucuya baglaniliyor...',
                            style: AppTextStyles.body.standardCopyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          Text(
                            '%${(progress * 100).toInt()}',
                            style: AppTextStyles.title.standardCopyWith(
                              color: AppColors.gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      AppProgressBar(
                        value: progress,
                        semanticsLabel: 'Varliklar yukleniyor',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
