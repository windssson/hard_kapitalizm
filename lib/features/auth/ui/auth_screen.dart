import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/managers/auth_manager.dart';
import 'package:hard_kapitalizm/core/managers/session_manager.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_haptic.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoogleOnboardingResult {
  final CityModel city;
  final String companyName;

  const GoogleOnboardingResult({
    required this.city,
    required this.companyName,
  });
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerPasswordConfirmController = TextEditingController();
  final _registerCompanyNameController =
      TextEditingController(text: 'Yeni Holding');

  bool _isLoginPasswordObscured = true;
  bool _isRegisterPasswordObscured = true;
  bool _isRegisterPasswordConfirmObscured = true;

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  CityModel? _selectedCity;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerPasswordConfirmController.dispose();
    _registerCompanyNameController.dispose();
    super.dispose();
  }

  String _mapAuthError(Object error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return 'E-posta adresi veya şifre hatalı.';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already registered') ||
        msg.contains('user_already_exists')) {
      return 'Bu e-posta adresiyle zaten kayıtlı bir hesap var. Giriş yapmayı deneyin.';
    }
    if (msg.contains('password should be at least') ||
        msg.contains('weak_password')) {
      return 'Şifre çok zayıf. En az 6 karakter olmalıdır.';
    }
    if (msg.contains('invalid email') || msg.contains('invalid_email')) {
      return 'Lütfen geçerli bir e-posta adresi girin.';
    }
    if (msg.contains('network') ||
        msg.contains('socketexception') ||
        msg.contains('clientexception')) {
      return 'İnternet bağlantınızı kontrol edin.';
    }
    return 'İşlem gerçekleştirilemedi: ${error.toString()}';
  }

  Future<void> _handleEmailLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    AppHaptic.selection();

    try {
      final authManager = ref.read(authManagerProvider);
      await authManager.signInWithEmail(
        _loginEmailController.text,
        _loginPasswordController.text,
      );

      // Session bootstrap and wipe old user cached providers
      await SessionManager.bootstrapAndRefreshAll(ref);

      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Hoş Geldiniz',
        message: 'Giriş başarılı! Şirketiniz yükleniyor...',
        type: SnackbarType.success,
      );
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Giriş Başarısız',
        message: _mapAuthError(e),
        type: SnackbarType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;
    if (_selectedCity == null) {
      AppSnackbar.show(
        context,
        title: 'Şehir Seçimi Zorunlu',
        message: 'Lütfen holdinginizin merkez şehrini seçin.',
        type: SnackbarType.warning,
      );
      return;
    }

    setState(() => _isLoading = true);
    AppHaptic.selection();

    try {
      final authManager = ref.read(authManagerProvider);
      await authManager.signUpWithEmail(
        _registerEmailController.text,
        _registerPasswordController.text,
      );

      // Session bootstrap with selected headquarters city
      await Supabase.instance.client
          .rpc(
            'bootstrap_game_session',
            params: {
              'p_city_id': _selectedCity!.id,
            },
          )
          .then((_) {})
          .catchError((_) {});

      // Kullanıcının belirlediği holding adını kaydet
      final enteredCompanyName = _registerCompanyNameController.text.trim();
      if (enteredCompanyName.isNotEmpty && enteredCompanyName != 'Yeni Holding') {
        try {
          await Supabase.instance.client.rpc(
            'update_company_name',
            params: {'p_company_name': enteredCompanyName},
          );
        } catch (_) {}
      }

      // Invalidate old providers and refresh state for new user
      await SessionManager.bootstrapAndRefreshAll(ref);

      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Tebrikler!',
        message:
            'Hesabınız oluşturuldu. ${_selectedCity!.name} şehrinde 1 adet Genel Depo (500 Domates + 500 Biber) ve 1 adet Manav kuruldu!',
        type: SnackbarType.success,
      );
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Kayıt Başarısız',
        message: _mapAuthError(e),
        type: SnackbarType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    AppHaptic.selection();

    try {
      final authManager = ref.read(authManagerProvider);
      final response = await authManager.signInWithGoogle();
      if (response == null) {
        // Kullanıcı hesap seçimini iptal etti
        return;
      }

      String? chosenCompanyName;
      CityModel? chosenCity = _selectedCity;

      // Kullanıcının mevcut durumunu kontrol et
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final existingPlayer = await Supabase.instance.client
            .from('players')
            .select('headquarters_city_id')
            .eq('id', user.id)
            .maybeSingle();

        // Eğer yeni kullanıcıysa veya henüz merkez şehir seçilmemişse kurulum penceresini göster
        if (existingPlayer == null ||
            existingPlayer['headquarters_city_id'] == null) {
          final cities = await ref.read(citiesProvider.future);
          if (mounted && cities.isNotEmpty) {
            final result = await _showGoogleOnboardingSheet(
              context,
              cities,
            );
            if (result != null) {
              chosenCity = result.city;
              chosenCompanyName = result.companyName;
              _selectedCity = result.city;
            }
          }
        }
      }

      // Session bootstrap with selected headquarters city
      await Supabase.instance.client
          .rpc(
            'bootstrap_game_session',
            params: {
              if (chosenCity != null) 'p_city_id': chosenCity.id,
            },
          )
          .then((_) {})
          .catchError((_) {});

      // Kullanıcının belirlediği holding adını kaydet
      if (chosenCompanyName != null &&
          chosenCompanyName.trim().isNotEmpty &&
          chosenCompanyName.trim() != 'Yeni Holding') {
        try {
          await Supabase.instance.client.rpc(
            'update_company_name',
            params: {'p_company_name': chosenCompanyName.trim()},
          );
        } catch (_) {}
      }

      // Wipe old user cached providers and refresh core providers for new account
      await SessionManager.bootstrapAndRefreshAll(ref);

      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Hoş Geldiniz',
        message: 'Google ile giriş başarılı! Şirketiniz yükleniyor...',
        type: SnackbarType.success,
      );
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Google Girişi Başarısız',
        message: _mapAuthError(e),
        type: SnackbarType.error,
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(
      text: _loginEmailController.text.trim(),
    );
    bool isSending = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
            side: BorderSide(
              color: AppColors.borderGold.withValues(alpha: 0.6),
            ),
          ),
          title: Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: AppColors.gold),
              SizedBox(width: 10.w),
              Text(
                'Şifremi Unuttum',
                style: AppTextStyles.h2.copyWith(color: AppColors.gold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kayıtlı e-posta adresinizi girin. Size şifre sıfırlama bağlantısı göndereceğiz.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13.sp,
                ),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'E-posta Adresi',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                  prefixIcon: Icon(Icons.email_rounded, color: AppColors.gold),
                  filled: true,
                  fillColor: AppColors.cardBgLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppColors.gold),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'İptal',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            ElevatedButton(
              onPressed: isSending
                  ? null
                  : () async {
                      final email = resetEmailController.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        AppSnackbar.show(
                          context,
                          title: 'Uyarı',
                          message: 'Lütfen geçerli bir e-posta adresi girin.',
                          type: SnackbarType.warning,
                        );
                        return;
                      }

                      setDialogState(() => isSending = true);
                      try {
                        await ref
                            .read(authManagerProvider)
                            .sendPasswordResetEmail(email);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        AppSnackbar.show(
                          context,
                          title: 'Bağlantı Gönderildi',
                          message:
                              'Şifre sıfırlama e-postası gönderildi. Lütfen gelen kutunuzu kontrol edin.',
                          type: SnackbarType.success,
                        );
                      } catch (e) {
                        if (!ctx.mounted) return;
                        setDialogState(() => isSending = false);
                        AppSnackbar.show(
                          context,
                          title: 'Hata',
                          message: _mapAuthError(e),
                          type: SnackbarType.error,
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              child: isSending
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.background,
                      ),
                    )
                  : const Text('Gönder', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 440.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo & Brand Header
                  _buildHeader(),
                  SizedBox(height: 24.h),

                  // Google Sign-In Primary Button
                  _buildGoogleButton(),
                  SizedBox(height: 20.h),

                  // "Veya E-posta ile" Divider
                  _buildDivider(),
                  SizedBox(height: 20.h),

                  // Form Container with Tabs
                  _buildFormCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80.w,
          height: 80.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppColors.gold,
                AppColors.goldDark,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.35),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            AppIcons.monetizationOnRounded,
            color: AppColors.background,
            size: 44.sp,
          ),
        ),
        SizedBox(height: 14.h),
        Text(
          'HARD KAPİTALİZM',
          style: AppTextStyles.h1.copyWith(
            color: AppColors.gold,
            fontSize: 24.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          'Sermayeni Yönet, Ticaret İmparatorluğunu Kur',
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return Container(
      width: double.infinity,
      height: 52.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4285F4),
            Color(0xFF2A68CC),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4285F4).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: (_isGoogleLoading || _isLoading) ? null : _handleGoogleSignIn,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isGoogleLoading)
                  SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else ...[
                  Container(
                    padding: EdgeInsets.all(4.w),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      AppIcons.gMobiledataRounded,
                      color: const Color(0xFF4285F4),
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'Google ile Hızlı Devam Et',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
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

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.border.withValues(alpha: 0.6),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Text(
            'veya e-posta ile',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12.sp,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.border.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: AppColors.borderGold.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tab Bar Switcher
          Container(
            margin: EdgeInsets.all(8.w),
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppColors.cardBgLight,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                color: AppColors.gold,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppColors.background,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Giriş Yap'),
                Tab(text: 'Kayıt Ol'),
              ],
            ),
          ),

          // Tab Views
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                return _tabController.index == 0
                    ? _buildLoginForm()
                    : _buildRegisterForm();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 8.h),
          TextFormField(
            controller: _loginEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: _inputDecoration(
              label: 'E-posta Adresi',
              icon: Icons.email_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Lütfen e-posta adresinizi girin.';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return 'Geçerli bir e-posta adresi girin.';
              }
              return null;
            },
          ),
          SizedBox(height: 14.h),
          TextFormField(
            controller: _loginPasswordController,
            obscureText: _isLoginPasswordObscured,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleEmailLogin(),
            style: TextStyle(color: AppColors.textPrimary),
            decoration: _inputDecoration(
              label: 'Şifre',
              icon: Icons.lock_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _isLoginPasswordObscured
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppColors.textMuted,
                  size: 20.sp,
                ),
                onPressed: () {
                  setState(() {
                    _isLoginPasswordObscured = !_isLoginPasswordObscured;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Lütfen şifrenizi girin.';
              }
              return null;
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showForgotPasswordDialog,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
              ),
              child: Text(
                'Şifremi Unuttum?',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          _buildSubmitButton(
            title: 'GİRİŞ YAP',
            isLoading: _isLoading,
            onPressed: _handleEmailLogin,
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    final citiesAsync = ref.watch(citiesProvider);
    final cities = citiesAsync.value ?? const <CityModel>[];

    if (_selectedCity == null && cities.isNotEmpty) {
      _selectedCity = cities.firstWhere(
        (c) => c.name.toLowerCase().contains('istanbul'),
        orElse: () => cities.first,
      );
    }

    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 8.h),
          TextFormField(
            controller: _registerEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: _inputDecoration(
              label: 'E-posta Adresi',
              icon: Icons.email_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Lütfen e-posta adresinizi girin.';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return 'Geçerli bir e-posta adresi girin.';
              }
              return null;
            },
          ),
          SizedBox(height: 14.h),
          TextFormField(
            controller: _registerPasswordController,
            obscureText: _isRegisterPasswordObscured,
            textInputAction: TextInputAction.next,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: _inputDecoration(
              label: 'Şifre (En az 6 karakter)',
              icon: Icons.lock_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _isRegisterPasswordObscured
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppColors.textMuted,
                  size: 20.sp,
                ),
                onPressed: () {
                  setState(() {
                    _isRegisterPasswordObscured = !_isRegisterPasswordObscured;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.length < 6) {
                return 'Şifre en az 6 karakter olmalıdır.';
              }
              return null;
            },
          ),
          SizedBox(height: 14.h),
          TextFormField(
            controller: _registerPasswordConfirmController,
            obscureText: _isRegisterPasswordConfirmObscured,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleEmailRegister(),
            style: TextStyle(color: AppColors.textPrimary),
            decoration: _inputDecoration(
              label: 'Şifre Tekrar',
              icon: Icons.lock_reset_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _isRegisterPasswordConfirmObscured
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppColors.textMuted,
                  size: 20.sp,
                ),
                onPressed: () {
                  setState(() {
                    _isRegisterPasswordConfirmObscured =
                        !_isRegisterPasswordConfirmObscured;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value != _registerPasswordController.text) {
                return 'Şifreler birbiriyle uyuşmuyor.';
              }
              return null;
            },
          ),
          SizedBox(height: 14.h),
          // Holding Adı Giriş Alanı
          TextFormField(
            controller: _registerCompanyNameController,
            textInputAction: TextInputAction.next,
            maxLength: 25,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: _inputDecoration(
              label: 'Holding / Şirket Adı',
              icon: Icons.apartment_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Lütfen holdinginizin adını girin.';
              }
              return null;
            },
          ),
          SizedBox(height: 6.h),
          // Holding Merkez Şehri Seçim Kutusu
          InkWell(
            borderRadius: BorderRadius.circular(14.r),
            onTap: cities.isEmpty
                ? null
                : () => _showCitySelectionSheet(context, cities),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: AppColors.cardBgLight,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: AppColors.borderGold.withValues(alpha: 0.5),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      Icons.location_city_rounded,
                      color: AppColors.gold,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Holding Merkez Şehri',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11.sp,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          _selectedCity?.name ?? (citiesAsync.isLoading ? 'Şehirler yükleniyor...' : 'Şehir Seçin'),
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.gold,
                    size: 24.sp,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 18.h),
          _buildSubmitButton(
            title: 'HESAP OLUŞTUR & BAŞLA',
            isLoading: _isLoading,
            onPressed: _handleEmailRegister,
          ),
        ],
      ),
    );
  }

  Future<GoogleOnboardingResult?> _showGoogleOnboardingSheet(
    BuildContext context,
    List<CityModel> cities,
  ) async {
    final companyController = TextEditingController(text: 'Yeni Holding');
    String searchQuery = '';
    CityModel chosenCity = _selectedCity ??
        cities.firstWhere(
          (c) => c.name.toLowerCase().contains('istanbul'),
          orElse: () => cities.first,
        );

    return showModalBottomSheet<GoogleOnboardingResult>(
      context: context,
      backgroundColor: AppColors.cardBg,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        side: BorderSide(color: AppColors.borderGold.withValues(alpha: 0.3)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredCities = cities.where((c) {
              final q = searchQuery.trim().toLowerCase();
              if (q.isEmpty) return true;
              return c.name.toLowerCase().contains(q);
            }).toList();

            return PopScope(
              canPop: false,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.85,
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
                child: Column(
                  children: [
                    Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                    SizedBox(height: 14.h),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            Icons.business_center_rounded,
                            color: AppColors.gold,
                            size: 22.sp,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Holdinginizi Kurun',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Holding adınızı ve ana merkez şehrinizi belirleyin.',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14.h),
                    // Holding Adı Giriş Alanı
                    TextField(
                      controller: companyController,
                      maxLength: 25,
                      style: TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Holding / Şirket Adı',
                        labelStyle: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13.sp,
                        ),
                        prefixIcon: Icon(
                          Icons.apartment_rounded,
                          color: AppColors.gold,
                          size: 20.sp,
                        ),
                        filled: true,
                        fillColor: AppColors.cardBgLight,
                        counterStyle: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10.sp,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 12.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: AppColors.border.withValues(alpha: 0.6),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: AppColors.gold,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    // Şehir Arama
                    TextField(
                      onChanged: (val) {
                        setModalState(() {
                          searchQuery = val;
                        });
                      },
                      style: TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Merkez Şehir Ara (81 İl)...',
                        hintStyle: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13.sp,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: AppColors.gold,
                          size: 20.sp,
                        ),
                        filled: true,
                        fillColor: AppColors.cardBgLight,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 10.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: AppColors.border.withValues(alpha: 0.6),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: AppColors.gold,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filteredCities.length,
                        separatorBuilder: (_, _) => Divider(
                          color: AppColors.border.withValues(alpha: 0.3),
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final city = filteredCities[index];
                          final isSelected = chosenCity.id == city.id;

                          return ListTile(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 2.h,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: isSelected
                                  ? AppColors.gold
                                  : AppColors.cardBgLight,
                              radius: 16.r,
                              child: Icon(
                                Icons.location_city_rounded,
                                color: isSelected
                                    ? AppColors.background
                                    : AppColors.gold,
                                size: 16.sp,
                              ),
                            ),
                            title: Text(
                              city.name,
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.gold
                                    : AppColors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 13.sp,
                              ),
                            ),
                            subtitle: Text(
                              'Nüfus: ${AppMoney.full(city.population, withSymbol: false)}',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11.sp,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.gold,
                                    size: 20.sp,
                                  )
                                : null,
                            onTap: () {
                              setModalState(() {
                                chosenCity = city;
                              });
                            },
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 10.h),
                    // Onaylama Butonu
                    Container(
                      width: double.infinity,
                      height: 48.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.r),
                        gradient: LinearGradient(
                          colors: [
                            AppColors.gold,
                            AppColors.goldDark,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        onPressed: () {
                          final cName = companyController.text.trim();
                          Navigator.pop(
                            ctx,
                            GoogleOnboardingResult(
                              city: chosenCity,
                              companyName:
                                  cName.isEmpty ? 'Yeni Holding' : cName,
                            ),
                          );
                        },
                        child: Text(
                          '${chosenCity.name} Merkezli Kur & Başla',
                          style: TextStyle(
                            color: AppColors.background,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<CityModel?> _showCitySelectionSheet(
    BuildContext context,
    List<CityModel> cities, {
    bool isMandatory = false,
    String? title,
    String? subtitle,
  }) async {
    return showModalBottomSheet<CityModel>(
      context: context,
      backgroundColor: AppColors.cardBg,
      isScrollControlled: true,
      isDismissible: !isMandatory,
      enableDrag: !isMandatory,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        side: BorderSide(color: AppColors.borderGold.withValues(alpha: 0.3)),
      ),
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredCities = cities.where((c) {
              final q = searchQuery.trim().toLowerCase();
              if (q.isEmpty) return true;
              return c.name.toLowerCase().contains(q);
            }).toList();

            return PopScope(
              canPop: !isMandatory,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75,
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
                child: Column(
                  children: [
                    Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                    SizedBox(height: 14.h),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            Icons.location_city_rounded,
                            color: AppColors.gold,
                            size: 22.sp,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title ?? 'Holding Merkez Şehri Seçin',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                subtitle ??
                                    'Ticaret imparatorluğunuzun ana merkez üssü',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14.h),
                    TextField(
                      onChanged: (val) {
                        setModalState(() {
                          searchQuery = val;
                        });
                      },
                      style: TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Şehir ara (81 İl)...',
                        hintStyle: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13.sp,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: AppColors.gold,
                          size: 20.sp,
                        ),
                        filled: true,
                        fillColor: AppColors.cardBgLight,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 12.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: AppColors.border.withValues(alpha: 0.6),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: AppColors.gold,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filteredCities.length,
                        separatorBuilder: (_, _) => Divider(
                          color: AppColors.border.withValues(alpha: 0.3),
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final city = filteredCities[index];
                          final isSelected = _selectedCity?.id == city.id;

                          return ListTile(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 2.h,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: isSelected
                                  ? AppColors.gold
                                  : AppColors.cardBgLight,
                              radius: 18.r,
                              child: Icon(
                                Icons.apartment_rounded,
                                color: isSelected
                                    ? AppColors.background
                                    : AppColors.gold,
                                size: 18.sp,
                              ),
                            ),
                            title: Text(
                              city.name,
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.gold
                                    : AppColors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 14.sp,
                              ),
                            ),
                            subtitle: Text(
                              'Nüfus: ${AppMoney.full(city.population, withSymbol: false)}',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11.sp,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.gold,
                                    size: 20.sp,
                                  )
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedCity = city;
                              });
                              Navigator.pop(ctx, city);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: AppColors.textMuted,
        fontSize: 13.sp,
      ),
      prefixIcon: Icon(icon, color: AppColors.gold, size: 20.sp),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.cardBgLight,
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(color: AppColors.gold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(color: AppColors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(color: AppColors.red, width: 1.5),
      ),
    );
  }

  Widget _buildSubmitButton({
    required String title,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 50.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.r),
        gradient: LinearGradient(
          colors: [
            AppColors.gold,
            AppColors.goldDark,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 22.w,
                height: 22.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.background,
                ),
              )
            : Text(
                title,
                style: TextStyle(
                  color: AppColors.background,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }
}
