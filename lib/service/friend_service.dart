import 'package:supabase_flutter/supabase_flutter.dart';
import 'streak_service.dart';
import 'package:flutter/foundation.dart';

class Friend {
  final String id; // friends table row id
  final String userId; // the friend's actual auth id
  final String fullName;
  final String? avatarPath;

  Friend({required this.id, required this.userId, required this.fullName, this.avatarPath});
}

/// Thrown by [FriendService.sendFriendRequest] with a message safe to
/// show directly in a SnackBar.
class FriendRequestException implements Exception {
  final String message;
  FriendRequestException(this.message);
  @override
  String toString() => message;
}

class FriendService {
  final _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> findUserByFriendCode(String code) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _supabase
        .from('profiles')
        .select('id, full_name, username, friend_code')
        .eq('friend_code', code.trim().toUpperCase())
        .neq('id', userId)
        .maybeSingle();

    return row;
  }

  Future<String?> fetchMyFriendCode() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _supabase.from('profiles').select('friend_code').eq('id', userId).maybeSingle();
    return row?['friend_code'] as String?;
  }

  /// Sends a friend request from the current user to [receiverId].
  ///
  /// Only the actual `friends` table (checked in both directions) is
  /// treated as proof of an existing friendship. A `friend_requests`
  /// row with status `accepted` is *not* trusted on its own — if the
  /// friendship was later removed, that row can go stale, and treating
  /// it as authoritative would permanently block re-adding.
  Future<void> sendFriendRequest(String receiverId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw FriendRequestException('You need to be signed in to add friends.');
    }

    if (userId == receiverId) {
      throw FriendRequestException("You can't add yourself as a friend.");
    }

    // Already friends? Check both directions — the friends table is
    // the single source of truth for this, not friend_requests.status.
    final existingFriend = await _supabase
        .from('friends')
        .select('id')
        .or('and(user_id.eq.$userId,friend_id.eq.$receiverId),'
        'and(user_id.eq.$receiverId,friend_id.eq.$userId)')
        .maybeSingle();

    if (existingFriend != null) {
      throw FriendRequestException("You're already friends with this person.");
    }

    // They already sent *you* a pending request — nudge toward
    // accepting theirs instead of creating one in the other direction.
    final theirRequest = await _supabase
        .from('friend_requests')
        .select('id')
        .eq('sender_id', receiverId)
        .eq('receiver_id', userId)
        .eq('status', 'pending')
        .maybeSingle();

    if (theirRequest != null) {
      throw FriendRequestException(
        'They already sent you a friend request — check your notifications.',
      );
    }

    // Is there already a row in this exact direction?
    final existingRequest = await _supabase
        .from('friend_requests')
        .select('id, status')
        .eq('sender_id', userId)
        .eq('receiver_id', receiverId)
        .maybeSingle();

    if (existingRequest != null) {
      if (existingRequest['status'] == 'pending') {
        throw FriendRequestException('Friend request already sent.');
      }

      // declined, accepted-but-since-unfriended, or anything else —
      // revive it into a fresh pending request rather than inserting
      // a second row and hitting the unique constraint.
      await _supabase
          .from('friend_requests')
          .update({
        'status': 'pending',
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', existingRequest['id']);
      return;
    }

    await _supabase.from('friend_requests').insert({
      'sender_id': userId,
      'receiver_id': receiverId,
      'status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> fetchIncomingRequests() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final rows = await _supabase
        .from('friend_requests')
        .select('id, sender_id, profiles!friend_requests_sender_profile_fkey(full_name, username, avatar_path)')
        .eq('receiver_id', userId)
        .eq('status', 'pending');

    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> acceptRequest(String requestId) async {
    // The `sync_friendship_on_accept` trigger (security definer) inserts
    // both `friends` rows automatically when status flips to 'accepted'.
    // Don't also insert/upsert here — RLS blocks the sender-side row
    // since it's not `auth.uid()`, and it's unnecessary anyway.
    await _supabase
        .from('friend_requests')
        .update({'status': 'accepted'})
        .eq('id', requestId);
  }

  Future<void> declineRequest(String requestId) async {
    await _supabase.from('friend_requests').update({'status': 'declined'}).eq('id', requestId);
  }

  Future<List<Friend>> fetchFriends() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final rows = await _supabase
        .from('friends')
        .select('id, friend_id, profiles!friends_friend_profile_fkey(full_name, avatar_path)')
        .eq('user_id', userId);

    return (rows as List).map((r) {
      final profile = r['profiles'] as Map<String, dynamic>?;
      return Friend(
        id: r['id'] as String,
        userId: r['friend_id'] as String,
        fullName: (profile?['full_name'] as String?) ?? 'Unknown',
        avatarPath: profile?['avatar_path'] as String?,
      );
    }).toList();
  }

  /// Realtime: fires when a friendship is added or removed involving the
  /// current user — e.g. someone accepts your request on their device,
  /// or unfriends you. Caller removes the channel in dispose().
  RealtimeChannel subscribeToFriendChanges(VoidCallback onChange) {
    final userId = _supabase.auth.currentUser?.id;
    final channel = _supabase.channel('my_friends:${userId ?? 'anon'}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'friends',
        // no server-side filter: DELETE payloads don't reliably include
        // user_id unless REPLICA IDENTITY FULL is set on this table.
        callback: (payload) {
          final newRow = payload.newRecord;
          final oldRow = payload.oldRecord;
          final matches = newRow['user_id'] == userId || oldRow['user_id'] == userId;
          if (matches) onChange();
        },
      )
      ..subscribe();
    return channel;
  }

  /// Removes the friendship in both directions, and clears out any
  /// friend_requests row between the two users so a fresh request can
  /// be sent afterward without hitting stale-status blocks.
  Future<void> removeFriend(String friendsRowId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final row = await _supabase
        .from('friends')
        .select('friend_id')
        .eq('id', friendsRowId)
        .maybeSingle();

    final otherUserId = row?['friend_id'] as String?;
    if (otherUserId == null) return;

    await _unfriendBothSides(userId, otherUserId);
  }

  Future<void> removeFriends(List<String> friendsRowIds) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final rows = await _supabase
        .from('friends')
        .select('friend_id')
        .inFilter('id', friendsRowIds);

    final otherIds = (rows as List).map((r) => r['friend_id'] as String).toList();

    for (final otherId in otherIds) {
      await _unfriendBothSides(userId, otherId);
    }
  }

  Future<void> _unfriendBothSides(String userId, String otherUserId) async {
    await _supabase.rpc('unfriend', params: {'p_other_user_id': otherUserId});
  }
  Future<StreakStats> fetchFriendStats(String friendUserId) async {
    final rows = await _supabase
        .from('streak_days')
        .select('day')
        .eq('user_id', friendUserId)
        .order('day', ascending: true);

    final daySet = (rows as List)
        .map((r) => DateTime.parse(r['day'] as String))
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();

    int currentStreak = 0;
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    while (daySet.contains(cursor)) {
      currentStreak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    final sortedDays = daySet.toList()..sort();
    int longest = 0, running = 0;
    DateTime? prev;
    for (final d in sortedDays) {
      running = (prev != null && d.difference(prev).inDays == 1) ? running + 1 : 1;
      if (running > longest) longest = running;
      prev = d;
    }

    double successRate = 0;
    if (sortedDays.isNotEmpty) {
      final totalPossible = DateTime.now().difference(sortedDays.first).inDays + 1;
      successRate = totalPossible > 0 ? (sortedDays.length / totalPossible) * 100 : 0;
    }

    final now = DateTime.now();
    final daysThisMonth = sortedDays.where((d) => d.year == now.year && d.month == now.month).length;

    final profile = await _supabase.from('profiles').select('xp, full_name').eq('id', friendUserId).maybeSingle();
    final totalXp = (profile?['xp'] as int?) ?? 0;
    final fullName = (profile?['full_name'] as String?) ?? 'Unknown';

    return StreakStats(
      fullName: fullName,
      currentStreak: currentStreak,
      longestStreak: longest,
      successRate: successRate,
      daysThisMonth: daysThisMonth,
      totalXp: totalXp,
    );
  }
}