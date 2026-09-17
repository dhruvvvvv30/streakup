import 'package:supabase_flutter/supabase_flutter.dart';

class JournalEntry {
  final String id;
  final DateTime day;
  String entryText;
  String? mood;

  JournalEntry({
    required this.id,
    required this.day,
    required this.entryText,
    this.mood,
  });

  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    return JournalEntry(
      id: map['id'] as String,
      day: DateTime.parse(map['day'] as String),
      entryText: map['entry_text'] as String? ?? '',
      mood: map['mood'] as String?,
    );
  }
}

class JournalService {
  final _supabase = Supabase.instance.client;

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<JournalEntry?> fetchEntryForDay(DateTime day) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _supabase
        .from('journal_entries')
        .select()
        .eq('user_id', userId)
        .eq('day', _dateOnly(day))
        .maybeSingle();

    return row == null ? null : JournalEntry.fromMap(row);
  }

  /// Most recent entry strictly before [beforeDay]. Kept for callers that
  /// explicitly want to exclude "today" (e.g. a true "yesterday" widget).
  Future<JournalEntry?> fetchLatestEntryBefore(DateTime beforeDay) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final rows = await _supabase
        .from('journal_entries')
        .select()
        .eq('user_id', userId)
        .lt('day', _dateOnly(beforeDay))
        .order('day', ascending: false)
        .limit(1);

    final list = rows as List;
    return list.isEmpty ? null : JournalEntry.fromMap(list.first);
  }

  /// Most recent journal entry overall (today included). Use this for a
  /// "Latest entry" widget that should update the instant a new entry is saved.
  Future<JournalEntry?> fetchLatestEntry() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final rows = await _supabase
        .from('journal_entries')
        .select()
        .eq('user_id', userId)
        .order('day', ascending: false)
        .order('updated_at', ascending: false)
        .limit(1);

    final list = rows as List;
    return list.isEmpty ? null : JournalEntry.fromMap(list.first);
  }

  /// Days (1-31) within [month] that have a journal entry, for calendar coloring.
  Future<Set<int>> fetchJournaledDaysForMonth(DateTime month) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {};

    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    final rows = await _supabase
        .from('journal_entries')
        .select('day')
        .eq('user_id', userId)
        .gte('day', _dateOnly(firstDay))
        .lte('day', _dateOnly(lastDay));

    return (rows as List)
        .map((r) => DateTime.parse(r['day'] as String).day)
        .toSet();
  }

  Future<List<JournalEntry>> fetchAllEntries() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final rows = await _supabase
        .from('journal_entries')
        .select()
        .eq('user_id', userId)
        .order('day', ascending: false);

    return (rows as List).map((r) => JournalEntry.fromMap(r)).toList();
  }

  Future<JournalEntry> saveEntry({
    required DateTime day,
    required String text,
    String? mood,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not signed in');

    final row = await _supabase
        .from('journal_entries')
        .upsert(
      {
        'user_id': userId,
        'day': _dateOnly(day),
        'entry_text': text,
        'mood': mood,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,day',
    )
        .select()
        .single();

    return JournalEntry.fromMap(row);
  }

  Future<void> updateEntryText(String id, String text) async {
    await _supabase.from('journal_entries').update({
      'entry_text': text,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteEntry(String id) async {
    await _supabase.from('journal_entries').delete().eq('id', id);
  }
}