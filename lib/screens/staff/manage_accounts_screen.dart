import 'package:flutter/material.dart';

import '../../models/college.dart';
import '../../services/admin_service.dart';
import '../../services/laboratory_service.dart';
import '../../theme/app_theme.dart';

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
  String? _success;

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
      setState(() {
        _error = 'Failed to load colleges: $e';
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
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });

    final result = await _service.createUser(
      email: _emailController.text.trim(),
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
      setState(() {
        _saving = false;
        _success =
            'Account created: ${_emailController.text.trim()} ($_role)';
      });
      _emailController.clear();
      _passwordController.clear();
      _fullNameController.clear();
      _studentIdController.clear();
      _courseController.clear();
      _employeeIdController.clear();
      _departmentController.clear();
      setState(() => _selectedCollege = null);
    } else {
      setState(() {
        _saving = false;
        _error = result.errorMessage ?? 'Failed to create account.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingColleges) {
      return Scaffold(
        appBar: AppBar(title: const Text('Manage Accounts')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Accounts')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create a new student or staff account.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(
                  labelText: 'Role *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'student', child: Text('Student')),
                  DropdownMenuItem(value: 'staff', child: Text('Staff')),
                ],
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _role = v ?? 'student'),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailController,
                enabled: !_saving,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  hintText: 'name@umindanao.edu.ph',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (s.isEmpty) return 'Required';
                  if (!s.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _passwordController,
                enabled: !_saving,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Temporary Password *',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 6) return 'At least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _fullNameController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              if (_role == 'student') ...[
                DropdownButtonFormField<College>(
                  initialValue: _selectedCollege,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'College *',
                    border: OutlineInputBorder(),
                  ),
                  items: _colleges
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(
                              c.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _selectedCollege = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _studentIdController,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Student ID',
                    hintText: 'e.g. 2024-00001',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _courseController,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Course',
                    border: OutlineInputBorder(),
                  ),
                ),
              ] else ...[
                TextFormField(
                  controller: _employeeIdController,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Employee ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _departmentController,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

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
                            style: TextStyle(color: Colors.red.shade700)),
                      ),
                    ],
                  ),
                ),
              ],

              if (_success != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_success!,
                            style:
                                TextStyle(color: Colors.green.shade700)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
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
                  label: Text(_saving ? 'Creating…' : 'CREATE ACCOUNT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.maroon,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}