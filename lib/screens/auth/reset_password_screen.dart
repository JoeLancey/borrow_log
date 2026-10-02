import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_components.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (_loading) return;
    final password = _passwordController.text;
    final confirmation = _confirmController.text;
    if (password.length < 8) {
      setState(() => _error = 'Use at least 8 characters for your new password.');
      return;
    }
    if (password != confirmation) {
      setState(() => _error = 'The passwords do not match.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _authService.updateRecoveredPassword(
      newPassword: password,
    );
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _loading = false;
        _error = result.errorMessage;
      });
      return;
    }

    await _authService.logout();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Password updated'),
        content: const Text(
          'Your password has been changed. You can now sign in with your new password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue'),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.colorScheme.primary, AppColors.maroon600],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                          const Center(child: UmBrandMark(size: 64)),
                          const SizedBox(height: AppSpacing.xl),
                        Text('Create a new password', style: theme.textTheme.headlineSmall),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                            'Choose a strong password to secure your Borrow Log account.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        AppTextField(
                          controller: _passwordController,
                          label: 'New password',
                          prefixIcon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          enabled: !_loading,
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                            icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          controller: _confirmController,
                          label: 'Confirm new password',
                          prefixIcon: Icons.lock_reset_outlined,
                          obscureText: _obscureConfirm,
                          enabled: !_loading,
                          onSubmitted: (_) => _updatePassword(),
                          suffixIcon: IconButton(
                            tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
                            icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        AppButton(
                          label: 'Update password',
                          icon: Icons.check_rounded,
                          loading: _loading,
                          onPressed: _updatePassword,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}