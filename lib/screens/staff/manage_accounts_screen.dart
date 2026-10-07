import 'package:flutter/material.dart';

import '../../models/college.dart';
import '../../services/admin_service.dart';
import '../../services/laboratory_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_feedback.dart';
import '../../widgets/borrow_log_app_bar.dart';

class ManageAccountsScreen extends StatefulWidget {
  const ManageAccountsScreen({super.key});

  @override
  State<ManageAccountsScreen> createState() => _ManageAccountsScreenState();
}

class _ManageAccountsScreenState extends State<ManageAccountsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = AdminService();
  final _labService = LaboratoryService();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _courseController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _departmentController = TextEditingController();

  List<College> _colleges = [];
  College? _selectedCollege;
  bool _loadingColleges = true;

  String _role = 'student';
  bool _saving = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadColleges();
  }

  Future<void> _loadColleges() async {
    try {
      final list = await _labService.fetchColleges();
      if (!mounted) return;
      setState(() {
        _colleges = list;
        _loadingColleges = false;
      });
    } catch (e) {
      if (!mounted) return;
      // ignore: avoid_print
      print('📋 [manage-accounts] load colleges failed: $e');
      setState(() {
        _error = 'Could not load colleges. Please try again.';
        _loadingColleges = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _studentIdController.dispose();
    _courseController.dispose();
    _employeeIdController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final email = _emailController.text.trim();

    final result = await _service.createUser(
      email: email,
      password: _passwordController.text,
      fullName: _fullNameController.text.trim(),
      role: _role,
      studentId: _studentIdController.text,
      course: _courseController.text,
      college: _role == 'student' ? _selectedCollege?.name : null,
      employeeId: _employeeIdController.text,
      department: _departmentController.text,
    );

    if (!mounted) return;

    if (result.success) {
      // ✅ Clear success toast
      AppFeedback.success(
        context,
        'Account created · $email ($_role)',
      );

      // Clear the form for the next account
      _emailController.clear();
      _passwordController.clear();
      _fullNameController.clear();
      _studentIdController.clear();
      _courseController.clear();
      _employeeIdController.clear();
      _departmentController.clear();
      setState(() {
        _selectedCollege = null;
        _saving = false;
      });
      _formKey.currentState?.reset();
    } else {
      // Log raw error, show friendly message
      // ignore: avoid_print
      print('📋 [manage-accounts] create failed: ${result.errorMessage}');
      setState(() {
        _saving = false;
        _error =
            result.errorMessage ?? 'Could not create account. Please try again.';
      });
    }
  }

  // ---------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------

  InputDecoration _decoration(
    String label, {
    String? hint,
    String? helper,
    IconData? icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperMaxLines: 2,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.maroon.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppTheme.maroon),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _gap() => const SizedBox(height: 14);

  /// Red error banner — kept for inline form errors.
  Widget _errorBanner(String message) {
    return Container(
      key: ValueKey(message),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: Colors.red.shade700.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.red.shade700.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            icon: Icon(Icons.close, size: 18, color: Colors.red.shade700),
            onPressed: () => setState(() => _error = null),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loadingColleges) {
      return const Scaffold(
        appBar: BorrowLogAppBar(title: 'Manage accounts'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isStudent = _role == 'student';

    return Scaffold(
      appBar: const BorrowLogAppBar(title: 'Manage accounts'),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create account',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add a new student or staff member. They can sign in '
                      'right away with the temporary password.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 20),

                    // ---- Role ----
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: 'student',
                          icon: Icon(Icons.school_outlined),
                          label: Text('Student'),
                        ),
                        ButtonSegment(
                          value: 'staff',
                          icon: Icon(Icons.badge_outlined),
                          label: Text('Staff'),
                        ),
                      ],
                      selected: {_role},
                      onSelectionChanged: _saving
                          ? null
                          : (s) => setState(() => _role = s.first),
                    ),
                    const SizedBox(height: 16),

                    // ---- Sign-in details ----
                    _section(
                      icon: Icons.lock_outline,
                      title: 'Sign-in details',
                      children: [
                        TextFormField(
                          controller: _emailController,
                          enabled: !_saving,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          decoration: _decoration(
                            'Email *',
                            hint: 'name@umindanao.edu.ph',
                            icon: Icons.mail_outline,
                          ),
                          validator: (v) {
                            final s = v?.trim() ?? '';
                            if (s.isEmpty) return 'Required';
                            if (!s.contains('@')) return 'Invalid email';
                            return null;
                          },
                        ),
                        _gap(),
                        TextFormField(
                          controller: _passwordController,
                          enabled: !_saving,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          decoration: _decoration(
                            'Temporary password *',
                            helper:
                                'At least 6 characters. Ask the user to change it after first login.',
                            icon: Icons.key_outlined,
                            suffix: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (v.length < 6) return 'At least 6 characters';
                            return null;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ---- Personal + role-specific ----
                    _section(
                      icon: isStudent
                          ? Icons.school_outlined
                          : Icons.badge_outlined,
                      title: isStudent ? 'Student profile' : 'Staff profile',
                      children: [
                        TextFormField(
                          controller: _fullNameController,
                          enabled: !_saving,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: _decoration(
                            'Full name *',
                            icon: Icons.person_outline,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        _gap(),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: isStudent
                              ? Column(
                                  key: const ValueKey('student-fields'),
                                  children: [
                                    DropdownButtonFormField<College>(
                                      initialValue: _selectedCollege,
                                      isExpanded: true,
                                      decoration: _decoration(
                                        'College *',
                                        icon: Icons.account_balance_outlined,
                                      ),
                                      items: _colleges
                                          .map(
                                            (c) => DropdownMenuItem(
                                              value: c,
                                              child: Text(
                                                c.name,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: _saving
                                          ? null
                                          : (v) => setState(
                                                () => _selectedCollege = v,
                                              ),
                                      validator: (v) =>
                                          v == null ? 'Required' : null,
                                    ),
                                    _gap(),
                                    TextFormField(
                                      controller: _studentIdController,
                                      enabled: !_saving,
                                      textInputAction: TextInputAction.next,
                                      decoration: _decoration(
                                        'Student ID',
                                        hint: 'e.g. 2024-00001',
                                        icon: Icons.numbers,
                                      ),
                                    ),
                                    _gap(),
                                    TextFormField(
                                      controller: _courseController,
                                      enabled: !_saving,
                                      textInputAction: TextInputAction.done,
                                      decoration: _decoration(
                                        'Course',
                                        icon: Icons.menu_book_outlined,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  key: const ValueKey('staff-fields'),
                                  children: [
                                    TextFormField(
                                      controller: _employeeIdController,
                                      enabled: !_saving,
                                      textInputAction: TextInputAction.next,
                                      decoration: _decoration(
                                        'Employee ID',
                                        icon: Icons.numbers,
                                      ),
                                    ),
                                    _gap(),
                                    TextFormField(
                                      controller: _departmentController,
                                      enabled: !_saving,
                                      textInputAction: TextInputAction.done,
                                      decoration: _decoration(
                                        'Department',
                                        icon: Icons.apartment_outlined,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),

                    // ---- Error banner (success is now a toast) ----
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      alignment: Alignment.topCenter,
                      child: _error == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: _errorBanner(_error!),
                            ),
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _submit,
                        icon: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.person_add_alt_1),
                        label: Text(
                          _saving ? 'Creating…' : 'Create account',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.maroon,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}