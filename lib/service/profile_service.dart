import 'package:supabase_flutter/supabase_flutter.dart';
import 'streak_service.dart';

class ProfileDetailData {
  final String fullName;
  final String username;
  final String? birthdayFormatted;
  final String? avatarPath;
  final String tagline;
  final int currentStreak;
  final int totalJournalEntries;
  final int completedTasks;

  ProfileDetailData({
    required this.fullName,
    required this.username,
    required this.birthdayFormatted,
    required this.avatarPath,
    required this.tagline,
    required this.currentStreak,
    required this.totalJournalEntries,
    required this.completedTasks,
  });
}

class ProfileService {
  final _supabase = Supabase.instance.client;

  String _ordinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1: return '${day}st';
      case 2: return '${day}nd';
      case 3: return '${day}rd';
      default: return '${day}th';
    }
  }

  String _monthName(int month) {
    const names = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    return names[month - 1];
  }

  Future<ProfileDetailData> fetchProfileDetail() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return ProfileDetailData(
        fullName: 'there',
        username: '',
        birthdayFormatted: null,
        avatarPath: null,
        tagline: 'Small steps. Big progress.',
        currentStreak: 0,
        totalJournalEntries: 0,
        completedTasks: 0,
      );
    }

    final profile = await _supabase
        .from('profiles')
        .select('full_name, username, date_of_birth, avatar_path, motivation')
        .eq('id', userId)
        .maybeSingle();

    String? birthdayFormatted;
    final dobRaw = profile?['date_of_birth'] as String?;
    if (dobRaw != null) {
      final dob = DateTime.parse(dobRaw);
      birthdayFormatted = '${_ordinal(dob.day)} ${_monthName(dob.month)} ${dob.year}';
    }

    final journalCountResp = await _supabase
        .from('journal_entries')
        .select('id')
        .eq('user_id', userId)
        .count(CountOption.exact);

    int completedTasksCount = 0;
    try {
      final tasksCountResp = await _supabase
          .from('tasks')
          .select('id')
          .eq('user_id', userId)
          .eq('completed', true)
          .count(CountOption.exact);
      completedTasksCount = tasksCountResp.count;
    } catch (_) {
      // tasks table/columns may differ — falls back to 0
    }

    final stats = await StreakService().fetchStats();

    final motivation = profile?['motivation'] as String?;

    return ProfileDetailData(
      fullName: (profile?['full_name'] as String?) ?? 'there',
      username: (profile?['username'] as String?) ?? '',
      birthdayFormatted: birthdayFormatted,
      avatarPath: profile?['avatar_path'] as String?,
      tagline: (motivation != null && motivation.trim().isNotEmpty) ? motivation : 'Small steps. Big progress.',
      currentStreak: stats.currentStreak,
      totalJournalEntries: journalCountResp.count,
      completedTasks: completedTasksCount,
    );
  }
  Future<void> updateNameUsername(String fullName, String username) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    await _supabase.from('profiles').update({
      'full_name': fullName,
      'username': username,
    }).eq('id', userId);
  }

  Future<void> updateBirthday(DateTime dob) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    await _supabase.from('profiles').update({
      'date_of_birth': dob.toIso8601String(),
    }).eq('id', userId);
  }

  Future<void> updateAvatar(String avatarPath, String gender) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    await _supabase.from('profiles').update({
      'avatar_path': avatarPath,
      'gender': gender,
    }).eq('id', userId);
  }
}