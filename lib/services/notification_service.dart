import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification.dart';

class NotificationService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<AppNotification>> fetchMyNotifications() async {
    final uid = _client.auth.currentUser!.id;
    final data = await _client
        .from('notifications')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(100);

    return (data as List)
        .map((row) => AppNotification.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<int> unreadCount() async {
    final uid = _client.auth.currentUser!.id;
    final data = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', uid)
        .isFilter('read_at', null);

    return (data as List).length;
  }

  Future<void> markRead(String id) async {
    await _client.from('notifications').update({
      'read_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> markAllRead() async {
    final uid = _client.auth.currentUser!.id;
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('user_id', uid)
        .isFilter('read_at', null);
  }

  Future<void> insertNotification({
    required String userId,
    required String title,
    String? body,
    required String kind,
    String? reservationId,
  }) async {
    await _client.from('notifications').insert({
      'user_id': userId,
      'title': title,
      'body': body,
      'kind': kind,
      'reservation_id': reservationId,
    });
  }
}   