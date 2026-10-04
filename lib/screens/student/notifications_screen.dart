import 'package:flutter/material.dart';

import '../../models/notification.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/borrow_log_states.dart';
import '../shared/borrower_slip_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationService();
  late Future<List<AppNotification>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchMyNotifications();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _service.fetchMyNotifications();
    });
  }

  Future<void> _markAllRead() async {
    try {
      await _service.markAllRead();
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Failed: $e'),
        ),
      );
    }
  }

  Future<void> _open(AppNotification n) async {
    if (n.isUnread) {
      try {
        await _service.markRead(n.id);
      } catch (_) {}
    }
    if (!mounted) return;

    if (n.reservationId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BorrowerSlipScreen(reservationId: n.reservationId!),
        ),
      );
      await _refresh();
    } else {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F5F4),
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            icon: const Icon(Icons.done_all),
            onPressed: _markAllRead,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppTheme.maroon,
        child: FutureBuilder<List<AppNotification>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const BorrowLogSkeletonList(itemCount: 6);
            }
            if (snap.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: BorrowLogErrorState(
                      message: 'Failed to load notifications:\n${snap.error}',
                      onRetry: _refresh,
                    ),
                  ),
                ],
              );
            }
            final list = snap.data ?? [];
            if (list.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  BorrowLogEmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'No notifications yet',
                    message: 'You are all caught up for now.',
                  ),
                ],
              );
            }

            final unread = list.where((n) => n.isUnread).length;

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: list.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) return _summary(unread, list.length);
                return _tile(list[i - 1]);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _summary(int unread, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
      child: Row(
        children: [
          Text(
            unread > 0 ? '$unread unread' : 'All read',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: unread > 0 ? AppTheme.maroon : Colors.black54,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'of $total',
            style: const TextStyle(fontSize: 13, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _tile(AppNotification n) {
    final icon = _iconFor(n.kind);
    final color = _colorFor(n.kind);
    final hasBody = n.body != null && n.body!.isNotEmpty;
    final opensSlip = n.reservationId != null;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      color: n.isUnread ? const Color(0xFFFFF8F8) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: n.isUnread
              ? AppTheme.maroon.withValues(alpha: 0.25)
              : const Color(0x14000000),
        ),
      ),
      child: InkWell(
        onTap: () => _open(n),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.25,
                        fontWeight:
                            n.isUnread ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (hasBody)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          n.body!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.schedule,
                            size: 12, color: Colors.black38),
                        const SizedBox(width: 4),
                        Text(
                          n.relativeTime,
                          style: const TextStyle(
                              fontSize: 11.5, color: Colors.black45),
                        ),
                        if (opensSlip) ...[
                          const Spacer(),
                          const Text(
                            'View slip',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.maroon,
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              size: 16, color: AppTheme.maroon),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (n.isUnread)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 6),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppTheme.maroon,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'reservation_approved':
        return Icons.check_circle_outline;
      case 'reservation_rejected':
        return Icons.cancel_outlined;
      case 'equipment_released':
        return Icons.assignment_turned_in_outlined;
      case 'return_recorded':
        return Icons.assignment_return_outlined;
      case 'overdue':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_none;
    }
  }

  Color _colorFor(String kind) {
    switch (kind) {
      case 'reservation_approved':
        return Colors.green;
      case 'reservation_rejected':
        return Colors.red;
      case 'equipment_released':
        return Colors.blue;
      case 'return_recorded':
        return Colors.teal;
      case 'overdue':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}