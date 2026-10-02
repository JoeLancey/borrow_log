import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/widgets/connectivity_banner.dart';
import 'theme/app_theme.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/shared/loading_screen.dart';
import 'screens/staff/staff_dashboard.dart';
import 'screens/student/student_dashboard.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment()..validate();
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
    return Builder(
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery,
          child: MaterialApp(
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
            home: config == null
              ? const _AuthEntryPoint()
              : _StartupGate(config: config!),
          ),
        );
      },
    );
  }
}

class _StartupGate extends StatefulWidget {
  const _StartupGate({required this.config});

  final AppConfig config;

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  Future<void>? _initialization;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _initialization = _initializeSupabase(widget.config);
      });
    });
  }

  void _retry() {
    setState(() {
      _initialization = _initializeSupabase(widget.config);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_initialization == null) return const LoadingScreen();

    return FutureBuilder<void>(
      future: _initialization!,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingScreen();
        }
        if (snapshot.hasError) {
          return _StartupErrorScreen(onRetry: _retry);
        }
        return const _AuthEntryPoint();
      },
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