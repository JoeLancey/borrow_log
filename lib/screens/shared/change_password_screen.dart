import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class ChangePasswordScreen extends StatefulWidget {
  /// If true, the back button is hidden — used for forced first-login change.
  final bool forced;

  const ChangePasswordScreen({super.key, this.forced = false});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  final _service = AuthService();

  bool _saving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final result = await _service.changePassword(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
    );

    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = result.errorMessage ?? 'Failed to change password.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.forced,
      child: Scaffold(
        appBar: AppBar(
          title:
              Text(widget.forced ? 'Set a new password' : 'Change Password'),
          automaticallyImplyLeading: !widget.forced,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.forced) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.amber.shade800),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'For security, please replace the temporary '
                            'password you received before continuing.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                TextFormField(
                  controller: _currentController,
                  enabled: !_saving,
                  obscureText: _obscureCurrent,
                  decoration: InputDecoration(
                    labelText: widget.forced
                        ? 'Temporary Password *'
                        : 'Current Password *',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureCurrent
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setState(
                          () => _obscureCurrent = !_obscureCurrent),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _newController,
                  enabled: !_saving,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Password *',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNew
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 6) return 'At least 6 characters';
                    if (v == _currentController.text) {
                      return 'New password must differ from the current one';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _confirmController,
                  enabled: !_saving,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password *',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setState(
                          () => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v != _newController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style:
                                  TextStyle(color: Colors.red.shade700)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.maroon,
                      foregroundColor: Colors.white,
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('UPDATE PASSWORD'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}