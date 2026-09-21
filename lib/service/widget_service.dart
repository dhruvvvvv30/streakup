import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'streak_service.dart';
import 'supabase_config.dart';

class WidgetService {
  WidgetService._();

  static const _androidName = 'StreakWidgetProvider';

  /// Screens can listen to this and reload when widget changes were synced.
  static final ValueNotifier<int> dataVersion = ValueNotifier<int>(0);

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------------------
  // Supabase (the widget background isolate does NOT run main())
  // ---------------------------------------------------------------------------
  static Future<bool> _ensureSupabase() async {
    try {
      final _ = Supabase.instance.client;
      return true;
    } catch (_) {
      try {
        await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
        return true;
      } catch (e) {
        debugPrint('[Widget] Supabase init failed: $e');
        return false;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Local (widget) storage helpers
  // ---------------------------------------------------------------------------
  static Future<List<String>> _readPending() async {
    final raw = await HomeWidget.getWidgetData<String>(
      'pending_toggles',
      defaultValue: '[]',
    );

    try {
      return (jsonDecode(raw ?? '[]') as List)
          .map((e) => e.toString())
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, bool>> _readLocalTasks() async {
    final raw = await HomeWidget.getWidgetData<String>(
      'today_tasks',
      defaultValue: '[]',
    );

    try {
      final list = (jsonDecode(raw ?? '[]') as List)
          .cast<Map<String, dynamic>>();

      return {
        for (final t in list) t['id'].toString(): (t['done'] as bool? ?? false),
      };
    } catch (_) {
      return {};
    }
  }

  static Future<void> _clearPending(String taskId) async {
    final pending = await _readPending()
      ..remove(taskId);

    await HomeWidget.saveWidgetData<String>(
      'pending_toggles',
      jsonEncode(pending),
    );
  }

  // ---------------------------------------------------------------------------
  // Push data to the native widget
  // ---------------------------------------------------------------------------
  static Future<void> pushToWidget({
    required int streakCount,
    required List<Map<String, dynamic>> todayTasks,
  }) async {
    // HomeWidget is not available on Flutter Web.
    if (kIsWeb) {
      return;
    }

    await HomeWidget.saveWidgetData<int>('streak_count', streakCount);

    await HomeWidget.saveWidgetData<String>(
      'today_tasks',
      jsonEncode(todayTasks),
    );

    await HomeWidget.saveWidgetData<String>(
      'data_date',
      _dateOnly(DateTime.now()),
    );

    // Stored as a String on purpose: Kotlin reads it back as a Long.
    await HomeWidget.saveWidgetData<String>(
      'last_refresh',
      DateTime.now().millisecondsSinceEpoch.toString(),
    );

    // last_refresh must be saved BEFORE this call, or onUpdate would loop.
    await HomeWidget.updateWidget(androidName: _androidName);
  }

  /// Fetches streak + tasks using the SAME rules as the To-Do screen.
  /// Call after any task change: create, edit, delete, toggle.
  static Future<void> refreshFromServer() async {
    // HomeWidget is not available on Flutter Web.
    if (kIsWeb) {
      return;
    }

    try {
      if (!await _ensureSupabase()) return;

      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) return;

      final now = DateTime.now();

      final todayStartUtc = DateTime(
        now.year,
        now.month,
        now.day,
      ).toUtc().toIso8601String();

      final cutoff = now
          .toUtc()
          .subtract(const Duration(hours: 24))
          .toIso8601String();

      // ---- Streak (consecutive days ending today) ----
      final dayRows = await client
          .from('streak_days')
          .select('day')
          .eq('user_id', userId);

      final daySet = (dayRows as List).map((r) {
        final d = DateTime.parse(r['day'] as String);
        return DateTime(d.year, d.month, d.day);
      }).toSet();

      var streak = 0;
      var cursor = DateTime(now.year, now.month, now.day);

      while (daySet.contains(cursor)) {
        streak++;
        cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
      }

      // ---- Tasks: identical query to TodoScreen._fetchTasks ----
      final rows = await client
          .from('tasks')
          .select()
          .eq('user_id', userId)
          .or('repeats.eq.true,created_at.gt.$cutoff')
          .order('created_at', ascending: false);

      final events = await client
          .from('task_completion_events')
          .select('task_id')
          .eq('user_id', userId)
          .gte('completed_at', todayStartUtc);

      final doneToday = (events as List)
          .map((e) => e['task_id'].toString())
          .toSet();

      // Keep taps that haven't reached Supabase yet
      final pending = await _readPending();
      final local = await _readLocalTasks();

      final tasks = <Map<String, dynamic>>[];

      for (final r in (rows as List)) {
        final id = r['id'].toString();

        final repeats = r['repeats'] as bool? ?? false;

        final repeatDays =
            (r['repeat_days'] as List?)?.map((e) => e as int).toList() ??
            <int>[];

        final createdAt = DateTime.parse(r['created_at'] as String);

        final expired = !repeats && now.difference(createdAt).inHours >= 24;

        final dueToday = !repeats || repeatDays.contains(now.weekday);

        if (expired || !dueToday) continue;

        var done = repeats
            ? doneToday.contains(id)
            : (r['completed'] as bool? ?? false);

        if (pending.contains(id) && local.containsKey(id)) {
          done = local[id]!;
        }

        tasks.add({
          'id': id,
          'title': r['title'] as String? ?? '',
          'done': done,
        });
      }

      await pushToWidget(streakCount: streak, todayTasks: tasks);
    } catch (e) {
      debugPrint('[Widget] refresh failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Widget tap -> Supabase (full logic: XP, events, streak_days)
  // ---------------------------------------------------------------------------
  static Future<void> registerBackgroundCallBack() async {
    // HomeWidget interactivity callbacks are not supported on Flutter Web.
    if (kIsWeb) {
      return;
    }

    await HomeWidget.registerInteractivityCallback(backgroundCallback);
  }

  static Future<void> _syncSingleToggle(String taskId) async {
    try {
      final local = await _readLocalTasks();

      if (!local.containsKey(taskId)) {
        await _clearPending(taskId);
        return;
      }

      if (!await _ensureSupabase()) return;

      if (Supabase.instance.client.auth.currentUser == null) {
        return;
      }

      await StreakService().toggleTaskCompletion(taskId, local[taskId]!);

      await _clearPending(taskId);
    } catch (e) {
      debugPrint('[Widget] toggle sync failed (will retry on resume): $e');
    }
  }

  static Future<void> syncPendingToggles() async {
    // HomeWidget is not available on Flutter Web.
    if (kIsWeb) {
      return;
    }

    final pending = await _readPending();

    for (final id in pending) {
      await _syncSingleToggle(id);
    }
  }

  /// Call on app start and whenever the app returns to the foreground.
  static Future<void> onAppResumed() async {
    // HomeWidget is not available on Flutter Web.
    if (kIsWeb) {
      return;
    }

    await syncPendingToggles();
    await refreshFromServer();
    dataVersion.value++;
  }
}

/// Must stay top-level. Runs in a separate isolate when a widget row is tapped.
@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  if (uri?.host == 'toggle') {
    final taskId = uri!.queryParameters['taskId'];

    if (taskId != null) {
      await WidgetService._syncSingleToggle(taskId);
    }
  } else if (uri?.host == 'refresh') {
    await WidgetService.refreshFromServer();
  }
}
