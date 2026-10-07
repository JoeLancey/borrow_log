import 'package:flutter/material.dart';

/// Consistent in-app feedback messages for BORROW LOG.
///
/// Use these helpers instead of raw SnackBars so every toast has the
/// same look, positioning, duration, and behavior across the app.
class AppFeedback {
  AppFeedback._(); // non-instantiable

  /// Green check · success toast (3s).
  static void success(BuildContext context, String message) {
    _show(context, message, kind: _Kind.success);
  }

  /// Red X · error toast (4s).
  static void error(BuildContext context, String message) {
    _show(context, message, kind: _Kind.error);
  }

  /// Blue info · neutral toast (3s).
  static void info(BuildContext context, String message) {
    _show(context, message, kind: _Kind.info);
  }

  static void _show(
    BuildContext context,
    String message, {
    required _Kind kind,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final (IconData icon, Color bg) = switch (kind) {
      _Kind.success => (Icons.check_circle_outline, const Color(0xFF1B5E20)),
      _Kind.error => (Icons.error_outline, const Color(0xFFB71C1C)),
      _Kind.info => (Icons.info_outline, const Color(0xFF0D47A1)),
    };

    final duration = kind == _Kind.error
        ? const Duration(seconds: 4)
        : const Duration(seconds: 3);

    // Clear any current toast so messages don't pile up.
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bg,
        duration: duration,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        dismissDirection: DismissDirection.horizontal,
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Kind { success, error, info }