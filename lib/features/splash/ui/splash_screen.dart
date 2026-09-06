import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/core/managers/asset_manager.dart';
import 'package:hard_kapitalizm/core/managers/auth_manager.dart';
import 'package:hard_kapitalizm/core/managers/session_manager.dart';
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
    final startTime = DateTime.now();
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final authManager = ref.read(authManagerProvider);
      final assetManager = ref.read(assetManagerProvider);

      if (session == null) {
        // Oturum yok: Statik katalog ve temel arayüz görsellerini yükleyip Auth ekranına geç
        // Başarısız olursa bile auth ekranına yönlendir
        try {
          await Future.wait([
            ref.read(staticCatalogsProvider.future).timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw TimeoutException('Katalog yüklenemedi'),
            ),
            assetManager.prefetchCriticalAssets(
              onProgress: (current, total, fileName) {
                if (mounted) {
                  setState(() {
                    _currentFile = current;
                    _totalFiles = total;
                  });
                }
              },
            ),
          ]);
        } catch (_) {
          // Katalog veya asset indirme hatası auth geçişini engellemesin
        }

        final elapsed = DateTime.now().difference(startTime);
        if (elapsed < const Duration(milliseconds: 700)) {
          await Future.delayed(const Duration(milliseconds: 700) - elapsed);
        }

        if (mounted) {
          setState(() {
            _currentFile = _totalFiles > 0 ? _totalFiles : 1;
            _totalFiles = _totalFiles > 0 ? _totalFiles : 1;
          });
          context.go('/auth');
        }
        return;
      }

      // Oturum var: Arka plan senkronizasyonu başlat
      authManager.syncGoogleProfileIfLinked().ignore();

      // 1. Oturum başlatma ve geçerlilik kontrolü
      bool isSessionValid = true;
      try {
        await Supabase.instance.client.rpc('bootstrap_game_session');
      } catch (err) {
        final errStr = err.toString().toLowerCase();
        if (errStr.contains('oturum acilmamis') ||
            errStr.contains('invalid jwt') ||
            errStr.contains('jwt expired') ||
            errStr.contains('user not found') ||
            errStr.contains('unauthorized') ||
            errStr.contains('yetkisiz')) {
          isSessionValid = false;
        }
      }

      if (!isSessionValid) {
        SessionManager.invalidateAllGameProviders(ref);
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          context.go('/auth');
        }
        return;
      }

      // 2. Kritik işlemleri aynı anda PARALEL olarak yürüt
      await Future.wait([
        // Statik Şehir, Ürün ve Bina tipleri paketini tekil RPC ile çek
        ref.read(staticCatalogsProvider.future),

        // Sadece ana ekran ve temel arayüz için kritik görselleri önbelleğe al
        assetManager.prefetchCriticalAssets(
          onProgress: (current, total, fileName) {
            if (mounted) {
              setState(() {
                _currentFile = current;
                _totalFiles = total;
              });
            }
          },
        ),

        // Oturum verilerini ve ana sayfa dashboard durumunu önceden yükle
        SessionManager.bootstrapAndRefreshAll(ref),
      ]).timeout(const Duration(seconds: 20));

      // Kalan ürün ikonlarını ve arka plan servislerini ana ekrana geçerken sessizce çalıştır
      assetManager.prefetchRemainingAssetsInBackground();
      ref.read(playerActiveProductsProvider.future).ignore();

      final elapsed = DateTime.now().difference(startTime);
      if (elapsed < const Duration(milliseconds: 800)) {
        await Future.delayed(const Duration(milliseconds: 800) - elapsed);
      }

      if (mounted) {
        setState(() {
          if (_totalFiles == 0) {
            _totalFiles = 1;
            _currentFile = 1;
          } else {
            _currentFile = _totalFiles;
          }
        });
        if (!mounted) return;
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        String friendlyError = e.toString();
        if (friendlyError.contains('SocketException') ||
            friendlyError.contains('Failed host lookup') ||
            friendlyError.contains('ClientException') ||
            friendlyError.contains('HandshakeException')) {
          friendlyError =
              'İnternet bağlantısı bulunamadı. Lütfen internet bağlantınızı kontrol edip tekrar deneyin.';
        }
        setState(() {
          _error = friendlyError;
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
      backgroundColor: AppColors.background,
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
                                ? 'Hazır!'
                                : 'Sunucuya bağlanılıyor...',
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
                        semanticsLabel: 'Varlıklar yükleniyor',
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
