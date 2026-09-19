import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Map<String, IconData> groupIcons = {
  'groups_rounded': Icons.groups_rounded,
  'security_rounded': Icons.security_rounded,
  'fitness_center_rounded': Icons.fitness_center_rounded,
  'menu_book_rounded': Icons.menu_book_rounded,
  'code_rounded': Icons.code_rounded,
};

IconData iconForName(String name) => groupIcons[name] ?? Icons.groups_rounded;

class GroupModel {
  final String id;
  final String name;
  final String tagline;
  final String iconName;
  final String inviteCode;
  final int memberCount;
  final int streak;

  GroupModel({
    required this.id,
    required this.name,
    required this.tagline,
    required this.iconName,
    required this.inviteCode,
    required this.memberCount,
    required this.streak,
  });
}

class GroupMemberStat {
  final String userId;
  final String name;
  final int xp;
  final bool isYou;
  final String? avatarPath;

  GroupMemberStat({
    required this.userId,
    required this.name,
    required this.xp,
    required this.isYou,
    this.avatarPath,
  });
}

class GroupProgressMember {
  final String userId;
  final String name;
  final bool isYou;
  final bool doneToday;
  final String? avatarPath;

  GroupProgressMember({
    required this.userId,
    required this.name,
    required this.isYou,
    required this.doneToday,
    this.avatarPath,
  });
}

class GroupTask {
  final String id;
  final String title;
  final DateTime taskDate;
  final bool doneByYou;

  GroupTask({
    required this.id,
    required this.title,
    required this.taskDate,
    required this.doneByYou,
  });
}

class GroupProgressData {
  final List<GroupProgressMember> members;
  final List<bool> week; // Mon..Sun
  final GroupTask? task;

  GroupProgressData({required this.members, required this.week, this.task});

  int get completedToday => members.where((m) => m.doneToday).length;
}

class GroupService {
  final _supabase = Supabase.instance.client;

  Future<List<GroupModel>> fetchMyGroups() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final memberRows = await _supabase
        .from('group_members')
        .select('group_id')
        .eq('user_id', userId);

    final groupIds = (memberRows as List).map((r) => r['group_id'] as String).toList();
    if (groupIds.isEmpty) return [];

    final groupsRows = await _supabase.from('groups').select().inFilter('id', groupIds);

    final result = <GroupModel>[];
    for (final g in groupsRows as List) {
      final groupId = g['id'] as String;

      final countRows = await _supabase
          .from('group_members')
          .select('user_id')
          .eq('group_id', groupId);

      final streak = await _supabase.rpc('group_current_streak', params: {'p_group_id': groupId});

      result.add(GroupModel(
        id: groupId,
        name: g['name'] as String,
        tagline: (g['tagline'] as String?) ?? '',
        iconName: (g['icon_name'] as String?) ?? 'groups_rounded',
        inviteCode: g['invite_code'] as String,
        memberCount: (countRows as List).length,
        streak: (streak as int?) ?? 0,
      ));
    }
    return result;
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<GroupProgressData> fetchGroupProgress(String groupId) async {
    final res = await _supabase.rpc('get_group_progress', params: {
      'p_group_id': groupId,
      'p_today': _dateOnly(DateTime.now()),
    });
    final j = Map<String, dynamic>.from(res as Map);

    final taskJson = j['task'] as Map<String, dynamic>?;

    return GroupProgressData(
      members: (j['members'] as List)
          .map((m) => GroupProgressMember(
        userId: m['user_id'] as String,
        name: m['name'] as String,
        isYou: m['is_you'] as bool,
        doneToday: m['done_today'] as bool,
        avatarPath: m['avatar_path'] as String?,
      ))
          .toList(),
      week: (j['week'] as List).map((e) => e as bool).toList(),
      task: taskJson == null
          ? null
          : GroupTask(
        id: taskJson['id'] as String,
        title: taskJson['title'] as String,
        taskDate: DateTime.parse(taskJson['task_date'] as String),
        doneByYou: taskJson['done_by_you'] as bool,
      ),
    );
  }

