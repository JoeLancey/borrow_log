import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_components.dart';
import '../shared/change_password_screen.dart';
import '../staff/staff_dashboard.dart';
import '../student/student_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email and password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.login(
      email: email,
      password: password,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _isLoading = false;
        _errorMessage = result.errorMessage ?? 'Login failed.';
      });
      return;
    }

    setState(() => _isLoading = false);

    // Force password change for newly provisioned accounts.
    if (result.mustChangePassword) {
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const ChangePasswordScreen(forced: true),
        ),
      );
      if (!mounted) return;
      if (changed != true) {
        await AuthService().logout();
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'You must set a new password before using the app.';
        });
        return;
      }
    }

    if (!mounted) return;

    final role = result.role;
    if (role == 'student') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const StudentDashboard()),
      );
    } else if (role == 'staff') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const StaffDashboard()),
      );
    } else {
      setState(() {
        _errorMessage = 'Invalid or missing role. Please contact support.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary,
                  theme.brightness == Brightness.dark
                      ? AppColors.maroon900
                      : AppColors.maroon600,
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: Flex(
                      direction: wide ? Axis.horizontal : Axis.vertical,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (wide)
                          Expanded(child: _brandPanel(theme))
                        else
                          _brandMark(theme),
                        SizedBox(
                          width: wide ? AppSpacing.xxxl : 0,
                          height: wide ? 0 : AppSpacing.xl,
                        ),
                        SizedBox(
                          width: wide ? 440 : double.infinity,
                          child: _loginCard(theme),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _brandMark(ThemeData theme) {
    return Column(
      children: [
        const UmBrandMark(size: 76),
        const SizedBox(height: AppSpacing.lg),
        Text('BORROW LOG',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              letterSpacing: 1.4,
            )),
      ],
    );
  }

  Widget _brandPanel(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const UmBrandMark(size: 82),
          const SizedBox(height: AppSpacing.xl),
          Text('Borrow with clarity.',
              style: theme.textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: AppSpacing.md),
          Text(
            'A calmer way to reserve, release, and return laboratory equipment across the University of Mindanao.',
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            width: 56,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.gold500,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loginCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Welcome back', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text('Sign in with your UM account to continue.',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              controller: _emailController,
              label: 'UM email',
              hint: 'name@umindanao.edu.ph',
              prefixIcon: Icons.email_outlined,
              enabled: !_isLoading,
              keyboardType: TextInputType.emailAddress,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _passwordController,
              label: 'Password',
              prefixIcon: Icons.lock_outline,
              enabled: !_isLoading,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleLogin(),
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                icon: Icon(_obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(
                    () => _obscurePassword = !_obscurePassword),
              ),                                            
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading ? null : _showForgotPassword,
                child: const Text('Forgot password?'),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: theme.colorScheme.onErrorContainer),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(_errorMessage!,
                            style: TextStyle(
                                color: theme.colorScheme.onErrorContainer)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Sign in',
                icon: Icons.arrow_forward,
                loading: _isLoading,
                onPressed: _handleLogin,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showForgotPassword() async {
    final emailController = TextEditingController(text: _emailController.text);
    String? error;
    var loading = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reset your password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Enter your UM email and we will send you a secure reset link.'),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: emailController,
                enabled: !loading,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'UM email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(error!, style: TextStyle(color: Colors.red)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      final email = emailController.text.trim();
                      if (email.isEmpty) {
                        setDialogState(() => error = 'Enter your UM email address.');
                        return;
                      }
                      setDialogState(() {
                        loading = true;
                        error = null;
                      });
                      final result = await _authService.requestPasswordReset(email: email);
                      if (!dialogContext.mounted) return;
                      if (!result.success) {
                        setDialogState(() {
                          loading = false;
                          error = result.errorMessage;
                        });
                        return;
                      }
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Check your email for a secure password reset link.')),
                      );
                    },
              child: loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Send link'),
            ),
          ],
        ),
      ),
    );
    emailController.dispose();
  }
}