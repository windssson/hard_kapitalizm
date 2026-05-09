import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/constants/supabase_constants.dart';
import 'package:hard_kapitalizm/features/home/ui/home_screen.dart';
import 'package:hard_kapitalizm/features/splash/ui/splash_screen.dart';
import 'package:hard_kapitalizm/features/store/ui/store_screen.dart';
import 'package:hard_kapitalizm/features/store/ui/store_detail_screen.dart';
import 'package:hard_kapitalizm/features/store/ui/city_selection_screen.dart';
import 'package:hard_kapitalizm/features/store/ui/store_type_selection_screen.dart';
import 'package:hard_kapitalizm/features/auth/ui/profile_screen.dart';
import 'package:hard_kapitalizm/features/field/ui/field_screen.dart';
import 'package:hard_kapitalizm/features/field/ui/field_type_selection_screen.dart';
import 'package:hard_kapitalizm/features/farm/ui/farm_screen.dart';
import 'package:hard_kapitalizm/features/farm/ui/farm_type_selection_screen.dart';
import 'package:hard_kapitalizm/features/factory/ui/factory_screen.dart';
import 'package:hard_kapitalizm/features/factory/ui/factory_type_selection_screen.dart';
import 'package:hard_kapitalizm/features/mine/ui/mine_screen.dart';
import 'package:hard_kapitalizm/features/mine/ui/mine_type_selection_screen.dart';
import 'package:hard_kapitalizm/features/market/ui/market_screen.dart';
import 'package:hard_kapitalizm/features/logistics/ui/logistics_management_screen.dart';
import 'package:hard_kapitalizm/features/logistics/ui/logistics_setup_screen.dart';
import 'package:hard_kapitalizm/features/warehouse/ui/warehouse_screen.dart';
import 'package:hard_kapitalizm/features/warehouse/ui/warehouse_type_selection_screen.dart';
import 'package:hard_kapitalizm/features/warehouse/ui/warehouse_detail_screen.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: HardKapitalizmApp()));
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/store',
      builder: (context, state) => const StoreScreen(),
      routes: [
        GoRoute(
          path: 'new/city',
          builder: (context, state) => const CitySelectionScreen(),
        ),
        GoRoute(
          path: 'new/type',
          builder: (context, state) {
            final city = state.extra as CityModel;
            return StoreTypeSelectionScreen(selectedCity: city);
          },
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) => StoreDetailScreen(
            storeId: state.pathParameters['id']!,
          ),
        ),
      ],
    ),
    GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
    GoRoute(
      path: '/fields',
      builder: (context, state) => const FieldScreen(),
      routes: [
        GoRoute(
          path: 'new/city',
          builder: (context, state) => const CitySelectionScreen(buildingKind: 'field'),
        ),
        GoRoute(
          path: 'new/type',
          builder: (context, state) {
            final city = state.extra as CityModel;
            return FieldTypeSelectionScreen(selectedCity: city);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/farms',
      builder: (context, state) => const FarmScreen(),
      routes: [
        GoRoute(
          path: 'new/city',
          builder: (context, state) => const CitySelectionScreen(buildingKind: 'farm'),
        ),
        GoRoute(
          path: 'new/type',
          builder: (context, state) {
            final city = state.extra as CityModel;
            return FarmTypeSelectionScreen(selectedCity: city);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/factories',
      builder: (context, state) => const FactoryScreen(),
      routes: [
        GoRoute(
          path: 'new/city',
          builder: (context, state) => const CitySelectionScreen(buildingKind: 'factory'),
        ),
        GoRoute(
          path: 'new/type',
          builder: (context, state) {
            final city = state.extra as CityModel;
            return FactoryTypeSelectionScreen(selectedCity: city);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/mines',
      builder: (context, state) => const MineScreen(),
      routes: [
        GoRoute(
          path: 'new/city',
          builder: (context, state) => const CitySelectionScreen(buildingKind: 'mine'),
        ),
        GoRoute(
          path: 'new/type',
          builder: (context, state) {
            final city = state.extra as CityModel;
            return MineTypeSelectionScreen(selectedCity: city);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/logistics',
      builder: (context, state) => const LogisticsManagementScreen(),
    ),
    GoRoute(
      path: '/logistics/setup',
      builder: (context, state) => const LogisticsSetupScreen(),
    ),
    GoRoute(
      path: '/market/:productId',
      builder: (context, state) {
        final productId = state.pathParameters['productId']!;
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
          builder: (context, state) => const CitySelectionScreen(buildingKind: 'warehouse'),
        ),
        GoRoute(
          path: 'new/type',
          builder: (context, state) {
            final city = state.extra as CityModel;
            return WarehouseTypeSelectionScreen(selectedCity: city);
          },
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return WarehouseDetailScreen(warehouseId: id);
          },
        ),
      ],
    ),
  ],
);

class HardKapitalizmApp extends StatelessWidget {
  const HardKapitalizmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'Hard Kapitalizm',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            scaffoldBackgroundColor: Colors.transparent,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blueGrey,
              brightness: Brightness.dark,
              surface: Colors.transparent,
            ),
            useMaterial3: true,
          ),
          builder: (context, materialChild) {
            return Stack(
              children: [
                Container(color: AppColors.background),
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.05,
                    child: Image.asset(
                      'assets/back.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (materialChild != null) materialChild,
              ],
            );
          },
          routerConfig: _router,
        );
      },
    );
  }
}
