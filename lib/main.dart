import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/utils/app_haptic.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/ads/transfer_finish_rewarded_ad_service.dart';
import 'package:hard_kapitalizm/core/constants/supabase_constants.dart';
import 'package:hard_kapitalizm/features/home/ui/home_screen.dart';
import 'package:hard_kapitalizm/features/splash/ui/splash_screen.dart';
import 'package:hard_kapitalizm/features/store/ui/store_screen.dart';
import 'package:hard_kapitalizm/features/store/ui/store_detail_screen.dart';
import 'package:hard_kapitalizm/features/store/ui/store_performance_screen.dart';
import 'package:hard_kapitalizm/features/store/ui/city_selection_screen.dart';
import 'package:hard_kapitalizm/core/widgets/building_type_selection_screen.dart';
import 'package:hard_kapitalizm/features/auth/ui/profile_screen.dart';
import 'package:hard_kapitalizm/features/auth/ui/public_profile_screen.dart';
import 'package:hard_kapitalizm/features/premium/ui/premium_store_screen.dart';
import 'package:hard_kapitalizm/features/field/ui/field_screen.dart';
import 'package:hard_kapitalizm/features/field/ui/field_detail_screen.dart';
import 'package:hard_kapitalizm/features/farm/ui/farm_screen.dart';
import 'package:hard_kapitalizm/features/farm/ui/farm_detail_screen.dart';
import 'package:hard_kapitalizm/features/factory/ui/factory_screen.dart';
import 'package:hard_kapitalizm/features/factory/ui/factory_detail_screen.dart';
import 'package:hard_kapitalizm/features/mine/ui/mine_screen.dart';
import 'package:hard_kapitalizm/features/mine/ui/mine_detail_screen.dart';
import 'package:hard_kapitalizm/features/market/ui/market_screen.dart';
import 'package:hard_kapitalizm/features/company/ui/company_screen.dart';
import 'package:hard_kapitalizm/features/company/ui/brand_design_screen.dart';
import 'package:hard_kapitalizm/features/company/ui/brand_product_design_screen.dart';
import 'package:hard_kapitalizm/features/logistics/ui/logistics_finance_report_screen.dart';
import 'package:hard_kapitalizm/features/logistics/ui/logistics_setup_screen.dart';
import 'package:hard_kapitalizm/features/transfer_map/ui/transfer_map_screen.dart';
import 'package:hard_kapitalizm/features/warehouse/ui/warehouse_screen.dart';
import 'package:hard_kapitalizm/features/warehouse/ui/warehouse_detail_screen.dart';
import 'package:hard_kapitalizm/features/warehouse/ui/warehouse_history_screen.dart';
import 'package:hard_kapitalizm/features/arge/ui/arge_screen.dart';
import 'package:hard_kapitalizm/features/mission/ui/mission_screen.dart';
import 'package:hard_kapitalizm/features/tax/ui/tax_screen.dart';
import 'package:hard_kapitalizm/features/bank/ui/bank_screen.dart';

