import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BorrowLogStatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const BorrowLogStatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  factory BorrowLogStatusChip.asset(String status) {
    final normalized = status.toLowerCase();
    final color = switch (normalized) {
      'available' => Colors.green,
      'borrowed' => Colors.blue,
      'reserved' => Colors.orange,
      'maintenance' => Colors.deepPurple,
      'damaged' || 'lost' => Colors.red,
      _ => Colors.grey,
    };
    final icon = switch (normalized) {
      'available' => Icons.check_circle_outline,
      'borrowed' => Icons.assignment_outlined,
      'reserved' => Icons.event_note_outlined,
      'maintenance' => Icons.build_outlined,
      'damaged' => Icons.warning_amber_outlined,
      'lost' => Icons.help_outline,
      _ => Icons.label_outline,
    };
    return BorrowLogStatusChip(
      label: status[0].toUpperCase() + status.substring(1),
      color: color,
      icon: icon,
    );
  }

  factory BorrowLogStatusChip.reservation(String status, {bool overdue = false}) {
    final normalized = overdue ? 'overdue' : status.toLowerCase();
    final color = switch (normalized) {
      'pending' => Colors.orange,
      'approved' => Colors.green,
      'borrowed' => Colors.blue,
      'completed' => Colors.teal,
      'rejected' || 'overdue' => Colors.red,
      'cancelled' => Colors.grey,
      _ => Colors.grey,
    };
    final icon = switch (normalized) {
      'pending' => Icons.schedule,
      'approved' => Icons.check_circle_outline,
      'borrowed' => Icons.assignment_outlined,
      'completed' => Icons.done_all,
      'rejected' => Icons.cancel_outlined,
      'overdue' => Icons.warning_amber_outlined,
      'cancelled' => Icons.remove_circle_outline,
      _ => Icons.label_outline,
    };
    return BorrowLogStatusChip(
      label: normalized[0].toUpperCase() + normalized.substring(1),
      color: color,
      icon: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef StatusChip = BorrowLogStatusChip;

class BorrowLogSkeletonList extends StatelessWidget {
  final int itemCount;

  const BorrowLogSkeletonList({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: AppTheme.spaceMd),
      itemBuilder: (_, _) => const _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBar(width: 180, height: 16),
            SizedBox(height: AppTheme.spaceMd),
            _SkeletonBar(width: double.infinity, height: 12),
            SizedBox(height: AppTheme.spaceSm),
            _SkeletonBar(width: 240, height: 12),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBar extends StatefulWidget {
  final double width;
  final double height;

  const _SkeletonBar({required this.width, required this.height});

  @override
  State<_SkeletonBar> createState() => _SkeletonBarState();
}

class _SkeletonBarState extends State<_SkeletonBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.2 + progress * 2.4, 0),
              end: Alignment(-0.2 + progress * 2.4, 0),
              colors: [
                Colors.black.withValues(alpha: 0.06),
                Colors.black.withValues(alpha: 0.12),
                Colors.black.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
        );
      },
    );
  }
}

class BorrowLogEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const BorrowLogEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppTheme.maroon),
            const SizedBox(height: AppTheme.spaceLg),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppTheme.spaceLg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class BorrowLogErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const BorrowLogErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: Colors.red),
            const SizedBox(height: AppTheme.spaceMd),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppTheme.spaceLg),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
