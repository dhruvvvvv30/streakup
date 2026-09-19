import 'package:supabase_flutter/supabase_flutter.dart';

class StreakStats {
  final String fullName;
  final int currentStreak;
  final int longestStreak;
  final double successRate;
  final int daysThisMonth;
  final int totalXp;

  StreakStats({
    required this.fullName,
    required this.currentStreak,
    required this.longestStreak,
    required this.successRate,
    required this.daysThisMonth,
    required this.totalXp,
  });
}

class StreakService {
  final _supabase = Supabase.instance.client;
  static const int xpPerTask = 20;

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Call this from _toggleTask instead of the old markTodayCompleted().
  Future<void> toggleTaskCompletion(String taskId, bool newCompleted) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final now = DateTime.now();
    final todayStr = _dateOnly(now);
    final todayStartUtc = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();

    // Was this task already completed (and XP given) TODAY?
    final todays = await _supabase
        .from('task_completion_events')
        .select('id')
        .eq('user_id', userId)
        .eq('task_id', taskId)
        .gte('completed_at', todayStartUtc);
    final awardedToday = (todays as List).isNotEmpty;

    await _supabase.from('tasks').update({'completed': newCompleted}).eq('id', taskId);

    if (newCompleted && !awardedToday) {
      await _supabase.rpc('increment_xp', params: {'p_user_id': userId, 'p_amount': xpPerTask});
      await _supabase.from('task_completion_events').insert({'user_id': userId, 'task_id': taskId});
    } else if (!newCompleted && awardedToday) {
      await _supabase.rpc('increment_xp', params: {'p_user_id': userId, 'p_amount': -xpPerTask});
      await _supabase
          .from('task_completion_events')
          .delete()
          .eq('user_id', userId)
          .eq('task_id', taskId)
          .gte('completed_at', todayStartUtc);
    }

    // Re-evaluate today's streak row from today's events
    final eventsToday = await _supabase
        .from('task_completion_events')
        .select('id')
        .eq('user_id', userId)
        .gte('completed_at', todayStartUtc);

    if ((eventsToday as List).isNotEmpty) {
      await _supabase.from('streak_days').upsert(
        {'user_id': userId, 'day': todayStr, 'completed': true},
        onConflict: 'user_id,day',
      );
    } else {
      await _supabase.from('streak_days').delete().eq('user_id', userId).eq('day', todayStr);
    }
  }

  Future<Set<int>> fetchCompletedDaysForMonth(DateTime month) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {};
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    final rows = await _supabase
        .from('streak_days')
        .select('day')
        .eq('user_id', userId)
        .gte('day', _dateOnly(firstDay))
        .lte('day', _dateOnly(lastDay));

    return (rows as List).map((r) => DateTime.parse(r['day'] as String).day).toSet();
  }

  Future<Set<int>> fetchFreezeDaysForMonth(DateTime month) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {};
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    final rows = await _supabase
        .from('streak_days')
        .select('day')
        .eq('user_id', userId)
        .eq('freeze_used', true)
        .gte('day', _dateOnly(firstDay))
        .lte('day', _dateOnly(lastDay));

    return (rows as List).map((r) => DateTime.parse(r['day'] as String).day).toSet();
  }

  Future<StreakStats> fetchStats() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return StreakStats(fullName: 'there', currentStreak: 0, longestStreak: 0, successRate: 0, daysThisMonth: 0, totalXp: 0);
    }

    final rows = await _supabase
        .from('streak_days')
        .select('day')
        .eq('user_id', userId)
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

    final profile = await _supabase.from('profiles').select('xp, full_name').eq('id', userId).maybeSingle();
    final totalXp = (profile?['xp'] as int?) ?? 0;
    final fullName = (profile?['full_name'] as String?) ?? 'there';

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