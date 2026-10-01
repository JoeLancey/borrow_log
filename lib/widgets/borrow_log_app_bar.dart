import 'package:flutter/material.dart';

/// Standard BORROW LOG AppBar: UM logo + title on the left,
/// optional actions on the right.
///
/// Usage:
///   appBar: const BorrowLogAppBar(title: 'Inventory'),
///
/// When you need action buttons:
///   appBar: BorrowLogAppBar(
///     title: 'Inventory',
///     actions: [ IconButton(...) ],
///   ),
class BorrowLogAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showLogo;

  const BorrowLogAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showLogo = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(84);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 84,
      titleSpacing: leading == null ? 12 : null,
      leading: leading,
      backgroundColor: theme.colorScheme.primary,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF7E001B),
              Color(0xFF9F0A20),
            ],
          ),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLogo) ...[
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(4),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/um-logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
      actions: actions == null
          ? null
          : [
              const SizedBox(width: 8),
              ...actions!,
              const SizedBox(width: 8),
            ],
    );
  }
}