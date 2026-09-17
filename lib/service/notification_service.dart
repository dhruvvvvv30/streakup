import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class AppNotification {
  final String id;
  final String title;
  final String? body;
  final String type;
  final bool read;
  final DateTime createdAt;
  final String? referenceId; // e.g. friend_requests.id, when type == 'friend_request'
  final String? senderId;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.read,
    required this.createdAt,
    this.referenceId,
    this.senderId,
  });

  bool get unread => !read;

  AppNotification copyWithRead(bool newRead) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      read: newRead,
      createdAt: createdAt,
      referenceId: referenceId,
      senderId: senderId,
    );
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      title: map['title'] as String,
      body: map['body'] as String?,
      type: map['type'] as String? ?? 'general',
      read: map['read'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      referenceId: map['reference_id'] as String?,
      senderId: map['sender_id'] as String?,
    );
  }
}

class NotificationService {
  final _supabase = Supabase.instance.client;

  Future<List<AppNotification>> fetchNotifications() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final rows = await _supabase
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (rows as List).map((r) => AppNotification.fromMap(r)).toList();
  }

  /// Realtime: fires when a notification row is inserted/updated/deleted
  /// for the current user — e.g. someone sends you a friend request from
  /// their device. Caller removes the channel in dispose().
  RealtimeChannel subscribeToMyNotifications(VoidCallback onChange) {
    final userId = _supabase.auth.currentUser?.id;
    final channel = _supabase.channel('my_notifications:${userId ?? 'anon'}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (_) => onChange(),
      )
      ..subscribe();
    return channel;
  }

  Future<int> fetchUnreadCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    final resp = await _supabase
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('read', false)
        .count(CountOption.exact);

    return resp.count;
  }

  Future<void> markAsRead(String id) async {
    await _supabase.from('notifications').update({'read': true}).eq('id', id);
  }

  Future<void> markAllAsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    await _supabase.from('notifications').update({'read': true}).eq('user_id', userId).eq('read', false);
  }

  /// Deletes a notification row directly (used as a local-state fallback
  /// right after accept/decline, in case the resolve trigger's delete
  /// hasn't been picked up by the next fetch yet).
  Future<void> deleteNotification(String id) async {
    await _supabase.from('notifications').delete().eq('id', id);
  }
}