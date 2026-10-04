import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/reservation_service.dart';
import '../../features/reservations/domain/reservation_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/borrow_log_app_bar.dart';
import '../auth/login_screen.dart';
import 'browse_equipment_screen.dart';
import 'notifications_screen.dart';
import 'student_reservations_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final _notificationService = NotificationService();
  final ReservationRepository _reservationService = ReservationService();
  int _unread = 0;
  late Future<_StudentSummary> _summary;
  String _firstName = 'there';
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadUnread();
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
    await _loadUnread();
    setState(() {
      _summary = _loadSummary();
    });
  }

  Future<_StudentSummary> _loadSummary() async {
    final reservations = await _reservationService.fetchMyReservations();
    final active = reservations.where((r) => r.isActive).toList();
    final overdue = reservations.where((r) => r.isOverdue).length;
    active.sort((a, b) => (a.dueDate ?? DateTime(9999))
        .compareTo(b.dueDate ?? DateTime(9999)));
    return _StudentSummary(
      activeLoans: active.where((r) => r.status == 'borrowed').length,
      pending: reservations.where((r) => r.status == 'pending').length,
      overdue: overdue,
      nextDue: active.isEmpty ? null : active.first.dueDate,
    );
  }

  Future<void> _loadUnread() async {
    try {
      final n = await _notificationService.unreadCount();
      if (!mounted) return;
      setState(() => _unread = n);
    } catch (_) {
      // silent — badge is non-critical
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    await _loadUnread();
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  /// UX: ask before signing out so a mis-tap doesn't end the session.
  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.maroon),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok == true) await _logout();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.neutral100,
      appBar: BorrowLogAppBar(
        title: 'BorrowLog',
        actions: [
          IconButton(
            tooltip: _unread > 0
                ? 'Notifications, $_unread unread'
                : 'Notifications',
            onPressed: _openNotifications,
            icon: Badge(
              isLabelVisible: _unread > 0,
              label: Text(_unread > 99 ? '99+' : '$_unread'),
              backgroundColor: AppColors.gold500,
              textColor: AppColors.maroon900,
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Log out',
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppTheme.maroon,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                ),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _loadingProfile
                      ? _profileSkeleton()
                      : Text(
                          'Welcome back, $_firstName',
                          style: textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Reserve laboratory equipment and keep every loan on track.',
                    style: textTheme.bodyLarge?.copyWith(
                      height: 1.45,
                      color: AppColors.ink700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FutureBuilder<_StudentSummary>(
                    future: _summary,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return _summaryError();
                      if (!snapshot.hasData) return _summarySkeleton();
                      return _summaryCard(snapshot.data!);
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Quick actions',
                    style: textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final actionWidth = constraints.maxWidth >= 640
                          ? (constraints.maxWidth - AppSpacing.md) / 2
                          : constraints.maxWidth;
                      return Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.md,
                        children: [
                          SizedBox(
                            width: actionWidth,
                            child: _actionCard(
                              icon: Icons.add_circle_rounded,
                              title: 'Reserve equipment',
                              subtitle: 'Browse availability and request items',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const BrowseEquipmentScreen(),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: actionWidth,
                            child: _actionCard(
                              icon: Icons.event_note_rounded,
                              title: 'My reservations',
                              subtitle: 'Track requests, loans, and history',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const StudentReservationsScreen(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Summary ─────────────────────────

  Widget _summaryCard(_StudentSummary summary) {
    final dueText = summary.nextDue == null
        ? 'No active due date'
        : 'Next due: ${summary.nextDue!.month.toString().padLeft(2, '0')}/${summary.nextDue!.day.toString().padLeft(2, '0')}';
    final hasOverdue = summary.overdue > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF9F1225),
            Color(0xFF7D0B18),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7D0B18).withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your borrowing snapshot',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _summaryMetric(
                    '${summary.activeLoans}',
                    'Active loans',
                    isHighlighted: false,
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Colors.white24,
                ),
                Expanded(
                  child: _summaryMetric(
                    '${summary.pending}',
                    'Pending',
                    isHighlighted: false,
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Colors.white24,
                ),
                Expanded(
                  child: _summaryMetric(
                    '${summary.overdue}',
                    'Overdue',
                    isHighlighted: hasOverdue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _infoPill(Icons.event_outlined, dueText, Colors.white70),
              if (hasOverdue)
                _infoPill(
                  Icons.warning_amber_rounded,
                  '${summary.overdue} overdue — return soon',
                  AppColors.gold300,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summarySkeleton() {
    return Container(
      height: 168,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppTheme.maroon,
        ),
      ),
    );
  }

  Widget _summaryError() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.red),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Couldn\'t load your borrowing snapshot.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: _refresh,
            style: TextButton.styleFrom(foregroundColor: AppTheme.maroon),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric(String value, String label, {required bool isHighlighted}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: isHighlighted ? AppColors.gold300 : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 30,
                letterSpacing: -0.8,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isHighlighted ? AppColors.gold300 : Colors.white70,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Actions ─────────────────────────

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0x14000000)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.maroon,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.ink500,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  size: 26, color: AppTheme.maroon),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileSkeleton() {
    return Container(
      width: 220,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _StudentSummary {
  final int activeLoans;
  final int pending;
  final int overdue;
  final DateTime? nextDue;

  const _StudentSummary({
    required this.activeLoans,
    required this.pending,
    required this.overdue,
    required this.nextDue,
  });
}