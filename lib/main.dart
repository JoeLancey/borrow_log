import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/widgets/connectivity_banner.dart';
import 'theme/app_theme.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/shared/animated_splash_screen.dart';
import 'screens/shared/loading_screen.dart';
import 'screens/staff/staff_dashboard.dart';
import 'screens/student/student_dashboard.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  runApp(BorrowLogApp(config: config));
}

Future<void> _initializeSupabase(AppConfig config) async {
  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabasePublishableKey,
  ).timeout(const Duration(seconds: 10));
}

class BorrowLogApp extends StatelessWidget {
  const BorrowLogApp({super.key, this.config});

  final AppConfig? config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Borrow Log',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      builder: (context, child) => Stack(
        children: [
          child ?? const SizedBox.shrink(),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ConnectivityBanner(),
          ),
        ],
      ),
      // Splash is ALWAYS the entry point.
      home: _StartupGate(config: config),
    );
  }
}

/// Shows the animated splash first, then:
///   1. Validates the config
///   2. Initializes Supabase (in parallel during the splash)
///   3. Routes to login / dashboard / error screen
///
/// The splash → next-screen transition is a smooth crossfade thanks
/// to [AnimatedSwitcher] — no black gap, no white flash.
class _StartupGate extends StatefulWidget {
  const _StartupGate({this.config});

  final AppConfig? config;

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  Future<void>? _initialization;
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();

    // Kick off Supabase init in parallel with the splash animation,
    // but only if config is present and valid.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cfg = widget.config;
      if (cfg != null && cfg.isValid) {
        setState(() {
          _initialization = _initializeSupabase(cfg);
        });
      }
    });
  }

  void _retry() {
    final cfg = widget.config;
    if (cfg == null || !cfg.isValid) return;
    setState(() {
      _initialization = _initializeSupabase(cfg);
    });
  }

  /// Builds whichever screen should currently be shown. The result is
  /// wrapped in an [AnimatedSwitcher] in [build] so each transition is
  /// a smooth crossfade.
  Widget _buildCurrentScreen() {
    // 1. Splash first.
    if (!_splashDone) {
      return AnimatedSplashScreen(
        key: const ValueKey('splash'),
        onFinished: () {
          if (!mounted) return;
          setState(() => _splashDone = true);
        },
      );
    }

    // 2. Validate config.
    final cfg = widget.config;
    if (cfg == null || !cfg.isValid) {
      return const KeyedSubtree(
        key: ValueKey('config-error'),
        child: _ConfigurationErrorScreen(),
      );
    }

    // 3. Wait for Supabase init.
    if (_initialization == null) {
      return const KeyedSubtree(
        key: ValueKey('loading-init'),
        child: LoadingScreen(),
      );
    }

    return FutureBuilder<void>(
      key: const ValueKey('auth-init'),
      future: _initialization!,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const KeyedSubtree(
            key: ValueKey('loading-future'),
            child: LoadingScreen(),
          );
        }
        if (snapshot.hasError) {
          return KeyedSubtree(
            key: const ValueKey('startup-error'),
            child: _StartupErrorScreen(onRetry: _retry),
          );
        }
        return const KeyedSubtree(
          key: ValueKey('auth-entry'),
          child: _AuthEntryPoint(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      // Fade + subtle scale so the swap feels intentional.
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: _buildCurrentScreen(),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.colorScheme.primary, AppColors.maroon900],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined,
                    color: Colors.white, size: 56),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'BorrowLog could not connect',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthEntryPoint extends StatefulWidget {
  const _AuthEntryPoint();

  @override
  State<_AuthEntryPoint> createState() => _AuthEntryPointState();
}

class _AuthEntryPointState extends State<_AuthEntryPoint> {
  bool _isRecovery = false;
  bool _isResolvingSession = true;
  String? _role;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    try {
      _resolveSession();
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
        (data) {
          if (!mounted) return;
          if (data.event == AuthChangeEvent.passwordRecovery) {
            setState(() => _isRecovery = true);
            return;
          }
          _resolveSession();
        },
      );
    } catch (_) {
      // Widget tests can render the app before Supabase is initialized.
      _isResolvingSession = false;
    }
  }

  Future<void> _resolveSession() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _role = null;
          _isRecovery = false;
          _isResolvingSession = false;
        });
        return;
      }

      final profile = await AuthService()
          .getCurrentProfile()
          .timeout(const Duration(seconds: 8));
      final role = profile?['role'] as String?;
      if (!mounted) return;
      setState(() {
        _role = role == 'student' || role == 'staff' ? role : null;
        _isResolvingSession = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _role = null;
        _isResolvingSession = false;
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isRecovery) return const ResetPasswordScreen();
    if (_isResolvingSession) {
      return const LoadingScreen();
    }
    if (_role == 'student') return const StudentDashboard();
    if (_role == 'staff') return const StaffDashboard();
    return const LoginScreen();
  }
}

class _ConfigurationErrorScreen extends StatelessWidget {
  const _ConfigurationErrorScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.settings_outlined,
                size: 56,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'App configuration is missing',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Run this build with SUPABASE_URL and either '
                'SUPABASE_PUBLISHABLE_KEY or SUPABASE_ANON_KEY.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}