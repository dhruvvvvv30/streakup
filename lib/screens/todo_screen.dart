import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'streak_progress_screen.dart';
import 'calendar_screen.dart';
import '../service/streak_service.dart';
import '../shared_widgets.dart';

class _Task {
  final String id;
  String title;
  bool completed;
  bool repeats;
  List<int> repeatDays; // 1=Mon ... 7=Sun
  final DateTime createdAt;

  _Task({
    required this.id,
    required this.title,
    this.completed = false,
    this.repeats = false,
    this.repeatDays = const [],
    required this.createdAt,
  });

  factory _Task.fromMap(Map<String, dynamic> map) {
    return _Task(
      id: map['id'] as String,
      title: map['title'] as String,
      completed: map['completed'] as bool,
      repeats: map['repeats'] as bool? ?? false,
      repeatDays:
          (map['repeat_days'] as List?)?.map((e) => e as int).toList() ?? [],
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Non-repeating ("Just today") tasks disappear 24h after creation.
  /// Repeating tasks never expire this way.
  bool get isExpired =>
      !repeats && DateTime.now().difference(createdAt).inHours >= 24;
}

class _RepeatChoice {
  final bool repeats;
  final List<int> days;
  _RepeatChoice({required this.repeats, required this.days});
}

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => TodoScreenState();
}

enum _Filter { all, pending, completed }

class TodoScreenState extends State<TodoScreen> {
  final _supabase = Supabase.instance.client;
  final _streakService = StreakService();
  List<_Task> _tasks = [];
  StreakStats? _stats;
  bool _loading = true;
  _Filter _filter = _Filter.all;

  bool _selectionMode = false;
  final Set<String> _selectedTaskIds = {};

  Future<void> _fetchAll() async {
    setState(() => _loading = true);
    await Future.wait([_fetchTasks(), _fetchStats()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchTasks() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await _supabase
          .from('tasks')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (!mounted) return;

      final fetched = (response as List)
          .map((row) => _Task.fromMap(row))
          .toList();
      final expired = fetched.where((t) => t.isExpired).toList();
      final active = fetched.where((t) => !t.isExpired).toList();

      setState(() {
        _tasks = active;
      });

      if (expired.isNotEmpty) {
        _deleteExpiredTasks(expired);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load tasks: $e')));
      }
    }
  }

  Future<void> _deleteExpiredTasks(List<_Task> expired) async {
    try {
      await _supabase
          .from('tasks')
          .delete()
          .inFilter('id', expired.map((t) => t.id).toList());
    } catch (_) {
      // Non-fatal: if this fails they'll just get filtered out again next fetch.
    }
  }

  Future<void> _fetchStats() async {
    try {
      final stats = await _streakService.fetchStats();
      if (mounted) setState(() => _stats = stats);
    } catch (e) {
      // Non-fatal ? info card just falls back to placeholders if this fails
    }
  }

  List<_Task> get _visibleTasks {
    switch (_filter) {
      case _Filter.pending:
        return _tasks.where((t) => !t.completed).toList();
      case _Filter.completed:
        return _tasks.where((t) => t.completed).toList();
      case _Filter.all:
        return _tasks;
    }
  }

  Future<void> _addTask() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'New Task',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Task title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Next', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (title == null || title.isEmpty || !mounted) return;

    final repeatResult = await _showRepeatDialog();
    if (repeatResult == null) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final inserted = await _supabase
          .from('tasks')
          .insert({
            'user_id': userId,
            'title': title,
            'completed': false,
            'repeats': repeatResult.repeats,
            'repeat_days': repeatResult.repeats ? repeatResult.days : null,
          })
          .select()
          .single();

      setState(() {
        _tasks.insert(0, _Task.fromMap(inserted));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add task: $e')));
      }
    }
  }

  Future<void> triggerAddTask() async {
    await _addTask();
  }

