class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String? body;
  final String kind;
  final String? reservationId;
  final DateTime? readAt;
  final DateTime? createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    this.body,
    required this.kind,
    this.reservationId,
    this.readAt,
    this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      body: map['body'] as String?,
      kind: map['kind'] as String,
      reservationId: map['reservation_id'] as String?,
      readAt: map['read_at'] != null
          ? DateTime.tryParse(map['read_at'].toString())
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  bool get isUnread => readAt == null;

  String get relativeTime {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final d = createdAt!;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}