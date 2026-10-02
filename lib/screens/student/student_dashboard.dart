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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral100,
      appBar: BorrowLogAppBar(
        title: 'BorrowLog',
        actions: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                tooltip: 'Notifications',
                onPressed: _openNotifications,
              ),
              if (_unread > 0)
                IgnorePointer(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8, right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold500,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      _unread > 99 ? '99+' : '$_unread',
                      style: const TextStyle(
                        color: AppColors.maroon900,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _logout,
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
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                ),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _loadingProfile
                      ? _profileSkeleton()
                      : Text(
                          'Welcome back, $_firstName',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Reserve laboratory equipment and keep every loan on track.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.45,
                      color: AppColors.ink700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FutureBuilder<_StudentSummary>(
                    future: _summary,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox.shrink();
                      }
                      return _summaryCard(snapshot.data!);
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Quick actions',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Start with what you need today',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.ink500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
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

  Widget _summaryCard(_StudentSummary summary) {
    final dueText = summary.nextDue == null
        ? 'No active due date'
        : 'Next due: ${summary.nextDue!.month.toString().padLeft(2, '0')}/${summary.nextDue!.day.toString().padLeft(2, '0')}';

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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your borrowing snapshot',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
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
                  isHighlighted: summary.overdue > 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                dueText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFFDECEC),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: AppTheme.maroon,
                  size: 24,
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
                        fontSize: 20,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.ink500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 24),
            ],
          ),
        ),
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
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 28,
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

  Widget _profileSkeleton() {
    return Container(
      width: 200,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
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