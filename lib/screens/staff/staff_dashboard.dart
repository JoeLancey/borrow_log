import 'package:flutter/material.dart';

import '../../services/inventory_service.dart';
import '../../services/auth_service.dart';
import '../../services/reservation_service.dart';
import '../../features/reservations/domain/reservation_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_feedback.dart';
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
        _firstName = firstName.length > 18
            ? '${firstName.substring(0, 17)}…'
            : firstName;
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
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Log out of BorrowLog?',
      message: 'You can sign in again whenever you need to manage the lab.',
      confirmLabel: 'Log out',
    );
    if (!confirmed) return;
    if (!context.mounted) return;

    await AuthService().logout();
    if (!context.mounted) return;

    AppFeedback.info(context, 'Signed out');
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BorrowLogAppBar(
        title: 'BorrowLog',
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
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
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _header(),
                  const SizedBox(height: AppSpacing.lg),
                  FutureBuilder<_StaffSummary>(
                    future: _summary,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return _glanceSkeleton();
                      }
                      if (snapshot.hasError) {
                        return _glanceError();
                      }
                      final summary = snapshot.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _statusBanner(summary),
                          SectionHeader(
                            title: 'Today at a glance',
                            subtitle: 'Tap a card to jump to the details',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _glanceGrid(summary),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(
                    title: 'Workspace',
                    subtitle: 'Quick access to the tools you use most',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _workspaceCard(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final scheme = Theme.of(context).colorScheme;
    if (_loadingProfile) return _profileSkeleton();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _greetingText(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              _dateLabel(),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.maroon.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Text(
                'Staff',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.maroon,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statusBanner(_StaffSummary s) {
    final bool hasOverdue = s.overdue > 0;
    final bool allClear = s.overdue == 0 && s.pending == 0 && s.dueToday == 0;
    if (!hasOverdue && !allClear) return const SizedBox.shrink();

    final color = hasOverdue
        ? AppTheme.statusOverdue
        : AppTheme.statusApproved;
    final icon = hasOverdue
        ? Icons.warning_amber_rounded
        : Icons.check_circle_outline;
    final text = hasOverdue
        ? '${s.overdue} overdue loan${s.overdue == 1 ? '' : 's'} need attention'
        : 'All caught up. Nothing needs your attention right now.';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Material(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: hasOverdue
              ? () => _open(const SearchReservationsScreen())
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (hasOverdue) Icon(Icons.chevron_right_rounded, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _glanceGrid(_StaffSummary summary) {
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
              child: _GlanceTile(
                label: 'Pending',
                value: summary.pending,
                caption:
                    summary.pending == 0 ? 'All caught up' : 'Needs review',
                icon: Icons.pending_actions_outlined,
                color: AppTheme.statusPending,
                emphasize: summary.pending > 0,
                onTap: () => _open(const SearchReservationsScreen()),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _GlanceTile(
                label: 'Overdue',
                value: summary.overdue,
                caption:
                    summary.overdue == 0 ? 'All caught up' : 'Needs attention',
                icon: Icons.warning_amber_rounded,
                color: AppTheme.statusOverdue,
                emphasize: summary.overdue > 0,
                onTap: () => _open(const SearchReservationsScreen()),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _GlanceTile(
                label: 'Due today',
                value: summary.dueToday,
                caption:
                    summary.dueToday == 0 ? 'Nothing due' : 'Return today',
                icon: Icons.today_outlined,
                color: AppTheme.statusBorrowed,
                emphasize: summary.dueToday > 0,
                onTap: () => _open(const SearchReservationsScreen()),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _GlanceTile(
                label: 'Available',
                value: summary.availableAssets,
                caption: 'Ready to borrow',
                icon: Icons.inventory_2_outlined,
                color: AppTheme.statusApproved,
                onTap: () => _open(const InventoryScreen()),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _glanceSkeleton() {
    final scheme = Theme.of(context).colorScheme;
    Widget box() => Container(
          height: 92,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(18),
          ),
        );
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: box()),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: box()),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: box()),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: box()),
          ],
        ),
      ],
    );
  }

  Widget _glanceError() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: scheme.error),
          const SizedBox(width: 12),
          const Expanded(child: Text('Could not load today\'s numbers.')),
          TextButton(onPressed: _refresh, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _workspaceCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = <_MenuItem>[
      _MenuItem(
        icon: Icons.inventory_2_outlined,
        title: 'Inventory',
        subtitle: 'Types and assets',
        builder: (_) => const InventoryScreen(),
      ),
      _MenuItem(
        icon: Icons.pending_actions_outlined,
        title: 'Reservations',
        subtitle: 'Review and manage',
        builder: (_) => const StaffReservationsScreen(),
      ),
      _MenuItem(
        icon: Icons.search,
        title: 'Search',
        subtitle: 'Find records',
        builder: (_) => const SearchReservationsScreen(),
      ),
      _MenuItem(
        icon: Icons.bar_chart_outlined,
        title: 'Reports',
        subtitle: 'Insights and exports',
        builder: (_) => const ReportsScreen(),
      ),
      _MenuItem(
        icon: Icons.manage_accounts_outlined,
        title: 'Accounts',
        subtitle: 'Create users',
        builder: (_) => const ManageAccountsScreen(),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _menuTile(context, items[i]),
            if (i != items.length - 1)
              Divider(
                height: 1,
                indent: 70,
                color: scheme.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }

  Widget _menuTile(BuildContext context, _MenuItem item) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: item.builder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.maroon100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: AppTheme.maroon, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
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

  String _dateLabel() {
    final now = DateTime.now();
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  Widget _profileSkeleton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 210,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _GlanceTile extends StatelessWidget {
  const _GlanceTile({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
    required this.onTap,
    this.emphasize = false,
  });

  final String label;
  final int value;
  final String caption;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '$label: $value. $caption',
      child: Material(
        color: emphasize ? color.withValues(alpha: 0.08) : scheme.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 92),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: emphasize
                    ? color.withValues(alpha: 0.35)
                    : scheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$value',
                        style: TextStyle(
                          fontSize: 26,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: emphasize ? color : scheme.onSurface,
                        ),
                      ),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
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

class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
  });
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