  Future<void> completeGroupTask(String groupId) async {
    await _supabase.rpc('complete_group_task', params: {
      'p_group_id': groupId,
      'p_today': _dateOnly(DateTime.now()),
    });
  }

  Future<List<GroupMemberStat>> fetchLeaderboard(String groupId) async {
    final userId = _supabase.auth.currentUser?.id;

    final rows = await _supabase
        .from('group_members')
        .select('user_id, profiles(full_name, xp, avatar_path)')
        .eq('group_id', groupId);

    final list = (rows as List).map((r) {
      final profile = r['profiles'] as Map<String, dynamic>?;
      return GroupMemberStat(
        userId: r['user_id'] as String,
        name: (profile?['full_name'] as String?) ?? 'Unknown',
        xp: (profile?['xp'] as int?) ?? 0,
        isYou: r['user_id'] == userId,
        avatarPath: profile?['avatar_path'] as String?,
      );
    }).toList();

    list.sort((a, b) => b.xp.compareTo(a.xp));
    return list;
  }

  Future<int> fetchGroupStreak(String groupId) async {
    final streak = await _supabase.rpc('group_current_streak', params: {'p_group_id': groupId});
    return (streak as int?) ?? 0;
  }

  Future<Set<String>> fetchMemberUserIds(String groupId) async {
    final rows = await _supabase
        .from('group_members')
        .select('user_id')
        .eq('group_id', groupId);
    return (rows as List).map((r) => r['user_id'] as String).toSet();
  }

  /// Realtime updates for one group's leaderboard: membership changes
  /// and XP changes on any profile row. Caller removes the channel in dispose().
  RealtimeChannel subscribeToGroupUpdates(
      String groupId,
      VoidCallback onChange,
      ) {
    final channel = _supabase.channel('group_leaderboard:$groupId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'group_members',
        // no filter: DELETE payloads don't reliably include group_id
        // unless REPLICA IDENTITY FULL is set, so filter client-side instead.
        callback: (payload) {
          final newRow = payload.newRecord;
          final oldRow = payload.oldRecord;
          final matches = newRow['group_id'] == groupId || oldRow['group_id'] == groupId;
          if (matches) onChange();
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'profiles',
        callback: (_) => onChange(),
      )
      ..subscribe();

    return channel;
  }

  /// Realtime: fires when the current user is added to or removed from
  /// ANY group — e.g. a friend adds you to a group from their device.
  /// Caller removes the channel in dispose().
  RealtimeChannel subscribeToMyGroups(VoidCallback onChange) {
    final userId = _supabase.auth.currentUser?.id;
    final channel = _supabase.channel('my_groups:${userId ?? 'anon'}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'group_members',
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

  Future<GroupModel> createGroup({
    required String name,
    required String tagline,
    String iconName = 'groups_rounded',
  }) async {
    final row = await _supabase.rpc('create_group', params: {
      'p_name': name,
      'p_tagline': tagline,
      'p_icon': iconName,
    });

    final g = row as Map<String, dynamic>;
    return GroupModel(
      id: g['id'] as String,
      name: g['name'] as String,
      tagline: (g['tagline'] as String?) ?? '',
      iconName: (g['icon_name'] as String?) ?? 'groups_rounded',
      inviteCode: g['invite_code'] as String,
      memberCount: 1,
      streak: 0,
    );
  }

  Future<GroupModel> joinGroupByCode(String code) async {
    final row = await _supabase.rpc('join_group_by_code', params: {'p_code': code});
    final g = row as Map<String, dynamic>;
    return GroupModel(
      id: g['id'] as String,
      name: g['name'] as String,
      tagline: (g['tagline'] as String?) ?? '',
      iconName: (g['icon_name'] as String?) ?? 'groups_rounded',
      inviteCode: g['invite_code'] as String,
      memberCount: 0,
      streak: 0,
    );
  }

  Future<void> addMemberToGroup(String groupId, String friendUserId) async {
    await _supabase.rpc('add_group_member', params: {
      'p_group_id': groupId,
      'p_target_user_id': friendUserId,
    });
  }

  Future<void> leaveGroup(String groupId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    await _supabase
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }
}