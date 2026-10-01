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
        SnackBar(content: Text('Failed: $e')),
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
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Mark all read',
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
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Failed to load:\n${snap.error}',
                      textAlign: TextAlign.center),
                ),
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
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) => _tile(list[i]),
            );
          },
        ),
      ),
    );
  }

  Widget _tile(AppNotification n) {
    final icon = _iconFor(n.kind);
    final color = _colorFor(n.kind);

    return ListTile(
      onTap: () => _open(n),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        n.title,
        style: TextStyle(
          fontWeight: n.isUnread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (n.body != null && n.body!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(n.body!, style: const TextStyle(fontSize: 13)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              n.relativeTime,
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ),
        ],
      ),
      trailing: n.isUnread
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppTheme.maroon,
                shape: BoxShape.circle,
              ),
            )
          : null,
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