import 'package:hard_kapitalizm/features/achievement/ui/achievement_screen.dart';
import 'package:hard_kapitalizm/features/leaderboard/ui/leaderboard_screen.dart';
import 'package:hard_kapitalizm/features/cash_flow/ui/cash_flow_screen.dart';
import 'package:hard_kapitalizm/features/notification/ui/notifications_screen.dart';
import 'package:hard_kapitalizm/features/production_report/ui/production_report_screen.dart';
import 'package:hard_kapitalizm/features/tender/ui/tender_center_screen.dart';
import 'package:hard_kapitalizm/features/tender/ui/tender_detail_screen.dart';
import 'package:hard_kapitalizm/features/chat/ui/chat_screen.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/core/navigation/app_route_observer.dart';
import 'package:hard_kapitalizm/core/widgets/timed_task_runtime.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hard_kapitalizm/features/auth/ui/auth_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    publishableKey: SupabaseConstants.supabaseAnonKey,
  );

  await AppHaptic.init();

  if (TransferFinishRewardedAdService.appId != null) {
    await MobileAds.instance.initialize();
  }

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: HardKapitalizmApp()));
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  observers: [appRouteObserver],
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/missions',
      builder: (context, state) => const MissionScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),

    GoRoute(
      path: '/achievements',
      builder: (context, state) => const AchievementScreen(),
    ),
    GoRoute(
      path: '/leaderboard',
      builder: (context, state) => const LeaderboardScreen(),
    ),
    GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
    GoRoute(
      path: '/cash-history',
      builder: (context, state) => const CashFlowScreen(),
    ),
    GoRoute(
      path: '/production-report/:ownerKind/:id',
      builder: (context, state) => ProductionReportScreen(
        ownerKind: state.pathParameters['ownerKind'] ?? 'factory',
        ownerId: state.pathParameters['id'] ?? '',
        ownerName: state.uri.queryParameters['name'] ?? 'Uretim Birimi',
      ),
    ),
    GoRoute(
      path: '/transfer-map',
      builder: (context, state) {
        final tabParam = state.uri.queryParameters['tab'];
        final initialTab = tabParam == 'fleet'
            ? 1
            : tabParam == 'history'
                ? 2
                : 0;
        return TransferMapScreen(initialTab: initialTab);
      },
    ),
    GoRoute(
      path: '/store',
      builder: (context, state) => const StoreScreen(),
      routes: [
        GoRoute(
          path: 'new/city',
          builder: (context, state) => const CitySelectionScreen(buildingKind: 'store'),
        ),
        GoRoute(
          path: 'new/type',
          builder: (context, state) {
            final city = state.extra is CityModel ? (state.extra as CityModel) : null;
            if (city == null) {
              return const CitySelectionScreen();
            }
            return BuildingTypeSelectionScreen(
              selectedCity: city,
              buildingKind: 'store',
            );
          },
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) =>
              StoreDetailScreen(storeId: state.pathParameters['id'] ?? ''),
          routes: [
            GoRoute(
              path: 'report',
              builder: (context, state) =>
                  StorePerformanceScreen(storeId: state.pathParameters['id'] ?? ''),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
      routes: [
        GoRoute(
          path: 'public/:id',
          builder: (context, state) =>
              PublicProfileScreen(playerId: state.pathParameters['id'] ?? ''),
        ),
      ],
    ),
    GoRoute(
      path: '/premium-store',
      builder: (context, state) => const PremiumStoreScreen(),
    ),
    GoRoute(
      path: '/fields',
      builder: (context, state) => const FieldScreen(),
      routes: [
        GoRoute(
          path: 'new/city',
          builder: (context, state) =>
              const CitySelectionScreen(buildingKind: 'field'),
        ),
        GoRoute(
          path: 'new/type',
          builder: (context, state) {
            final city = state.extra is CityModel ? (state.extra as CityModel) : null;
            if (city == null) {
              return const CitySelectionScreen(buildingKind: 'field');
            }
            return BuildingTypeSelectionScreen(
              selectedCity: city,
              buildingKind: 'field',
            );
          },
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) =>
              FieldDetailScreen(fieldId: state.pathParameters['id'] ?? ''),
        ),
      ],
    ),
    GoRoute(
      path: '/farms',
      builder: (context, state) => const FarmScreen(),
      routes: [
        GoRoute(
          path: 'new/city',
          builder: (context, state) =>
              const CitySelectionScreen(buildingKind: 'farm'),
        ),
        GoRoute(
          path: 'new/type',
          builder: (context, state) {
            final city = state.extra is CityModel ? (state.extra as CityModel) : null;
            if (city == null) {
              return const CitySelectionScreen(buildingKind: 'farm');
            }
            return BuildingTypeSelectionScreen(
              selectedCity: city,
              buildingKind: 'farm',
            );
          },
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) =>
              FarmDetailScreen(farmId: state.pathParameters['id'] ?? ''),
        ),
      ],
    ),
    GoRoute(
      path: '/factories',
      builder: (context, state) => const FactoryScreen(),
      routes: [
        GoRoute(
          path: 'new/city',
          builder: (context, state) =>
              const CitySelectionScreen(buildingKind: 'factory'),
        ),
        GoRoute(
          path: 'new/type',
          builder: (context, state) {
            final city = state.extra is CityModel ? (state.extra as CityModel) : null;
            if (city == null) {
              return const CitySelectionScreen(buildingKind: 'factory');
            }
            return BuildingTypeSelectionScreen(
              selectedCity: city,
              buildingKind: 'factory',
            );
          },
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) =>
              FactoryDetailScreen(factoryId: state.pathParameters['id'] ?? ''),
        ),
      ],
    ),
    GoRoute(
      path: '/factorys',
      redirect: (context, state) => '/factories',
    ),
    GoRoute(
      path: '/factory',
      redirect: (context, state) => '/factories',
    ),
    GoRoute(
      path: '/field',
      redirect: (context, state) => '/fields',
    ),
    GoRoute(
      path: '/farm',
      redirect: (context, state) => '/farms',
    ),
    GoRoute(
      path: '/mine',
      redirect: (context, state) => '/mines',
    ),
    GoRoute(
      path: '/mines',
      builder: (context, state) => const MineScreen(),
      routes: [
        GoRoute(
          path: 'new/city',
          builder: (context, state) =>
              const CitySelectionScreen(buildingKind: 'mine'),
        ),
        GoRoute(
          path: 'new/type',
          builder: (context, state) {
            final city = state.extra is CityModel ? (state.extra as CityModel) : null;
            if (city == null) {
              return const CitySelectionScreen(buildingKind: 'mine');
            }
            return BuildingTypeSelectionScreen(
              selectedCity: city,
              buildingKind: 'mine',
            );
          },
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) =>
              MineDetailScreen(mineId: state.pathParameters['id'] ?? ''),
        ),
      ],
    ),
    GoRoute(
      path: '/logistics',
      builder: (context, state) => const TransferMapScreen(initialTab: 1),
    ),
    GoRoute(
      path: '/logistics/finance',
      builder: (context, state) => const LogisticsFinanceReportScreen(),
    ),
    GoRoute(
      path: '/logistics/setup',
      builder: (context, state) => const LogisticsSetupScreen(),
    ),
    GoRoute(
      path: '/company',
      builder: (context, state) => const CompanyScreen(),
    ),
    GoRoute(
      path: '/company/design',
      builder: (context, state) => const BrandDesignScreen(),
    ),
    GoRoute(
      path: '/company/products/:productId/design',
      builder: (context, state) => BrandProductDesignScreen(
        productId: state.pathParameters['productId'] ?? '',
      ),
    ),
    GoRoute(
      path: '/market',
      builder: (context, state) {
        final warehouseId = state.uri.queryParameters['warehouseId'] ?? '';
        final playerId = state.uri.queryParameters['playerId'] ?? '';
        final cityId = state.uri.queryParameters['cityId'] ?? '';

        return MarketScreen(
          warehouseId: warehouseId,
          playerId: playerId,
          cityId: cityId,
        );
      },
    ),
    GoRoute(
      path: '/market/:productId',
      builder: (context, state) {
        final productId = state.pathParameters['productId'] ?? '';
        final warehouseId = state.uri.queryParameters['warehouseId'] ?? '';
        final playerId = state.uri.queryParameters['playerId'] ?? '';
        final cityId = state.uri.queryParameters['cityId'] ?? '';

        return MarketScreen(
          productId: productId,
          warehouseId: warehouseId,
          playerId: playerId,
          cityId: cityId,
        );
      },
    ),
    GoRoute(
      path: '/warehouses',
      builder: (context, state) => const WarehouseScreen(),
      routes: [
        GoRoute(
          path: 'new/city',
          builder: (context, state) =>
              const CitySelectionScreen(buildingKind: 'warehouse'),
        ),
        GoRoute(
          path: 'new/type',
          builder: (context, state) {
            final city = state.extra is CityModel ? (state.extra as CityModel) : null;
            if (city == null) {
              return const CitySelectionScreen(buildingKind: 'warehouse');
            }
            return BuildingTypeSelectionScreen(
              selectedCity: city,
              buildingKind: 'warehouse',
            );
          },
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return WarehouseDetailScreen(warehouseId: id);
          },
          routes: [
            GoRoute(
              path: 'history',
              builder: (context, state) => WarehouseHistoryScreen(
                warehouseId: state.pathParameters['id'] ?? '',
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(path: '/arge', builder: (context, state) => const ArgeScreen()),
    GoRoute(path: '/tax', builder: (context, state) => const TaxScreen()),
    GoRoute(path: '/bank', builder: (context, state) => const BankScreen()),
    GoRoute(
      path: '/tenders',
      builder: (context, state) => const TenderCenterScreen(),
      routes: [
        GoRoute(
          path: 'open/:id',
          builder: (context, state) =>
              TenderDetailScreen(tenderId: state.pathParameters['id'] ?? ''),
        ),
        GoRoute(
          path: 'player/:id',
          builder: (context, state) =>
              TenderDetailScreen(playerTenderId: state.pathParameters['id'] ?? ''),
        ),
      ],
    ),
  ],
);

class HardKapitalizmApp extends StatefulWidget {
  const HardKapitalizmApp({super.key});

  @override
  State<HardKapitalizmApp> createState() => _HardKapitalizmAppState();
}

class _HardKapitalizmAppState extends State<HardKapitalizmApp> {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showRecoveryPasswordDialog();
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _showRecoveryPasswordDialog() {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;

    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool isSubmitting = false;
    bool isObscure = true;
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.r),
            side: BorderSide(color: AppColors.gold.withValues(alpha: 0.6)),
          ),
          title: Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: AppColors.gold, size: 24.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Yeni Şifre Belirleyin',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
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
                  'Şifre kurtarma bağlantısı doğrulandı. Lütfen hesabınız için yeni bir şifre belirleyin.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(height: 14.h),
                TextFormField(
                  controller: newPassController,
                  obscureText: isObscure,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14.sp),
                  decoration: InputDecoration(
                    labelText: 'Yeni Şifre (En az 6 karakter)',
                    labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
                    prefixIcon: Icon(Icons.lock_outline_rounded, color: AppColors.gold, size: 18.sp),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isObscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: AppColors.textMuted,
                        size: 18.sp,
                      ),
                      onPressed: () => setDialogState(() => isObscure = !isObscure),
                    ),
                    filled: true,
                    fillColor: AppColors.cardBgLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                  validator: (val) {
                    if (val == null || val.length < 6) {
                      return 'Şifre en az 6 karakter olmalıdır.';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 10.h),
                TextFormField(
                  controller: confirmPassController,
                  obscureText: isObscure,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14.sp),
                  decoration: InputDecoration(
                    labelText: 'Yeni Şifre Tekrar',
                    labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
                    prefixIcon: Icon(Icons.lock_rounded, color: AppColors.gold, size: 18.sp),
                    filled: true,
                    fillColor: AppColors.cardBgLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                  validator: (val) {
                    if (val != newPassController.text) {
                      return 'Şifreler birbiriyle uyuşmuyor.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSubmitting = true);
                      try {
                        await Supabase.instance.client.auth.updateUser(
                          UserAttributes(password: newPassController.text.trim()),
                        );
                        if (!dialogCtx.mounted) return;
                        Navigator.pop(dialogCtx);
                        AppSnackbar.show(
                          ctx,
                          title: 'Şifreniz Güncellendi',
                          message: 'Yeni şifreniz başarıyla kaydedildi.',
                          type: SnackbarType.success,
                        );
                      } catch (e) {
                        if (!dialogCtx.mounted) return;
                        setDialogState(() => isSubmitting = false);
                        AppSnackbar.show(
                          ctx,
                          title: 'Hata',
                          message: 'Şifre güncellenemedi: $e',
                          type: SnackbarType.error,
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
              child: isSubmitting
                  ? SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.background,
                      ),
                    )
                  : const Text('Şifreyi Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        final appTheme = AppTheme.buildTheme();
        return MaterialApp.router(
          title: 'Hard Kapitalizm',
          debugShowCheckedModeBanner: false,
          theme: appTheme.copyWith(
            scaffoldBackgroundColor: AppColors.transparent,
            colorScheme: appTheme.colorScheme.copyWith(
              surface: AppColors.transparent,
            ),
          ),
          builder: (context, materialChild) {
            return TimedTaskRuntime(
              child: Stack(
                children: [
                  Container(color: AppColors.background),
                  materialChild!,
                ],
              ),
            );
          },
          routerConfig: appRouter,
        );
      },
    );
  }
}

