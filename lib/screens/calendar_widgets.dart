import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../service/streak_service.dart';

class CalColors {
  static const purple = Color(0xFF6C5CE7);
  static const lightPurple = Color(0xFFDCD6FA);
  static const ink = Color(0xFF1E1C3B);
  static const sub = Color(0xFF8B8C9E);
}

class MonthlyStreakCalendar extends StatefulWidget {
  const MonthlyStreakCalendar({super.key});

  @override
  State<MonthlyStreakCalendar> createState() => _MonthlyStreakCalendarState();
}

class _MonthlyStreakCalendarState extends State<MonthlyStreakCalendar> {
  final _streakService = StreakService();
  final DateTime _today = DateTime.now();
  late DateTime _visibleMonth;
  Set<int> _completedDays = {};
  Set<int> _freezeDays = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(_today.year, _today.month, 1);
    _loadMonth();
  }

  Future<void> _loadMonth() async {
    setState(() => _loading = true);
    try {
      final completed = await _streakService.fetchCompletedDaysForMonth(_visibleMonth);
      final freeze = await _streakService.fetchFreezeDaysForMonth(_visibleMonth);
      if (mounted) {
        setState(() {
          _completedDays = completed;
          _freezeDays = freeze;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load calendar: $e')),
        );
      }
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta, 1);
    });
    _loadMonth();
  }

  String _monthName(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    const weekdayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_visibleMonth.year, _visibleMonth.month, 1).weekday % 7;

    final cells = <int?>[
      ...List.filled(firstWeekday, null),
      ...List.generate(daysInMonth, (i) => i + 1),
    ];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => _changeMonth(-1),
              child: const Icon(Icons.chevron_left_rounded, color: CalColors.sub),
            ),
            Text('${_monthName(_visibleMonth.month)} ${_visibleMonth.year}',
                style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w900, color: CalColors.ink)),
            GestureDetector(
              onTap: () => _changeMonth(1),
              child: const Icon(Icons.chevron_right_rounded, color: CalColors.sub),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFEFEFFE)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Monthly', style: GoogleFonts.nunito(fontSize: 11.5, fontWeight: FontWeight.w800, color: CalColors.ink)),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: CalColors.sub),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: weekdayLabels
              .map((d) => Expanded(
            child: Center(
              child: Text(d, style: GoogleFonts.nunito(fontSize: 11.5, fontWeight: FontWeight.w700, color: CalColors.sub)),
            ),
          ))
              .toList(),
        ),
        const SizedBox(height: 10),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: CircularProgressIndicator(color: CalColors.purple),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final day = cells[index];
              if (day == null) return const SizedBox.shrink();

              final isToday = _visibleMonth.year == _today.year &&
                  _visibleMonth.month == _today.month &&
                  day == _today.day;
              final isCompleted = _completedDays.contains(day);
              final isFreeze = _freezeDays.contains(day);

              Color bg;
              Color textColor;
              if (isToday) {
                bg = CalColors.purple;
                textColor = Colors.white;
              } else if (isCompleted) {
                bg = CalColors.lightPurple;
                textColor = CalColors.purple;
              } else {
                bg = Colors.transparent;
                textColor = CalColors.ink;
              }

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bg,
                      shape: isToday ? BoxShape.circle : BoxShape.rectangle,
                      borderRadius: isToday ? null : BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$day',
                      style: GoogleFonts.nunito(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (isFreeze)
                    const Positioned(
                      top: -3,
                      right: -1,
                      child: Icon(Icons.eco_rounded, size: 13, color: Color(0xFF4CAF7D)),
                    ),
                ],
              );
            },
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            Container(width: 10, height: 10, decoration: const BoxDecoration(color: CalColors.purple, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('Completed', style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: CalColors.sub)),
            const SizedBox(width: 16),
            const Icon(Icons.eco_rounded, size: 14, color: Color(0xFF4CAF7D)),
            const SizedBox(width: 6),
            Text('Freeze used', style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: CalColors.sub)),
          ],
        ),
      ],
    );
  }
}