import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/app_theme.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://pponevrnsnuzjbcnwvlg.supabase.co',
    publishableKey: 'sb_publishable_WmHaWEZS0WjXQYsqYJH5-g_4aAMzNKW',
  );

  runApp(const BorrowLogApp());
}

class BorrowLogApp extends StatelessWidget {
  const BorrowLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final clampedScale = mediaQuery.textScaler.clamp(maxScaleFactor: 1.2);
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: clampedScale),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Borrow Log',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            home: const _AuthEntryPoint(),
          ),
        );
      },
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
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    try {
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
        (data) {
          if (!mounted) return;
          setState(() => _isRecovery = data.event == AuthChangeEvent.passwordRecovery);
        },
      );
    } catch (_) {
      // Widget tests can render the app before Supabase is initialized.
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isRecovery ? const ResetPasswordScreen() : const LoginScreen();
  }
}