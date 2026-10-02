import 'package:flutter/material.dart';

import '../../services/inventory_service.dart';
import '../../services/auth_service.dart';
import '../../services/reservation_service.dart';
import '../../features/reservations/domain/reservation_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_components.dart';
import '../../widgets/borrow_log_app_bar.dart';
import '../auth/login_screen.dart';
import 'inventory_screen.dart';
import 'manage_accounts_screen.dart';
import 'reports_screen.dart';
import 'search_reservations_screen.dart';
import 'staff_reservations_screen.dart';

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  final ReservationRepository _reservationService = ReservationService();
  final _inventoryService = InventoryService();
  late Future<_StaffSummary> _summary;
  String _firstName = 'there';
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _summary = _loadSummary();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await AuthService().getCurrentProfile();
      if (!mounted) return;
      final fullName = (profile?['full_name'] ?? '').toString().trim();
      final firstName = fullName.isEmpty
          ? 'there'
          : fullName.split(RegExp(r'\s+')).first;
      setState(() {
        _firstName = firstName.length > 18 ? '${firstName.substring(0, 17)}…' : firstName;
        _loadingProfile = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _firstName = 'there';
        _loadingProfile = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _summary = _loadSummary();
    });
  }

  Future<_StaffSummary> _loadSummary() async {
    final reservations = await _reservationService.fetchAllReservations();
    final assets = await _inventoryService.fetchAssets();
    final today = DateTime.now();
    final dueToday = reservations.where((r) {
      final due = r.dueDate;
      return r.status == 'borrowed' &&
          due != null &&
          due.year == today.year &&
          due.month == today.month &&
          due.day == today.day;
    }).length;
    return _StaffSummary(
      pending: reservations.where((r) => r.status == 'pending').length,
      overdue: reservations.where((r) => r.isOverdue).length,
      dueToday: dueToday,
      availableAssets: assets.where((a) => a.status == 'available').length,
    );
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BorrowLogAppBar(
        title: 'BorrowLog',
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppTheme.maroon,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _loadingProfile
                      ? _profileSkeleton()
                      : Text(
                          _greetingText(),
                          style: Theme.of(context).textTheme.headlineMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Keep today\'s equipment movement accurate and predictable.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(
                    title: 'Today at a glance',
                    subtitle: 'The numbers that need attention first',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FutureBuilder<_StaffSummary>(
                    future: _summary,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      final summary = snapshot.data!;
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final cardWidth = constraints.maxWidth >= 720
                              ? (constraints.maxWidth - AppSpacing.md * 3) / 4
                              : (constraints.maxWidth - AppSpacing.md) / 2;
                          return Wrap(
                            spacing: AppSpacing.md,
                            runSpacing: AppSpacing.md,
                            children: [
                              SizedBox(
                                width: cardWidth,
                                child: _summaryCard(
                                  context,
                                  label: 'Pending requests',
                                  value: '${summary.pending}',
                                  icon: Icons.pending_actions_outlined,
                                  accent: summary.pending > 0
                                      ? AppTheme.statusPending
                                      : Colors.green,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const SearchReservationsScreen(),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _summaryCard(
                                  context,
                                  label: 'Overdue loans',
                                  value: '${summary.overdue}',
                                  icon: Icons.warning_amber_outlined,
                                  accent: summary.overdue > 0
                                      ? AppTheme.statusOverdue
                                      : Colors.green,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const SearchReservationsScreen(),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _summaryCard(
                                  context,
                                  label: 'Due today',
                                  value: '${summary.dueToday}',
                                  icon: Icons.today_outlined,
                                  accent: AppTheme.statusBorrowed,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const SearchReservationsScreen(),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _summaryCard(
                                  context,
                                  label: 'Available assets',
                                  value: '${summary.availableAssets}',
                                  icon: Icons.inventory_2_outlined,
                                  accent: AppTheme.statusApproved,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const InventoryScreen(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(
                    title: 'Workspace',
                    subtitle: 'Quick access to the tools you use most',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Column(
                    children: [
                      _menuTile(
                        context,
                        icon: Icons.inventory_2_outlined,
                        title: 'Inventory',
                        subtitle: 'Types and assets',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const InventoryScreen()),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _menuTile(
                        context,
                        icon: Icons.pending_actions_outlined,
                        title: 'Reservations',
                        subtitle: 'Review and manage',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StaffReservationsScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _menuTile(
                        context,
                        icon: Icons.search,
                        title: 'Search',
                        subtitle: 'Find records',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SearchReservationsScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _menuTile(
                        context,
                        icon: Icons.bar_chart_outlined,
                        title: 'Reports',
                        subtitle: 'Insights',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ReportsScreen()),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _menuTile(
                        context,
                        icon: Icons.manage_accounts_outlined,
                        title: 'Accounts',
                        subtitle: 'Create users',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ManageAccountsScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.maroon,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.maroon100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.maroon, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  String _greetingText() {
    final hour = DateTime.now().hour;
    final label = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';
    return '$label, $_firstName';
  }

  Widget _profileSkeleton() {
    return Container(
      width: 210,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _StaffSummary {
  final int pending;
  final int overdue;
  final int dueToday;
  final int availableAssets;

  const _StaffSummary({
    required this.pending,
    required this.overdue,
    required this.dueToday,
    required this.availableAssets,
  });
}