  Future<_RepeatChoice?> _showRepeatDialog() async {
    // 0 = Just today, 1 = Every day, 2 = Specific days
    int mode = 0;
    final selectedDays = <int>{};
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return showDialog<_RepeatChoice>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'When should this repeat?',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RadioListTile<int>(
                contentPadding: EdgeInsets.zero,
                title: const Text('Just today'),
                value: 0,
                groupValue: mode,
                activeColor: const Color(0xFF6C5CE7),
                onChanged: (v) => setDialogState(() => mode = 0),
              ),
              RadioListTile<int>(
                contentPadding: EdgeInsets.zero,
                title: const Text('Every day'),
                value: 1,
                groupValue: mode,
                activeColor: const Color(0xFF6C5CE7),
                onChanged: (v) => setDialogState(() => mode = 1),
              ),
              RadioListTile<int>(
                contentPadding: EdgeInsets.zero,
                title: const Text('Repeat on specific days'),
                value: 2,
                groupValue: mode,
                activeColor: const Color(0xFF6C5CE7),
                onChanged: (v) => setDialogState(() => mode = 2),
              ),
              if (mode == 2) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(7, (i) {
                    final dayNum = i + 1;
                    final selected = selectedDays.contains(dayNum);
                    return FilterChip(
                      label: Text(dayLabels[i]),
                      selected: selected,
                      selectedColor: const Color(0xFFEDEBFB),
                      checkmarkColor: const Color(0xFF6C5CE7),
                      labelStyle: TextStyle(
                        color: selected
                            ? const Color(0xFF6C5CE7)
                            : const Color(0xFF8B8C9E),
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (v) => setDialogState(() {
                        if (v) {
                          selectedDays.add(dayNum);
                        } else {
                          selectedDays.remove(dayNum);
                        }
                      }),
                    );
                  }),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
              ),
              onPressed: () {
                if (mode == 2 && selectedDays.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Pick at least one day, or choose "Just today" / "Every day"',
                      ),
                    ),
                  );
                  return;
                }

