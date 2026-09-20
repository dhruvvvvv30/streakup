import 'package:supabase_flutter/supabase_flutter.dart';
import 'widget_service.dart';

class HomeData {
  final String fullName;
  final String? avatarPath;
  final int currentStreak;
  final int totalXp;
  final bool journalDoneToday;
  final bool moodSetToday;
  final int daysCompletedThisWeek;
  final Map<int, bool> weekdayCompletion; // DateTime.weekday (1=Mon..7=Sun) -> completed
  final String? upcomingTaskTitle;
  final String? upcomingTaskCategory;

  HomeData({
    required this.fullName,
    required this.avatarPath,
    required this.currentStreak,
    required this.totalXp,
    required this.journalDoneToday,
    required this.moodSetToday,
    required this.daysCompletedThisWeek,
    required this.weekdayCompletion,
    required this.upcomingTaskTitle,
    required this.upcomingTaskCategory,
  });
}

class HomeService {
  final _supabase = Supabase.instance.client;

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<HomeData> fetchHomeData() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return HomeData(
        fullName: 'there',
        avatarPath: null,
        currentStreak: 0,
        totalXp: 0,
        journalDoneToday: false,
        moodSetToday: false,
        daysCompletedThisWeek: 0,
        weekdayCompletion: {},
        upcomingTaskTitle: null,
        upcomingTaskCategory: null,
      );
    }

    final today = DateTime.now();
    final todayStr = _dateOnly(today);

    // Profile (name + avatar)
    final profile = await _supabase
        .from('profiles')
        .select('full_name, avatar_path, xp')
        .eq('id', userId)
        .maybeSingle();

    // Today's journal entry (for Journal/Mood checkmarks)
    final journalToday = await _supabase
        .from('journal_entries')
        .select('mood')
        .eq('user_id', userId)
        .eq('day', todayStr)
        .maybeSingle();

    // This week's streak_days (Mon–Sun)
    final weekday = today.weekday; // 1 = Mon
    final monday = today.subtract(Duration(days: weekday - 1));
    final sunday = monday.add(const Duration(days: 6));

    final weekRows = await _supabase
        .from('streak_days')
        .select('day, completed')
        .eq('user_id', userId)
        .gte('day', _dateOnly(monday))
        .lte('day', _dateOnly(sunday));

    final weekdayCompletion = <int, bool>{};
    int daysCompletedThisWeek = 0;
    for (final row in (weekRows as List)) {
      final d = DateTime.parse(row['day'] as String);
      final completed = row['completed'] as bool? ?? false;
      weekdayCompletion[d.weekday] = completed;
      if (completed) daysCompletedThisWeek++;
    }

    // Current streak — reuse the same logic as StreakService
    final allDaysRows = await _supabase
        .from('streak_days')
        .select('day')
        .eq('user_id', userId)
        .order('day', ascending: true);
    final daySet = (allDaysRows as List)
        .map((r) => DateTime.parse(r['day'] as String))
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();
    int currentStreak = 0;
    var cursor = DateTime(today.year, today.month, today.day);
    while (daySet.contains(cursor)) {
      currentStreak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    // Next pending task (for the "Upcoming" card)
    String? upcomingTitle;
    String? upcomingCategory;
    try {
      final taskRow = await _supabase
          .from('tasks')
          .select()
          .eq('user_id', userId)
          .eq('completed', false)
          .order('created_at', ascending: true)
          .limit(1)
          .maybeSingle();
      if (taskRow != null) {
        upcomingTitle = taskRow['title'] as String?;
        upcomingCategory = taskRow['category'] as String? ?? 'Personal';
      }
    } catch (_) {
      // tasks table/columns may differ — fails silently, Upcoming card shows empty state
    }

    // Full list of today's tasks, for the home-screen widget
    // Full list of today's tasks, for the home-screen widget
    try {
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final todayTaskRows = await _supabase
          .from('tasks')
          .select('id, title, completed')
          .eq('user_id', userId)
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String())
          .order('created_at', ascending: true);

     // print('🟡 [Widget] Fetched ${(todayTaskRows as List).length} tasks for $todayStr');

      final todayTasks = todayTaskRows
          .map((r) => {
        'id': r['id'].toString(),
        'title': r['title'] as String? ?? '',
        'done': r['completed'] as bool? ?? false,
      })
          .toList();

      //print('🟡 [Widget] Pushing streak=$currentStreak tasks=$todayTasks');

      await WidgetService.pushToWidget(
        streakCount: currentStreak,
        todayTasks: todayTasks,
      );

     // print('🟢 [Widget] Push succeeded');
    } catch (e, st) {
    //  print('🔴 [Widget] PUSH FAILED: $e');
      // print(st);
    }

    return HomeData(
      fullName: (profile?['full_name'] as String?)?.split(' ').first ?? 'there',
      avatarPath: profile?['avatar_path'] as String?,
      currentStreak: currentStreak,
      totalXp: (profile?['xp'] as int?) ?? 0,
      journalDoneToday: journalToday != null,
      moodSetToday: journalToday != null && journalToday['mood'] != null,
      daysCompletedThisWeek: daysCompletedThisWeek,
      weekdayCompletion: weekdayCompletion,
      upcomingTaskTitle: upcomingTitle,
      upcomingTaskCategory: upcomingCategory,
    );
  }
}