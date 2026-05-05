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
import 'package:hard_kapitalizm/features/auth/ui/profile_screen.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';

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
    GoRoute(path: '/store', builder: (context, state) => const StoreScreen()),
    GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
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
            ),
            useMaterial3: true,
          ),
          builder: (context, materialChild) {
            return Stack(
              children: [
                Container(color: AppColors.background), // Siyah/koyu zemin eklendi
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.05, // Çok daha silik yapıldı
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
