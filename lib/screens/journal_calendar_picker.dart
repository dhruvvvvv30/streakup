import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shared_widgets.dart';
import '../service/journal_service.dart';

/// Custom calendar dialog for picking a journal date, with days colored
/// green if an entry exists for that day and red if it doesn't.
class JournalCalendarPicker extends StatefulWidget {
  final DateTime initialDate;
  const JournalCalendarPicker({super.key, required this.initialDate});

  @override
  State<JournalCalendarPicker> createState() => _JournalCalendarPickerState();
}

class _JournalCalendarPickerState extends State<JournalCalendarPicker> {
  final _service = JournalService();
  late DateTime _visibleMonth;
  late DateTime _selected;
  Set<int> _journaledDays = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
    _visibleMonth = DateTime(widget.initialDate.year, widget.initialDate.month, 1);
    _loadMonth();
  }

  Future<void> _loadMonth() async {
    setState(() => _loading = true);
    try {
      final days = await _service.fetchJournaledDaysForMonth(_visibleMonth);
      if (mounted) {
        setState(() {
          _journaledDays = days;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeMonth(int delta) {
    final now = DateTime.now();
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + delta, 1);
    if (next.isAfter(DateTime(now.year, now.month, 1))) return;
    setState(() => _visibleMonth = next);
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
    const weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_visibleMonth.year, _visibleMonth.month, 1).weekday % 7;
    final today = DateTime.now();
    final isCurrentMonth = _visibleMonth.year == today.year && _visibleMonth.month == today.month;

    final cells = <int?>[
      ...List.filled(firstWeekday, null),
      ...List.generate(daysInMonth, (i) => i + 1),
    ];

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => _changeMonth(-1),
                  child: const Icon(Icons.chevron_left_rounded, color: AppColors.sub),
                ),
                Text(
                  '${_monthName(_visibleMonth.month)} ${_visibleMonth.year}',
                  style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.ink),
                ),
                GestureDetector(
                  onTap: isCurrentMonth ? null : () => _changeMonth(1),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: isCurrentMonth ? AppColors.cardBorder : AppColors.sub,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: weekdayLabels
                  .map((d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: GoogleFonts.nunito(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.sub),
                  ),
                ),
              ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(color: AppColors.purple),
              )
            else
              SizedBox(
                width: 280,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cells.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 4,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final day = cells[index];
                    if (day == null) return const SizedBox.shrink();

                    final cellDate = DateTime(_visibleMonth.year, _visibleMonth.month, day);
                    final isFuture = cellDate.isAfter(DateTime(today.year, today.month, today.day));
                    final isSelected = cellDate.year == _selected.year &&
                        cellDate.month == _selected.month &&
                        cellDate.day == _selected.day;
                    final isJournaled = _journaledDays.contains(day);

                    Color bg;
                    Color textColor;
                    if (isFuture) {
                      bg = Colors.transparent;
                      textColor = AppColors.cardBorder;
                    } else if (isJournaled) {
                      bg = const Color(0xFFDCF5E4);
                      textColor = const Color(0xFF2E9B57);
                    } else {
                      bg = const Color(0xFFFCE1E1);
                      textColor = const Color(0xFFD64545);
                    }

                    return GestureDetector(
                      onTap: isFuture ? null : () => Navigator.pop(context, cellDate),
                      child: Container(
                        margin: const EdgeInsets.all(1),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: bg,
                          shape: BoxShape.circle,
                          border: isSelected ? Border.all(color: AppColors.purple, width: 2) : null,
                        ),
                        child: Text(
                          '$day',
                          style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w800, color: textColor),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF2E9B57), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('Journaled', style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.sub)),
                const SizedBox(width: 16),
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFD64545), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('Missed', style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.sub)),
              ],
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.sub)),
            ),
          ],
        ),
      ),
    );
  }
}