                if (mode == 0) {
                  Navigator.pop(ctx, _RepeatChoice(repeats: false, days: []));
                } else if (mode == 1) {
                  Navigator.pop(
                    ctx,
                    _RepeatChoice(repeats: true, days: [1, 2, 3, 4, 5, 6, 7]),
                  );
                } else {
                  Navigator.pop(
                    ctx,
                    _RepeatChoice(
                      repeats: true,
                      days: selectedDays.toList()..sort(),
                    ),
                  );
                }
              },
              child: const Text('Done', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editTask(_Task task) async {
    final controller = TextEditingController(text: task.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Edit Task',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Task title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (newTitle == null ||
        newTitle.isEmpty ||
        newTitle == task.title ||
        !mounted)
      return;

    final oldTitle = task.title;
    setState(() => task.title = newTitle);

    try {
      await _supabase
          .from('tasks')
          .update({'title': newTitle})
          .eq('id', task.id);
    } catch (e) {
      setState(() => task.title = oldTitle);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update task: $e')));
      }
    }
  }

  Future<void> _toggleTask(_Task task) async {
    final newValue = !task.completed;
    setState(() => task.completed = newValue);

    try {
      await _streakService.toggleTaskCompletion(task.id, newValue);
      await _fetchStats(); // refresh streak/XP shown on this screen too
    } catch (e) {
      setState(() => task.completed = !newValue);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update task: $e')));
      }
    }
  }

  Future<void> _deleteTask(_Task task) async {
    final removedIndex = _tasks.indexOf(task);
    setState(() => _tasks.remove(task));

    try {
      await _supabase.from('tasks').delete().eq('id', task.id);
    } catch (e) {
      setState(() => _tasks.insert(removedIndex, task));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete task: $e')));
      }
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedTaskIds.clear();
    });
  }

  void _toggleSelectAll() {
    final tasks = _visibleTasks;
    final allSelected =
        tasks.isNotEmpty && tasks.every((t) => _selectedTaskIds.contains(t.id));
    setState(() {
      if (allSelected) {
        _selectedTaskIds.clear();
      } else {
        _selectedTaskIds
          ..clear()
          ..addAll(tasks.map((t) => t.id));
      }
    });
  }

  void _toggleTaskSelected(_Task task) {
    setState(() {
      if (_selectedTaskIds.contains(task.id)) {
        _selectedTaskIds.remove(task.id);
      } else {
        _selectedTaskIds.add(task.id);
      }
    });
  }

  Future<void> _deleteSelectedTasks() async {
    if (_selectedTaskIds.isEmpty) return;

    final idsToDelete = _selectedTaskIds.toList();
    final removedTasks = _tasks
        .where((t) => idsToDelete.contains(t.id))
        .toList();

    setState(() {
      _tasks.removeWhere((t) => idsToDelete.contains(t.id));
      _selectedTaskIds.clear();
      _selectionMode = false;
    });

    try {
      await _supabase.from('tasks').delete().inFilter('id', idsToDelete);
    } catch (e) {
      setState(() {
        _tasks.insertAll(0, removedTasks);
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete tasks: $e')));
      }
    }
  }

  String _ordinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1:
        return '${day}st';
      case 2:
        return '${day}nd';
      case 3:
        return '${day}rd';
      default:
        return '${day}th';
    }
  }

  String _weekdayName(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[weekday - 1];
  }

  String _monthName(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[month - 1];
  }

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAll,
      color: const Color(0xFF6C5CE7),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppTopBar(),
            const SizedBox(height: 12),
            Text(
              'To-do List',
              style: GoogleFonts.schoolbell(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E1C3B),
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoCards(now),
            const SizedBox(height: 16),
            _buildFilterTabs(),
            const SizedBox(height: 8),
            _buildSelectionBar(),
            const SizedBox(height: 4),
            _buildAddTaskRow(),
            const SizedBox(height: 12),
            _buildTaskList(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCards(DateTime now) {
    final streakValue = _stats != null ? '${_stats!.currentStreak}' : '?';
    final xpValue = _stats != null ? '${_stats!.totalXp}+ Xp' : '? Xp';

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CalendarScreen()),
            ),
            child: _infoCard(
              icon: Icons.calendar_month_rounded,
              iconBg: const Color(0xFFEDEBFB),
              iconColor: const Color(0xFF6C5CE7),
              topLine:
                  '${_ordinal(now.day)} ${_monthName(now.month)}, ${now.year}',
              subLine: _weekdayName(now.weekday),
              actionLabel: 'View calendar',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StreakProgressScreen()),
              );
              _fetchStats(); // refresh in case streak/XP changed while on that screen
            },
            child: _infoCard(
              icon: Icons.local_fire_department_rounded,
              iconBg: const Color(0xFFFFF0EC),
              iconColor: const Color(0xFFFF7A45),
              topLine: streakValue,
              topLineSuffix: 'day streak',
              subLine: xpValue,
              actionLabel: 'See progress',
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String topLine,
    String? topLineSuffix,
    required String subLine,
    required String actionLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFECEFFC), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: topLineSuffix == null
                    ? Text(
                        topLine,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1E1C3B),
                        ),
                      )
                    : Text(
                        topLine,
                        style: GoogleFonts.nunito(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1E1C3B),
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subLine,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8B8C9E),
            ),
          ),
          const Divider(height: 18, color: Color(0xFFECEFFC)),
          Row(
            children: [
              Expanded(
                child: Text(
                  actionLabel,
                  style: GoogleFonts.nunito(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF6C5CE7),
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: Color(0xFF6C5CE7),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    Widget tab(String label, _Filter value) {
      final active = _filter == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _filter = value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFEDEBFB) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: active
                      ? const Color(0xFF6C5CE7)
                      : const Color(0xFF8B8C9E),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECEFFC), width: 1.2),
      ),
      child: Row(
        children: [
          tab('All tasks', _Filter.all),
          tab('Pending', _Filter.pending),
          tab('Completed', _Filter.completed),
        ],
      ),
    );
  }

  /// Row under the filter tabs. Idle: a single "select mode" icon button.
  /// Active: select-all icon, a delete icon (with count badge), and a
  /// close icon to cancel — all icons, no text buttons.
  Widget _buildSelectionBar() {
    final tasks = _visibleTasks;
    final allSelected =
        tasks.isNotEmpty && tasks.every((t) => _selectedTaskIds.contains(t.id));

    if (!_selectionMode) {
      return Align(
        alignment: Alignment.centerRight,
        child: IconButton(
          onPressed: tasks.isEmpty ? null : _toggleSelectionMode,
          tooltip: 'Select tasks',
          icon: Icon(
            Icons.playlist_add_check_rounded,
            color: tasks.isEmpty
                ? const Color(0xFFC7C5DE)
                : const Color(0xFF6C5CE7),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: _toggleSelectAll,
          tooltip: allSelected ? 'Deselect all' : 'Select all',
          icon: Icon(
            allSelected
                ? Icons.check_box_rounded
                : Icons.check_box_outline_blank_rounded,
            color: const Color(0xFF6C5CE7),
          ),
        ),
        Row(
          children: [
            if (_selectedTaskIds.isNotEmpty)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: _deleteSelectedTasks,
                    tooltip: 'Delete selected',
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(minWidth: 14),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_selectedTaskIds.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            IconButton(
              onPressed: _toggleSelectionMode,
              tooltip: 'Cancel',
              icon: const Icon(Icons.close_rounded, color: Color(0xFF8B8C9E)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAddTaskRow() {
    return GestureDetector(
      onTap: _addTask,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFECEFFC), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF6C5CE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Add New Task',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF6C5CE7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList() {
    final tasks = _visibleTasks;
    if (tasks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No tasks here',
            style: GoogleFonts.nunito(
              color: const Color(0xFF8B8C9E),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECEFFC), width: 1.2),
      ),
      child: Column(
        children: List.generate(tasks.length, (i) {
          final task = tasks[i];
          final isSelected = _selectedTaskIds.contains(task.id);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (_selectionMode) {
                          _toggleTaskSelected(task);
                        } else {
                          _toggleTask(task);
                        }
                      },
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _selectionMode
                              ? (isSelected
                                    ? const Color(0xFF6C5CE7)
                                    : Colors.transparent)
                              : (task.completed
                                    ? const Color(0xFF6C5CE7)
                                    : Colors.transparent),
                          border: Border.all(
                            color: const Color(0xFF6C5CE7),
                            width: 2,
                          ),
                        ),
                        child: _selectionMode
                            ? (isSelected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                  : null)
                            : (task.completed
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                  : null),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: GestureDetector(
                        onTap: _selectionMode
                            ? () => _toggleTaskSelected(task)
                            : null,
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: GoogleFonts.nunito(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: task.completed
                                    ? const Color(0xFF8B8C9E)
                                    : const Color(0xFF1E1C3B),
                                decoration: task.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            if (task.repeats && task.repeatDays.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.repeat_rounded,
                                      size: 12,
                                      color: Color(0xFF6C5CE7),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      _repeatLabel(task.repeatDays),
                                      style: GoogleFonts.nunito(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF6C5CE7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (!_selectionMode)
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_horiz_rounded,
                          color: Color(0xFF8B8C9E),
                        ),
                        onSelected: (value) {
                          if (value == 'edit') _editTask(task);
                          if (value == 'delete') _deleteTask(task);
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (i != tasks.length - 1)
                const Divider(height: 1, color: Color(0xFFECEFFC)),
            ],
          );
        }),
      ),
    );
  }

  String _repeatLabel(List<int> days) {
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (days.length == 7) return 'Every day';
    return days.map((d) => dayLabels[d - 1]).join(', ');
  }
}
