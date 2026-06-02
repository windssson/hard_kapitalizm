import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/core/managers/asset_manager.dart';
import 'package:hard_kapitalizm/core/managers/auth_manager.dart';
import 'package:hard_kapitalizm/features/notification/data/notification_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
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

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          await Supabase.instance.client.rpc(
            'bootstrap_game_session',
          );
        } catch (_) {
          // Bootstrap basarisiz olsa bile asset yukleme ve giris akisina devam ediyoruz.
        }
      }

      await ref.read(staticCatalogsProvider.future);

      if (user != null) {
        try {
          await ref.read(notificationActionProvider).refreshAttention();
        } catch (_) {
          // Bildirim attention refresh basarisiz olsa da giris akisina devam.
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
      backgroundColor: Colors.transparent,
      body: Center(
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
                // Glowing Logo
                Container(
                  padding: EdgeInsets.all(24.w),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.cardBg,
                        AppColors.cardBgLight,
                      ],
                    ),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Image.asset('assets/logo.png', width: 80.sp, height: 80.sp, fit: BoxFit.contain),
                ),
                SizedBox(height: 40.h),
                // Title
                Text(
                  'HARD',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 36.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                  ),
                ),
                Text(
                  'KAPITALIZM',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 32.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                SizedBox(height: 60.h),
                
                if (_error != null) ...[
                  Icon(Icons.error_outline, color: AppColors.red, size: 40.sp),
                  SizedBox(height: 16.h),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.red, fontSize: 14.sp),
                  ),
                  SizedBox(height: 24.h),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    onPressed: () {
                      setState(() => _error = null);
                      _startDownload();
                    },
                    child: Text('Tekrar Dene', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                  )
                ] else ...[
                  // Progress Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        progress == 1.0 ? 'Hazir!' : 'Sunucuya baglaniliyor...',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
                      ),
                      Text(
                        '%${(progress * 100).toInt()}',
                        style: TextStyle(color: AppColors.gold, fontSize: 14.sp, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  // Custom Progress Bar
                  Container(
                    height: 8.h,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.cardBgLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4.r),
                      border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                              width: constraints.maxWidth * progress,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.goldDark, AppColors.goldLight],
                                ),
                                borderRadius: BorderRadius.circular(4.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.gold.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
