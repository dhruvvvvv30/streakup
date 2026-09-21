import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shared_widgets.dart';
import '../service/journal_service.dart';
import '../service/ai_service.dart';
import 'journal_entries.dart';
import 'journal_calendar_picker.dart';

class JournalScreenContent extends StatefulWidget {
  const JournalScreenContent({super.key});

  @override
  State<JournalScreenContent> createState() => JournalScreenContentState();
}

class JournalScreenContentState extends State<JournalScreenContent> {
  final _entry = TextEditingController();
  final _entryFocus = FocusNode();

  final _service = JournalService();

  String? _selectedMood;
  DateTime _selectedDate = DateTime.now();

  JournalEntry? _currentEntry;
  JournalEntry? _latestEntry;

  bool _loading = true;
  bool _loadingSuggestions = false;

  @override
  void initState() {
    super.initState();

    _loadForDate(_selectedDate);
    _loadInsights();
  }

  @override
  void dispose() {
    _entry.dispose();
    _entryFocus.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // START WRITING
  // --------------------------------------------------

  void triggerStartWriting() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_entryFocus);
    });
  }

  // --------------------------------------------------
  // LOAD JOURNAL FOR SELECTED DATE
  // --------------------------------------------------

  Future<void> _loadForDate(DateTime date) async {
    setState(() => _loading = true);

    try {
      final entry = await _service.fetchEntryForDay(date);

      if (mounted) {
        setState(() {
          _currentEntry = entry;
          _entry.text = entry?.entryText ?? '';
          _selectedMood = entry?.mood;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load entry: $e')));
      }
    }
  }

  // --------------------------------------------------
  // LOAD LATEST ENTRY
  // --------------------------------------------------

  Future<void> _loadInsights() async {
    try {
      final entry = await _service.fetchLatestEntry();

      if (mounted) {
        setState(() => _latestEntry = entry);
      }
    } catch (e) {
      // Non-fatal.
    }
  }

  // --------------------------------------------------
  // PICK DATE
  // --------------------------------------------------

  Future<void> _pickDate() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) {
        return JournalCalendarPicker(initialDate: _selectedDate);
      },
    );

    if (picked == null) return;

    setState(() => _selectedDate = picked);

    _loadForDate(picked);
  }

  // --------------------------------------------------
  // SAVE JOURNAL
  // --------------------------------------------------

  Future<void> _saveJournal() async {
    try {
      final saved = await _service.saveEntry(
        day: _selectedDate,
        text: _entry.text.trim(),
        mood: _selectedMood,
      );

      if (mounted) {
        setState(() => _currentEntry = saved);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Journal saved!')));

        _loadInsights();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }

  // --------------------------------------------------
  // AI SUGGESTIONS
  // --------------------------------------------------

  Future<void> _getAISuggestions() async {
    if (_loadingSuggestions) return;

    setState(() {
      _loadingSuggestions = true;
    });

    try {
      final entries = await _service.fetchAllEntries();

      final journals = entries
          .map((entry) => entry.entryText.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      if (journals.isEmpty) {
        if (mounted) {
          setState(() {
            _loadingSuggestions = false;
          });

          _showSuggestionsSheet(const [
            'What was one meaningful moment from your day?',
            'What was something you learned about yourself today?',
            'What is one thing you would like to improve tomorrow?',
          ]);
        }

        return;
      }

      final suggestions = await AIService.getSuggestions(journals);

      if (!mounted) return;

      setState(() {
        _loadingSuggestions = false;
      });

      if (suggestions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'AI suggestions are temporarily unavailable. Please try again later.',
            ),
          ),
        );

        return;
      }

      _showSuggestionsSheet(suggestions);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingSuggestions = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate suggestions: $e')),
      );
    }
  }

  // --------------------------------------------------
  // SHOW AI SUGGESTIONS
  // --------------------------------------------------

  void _showSuggestionsSheet(List<String> suggestions) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDEBFB),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.purple,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'AI Suggestions',
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.sub,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Text(
                  'Use these questions to reflect on your day.',
                  style: GoogleFonts.nunito(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.sub,
                  ),
                ),

                const SizedBox(height: 18),

                ...List.generate(suggestions.length, (index) {
                  final question = suggestions[index];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F6FF),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: AppColors.purple.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.purple,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: GoogleFonts.nunito(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            question,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // --------------------------------------------------
  // DATE FORMAT
  // --------------------------------------------------

  String _formatDate(DateTime d) {
    const months = [
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

    return '${d.day} ${months[d.month - 1]}, ${d.year}';
  }

  // --------------------------------------------------
  // INSIGHTS MENU
  // --------------------------------------------------

  void _openInsightsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.purple,
                ),
                title: Text(
                  'View All Entries',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                ),
                onTap: () {
                  Navigator.pop(ctx);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const JournalEntriesScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --------------------------------------------------
  // BUILD
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isToday =
        _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        const AppTopBar(),

        const SizedBox(height: 18),

        Text(
          'Journal',
          style: GoogleFonts.schoolbell(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.ink,
          ),
        ),

        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: softCard(),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: AppColors.purple,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isToday
                            ? '${_formatDate(_selectedDate)} (Today)'
                            : _formatDate(_selectedDate),
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDEBFB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_rounded,
                            size: 14,
                            color: AppColors.purple,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'View Calendar',
                            style: GoogleFonts.nunito(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.purple,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: CircularProgressIndicator(color: AppColors.purple),
                )
              else
                Container(
                  height: 120,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: TextField(
                    controller: _entry,
                    focusNode: _entryFocus,
                    maxLines: null,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: AppColors.ink,
                    ),
                    decoration: InputDecoration(
                      hintText: 'How was your day?',
                      hintStyle: GoogleFonts.nunito(color: AppColors.sub),
                      border: InputBorder.none,
                    ),
                  ),
                ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loadingSuggestions ? null : _getAISuggestions,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppColors.purple.withValues(alpha: 0.3),
                        ),
                        backgroundColor: const Color(0xFFF6F2FF),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _loadingSuggestions
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.purple,
                              ),
                            )
                          : const Icon(
                              Icons.auto_awesome_rounded,
                              size: 16,
                              color: AppColors.purple,
                            ),
                      label: Text(
                        _loadingSuggestions ? 'Thinking...' : 'AI Suggestions',
                        style: GoogleFonts.nunito(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.purple,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saveJournal,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppColors.purple.withValues(alpha: 0.3),
                        ),
                        backgroundColor: const Color(0xFFF6F2FF),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(
                        Icons.favorite_border_rounded,
                        size: 16,
                        color: AppColors.purple,
                      ),
                      label: Text(
                        'Save Journal',
                        style: GoogleFonts.nunito(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.purple,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: softCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.sentiment_satisfied_rounded,
                        size: 18,
                        color: AppColors.ink,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Yesterday's Insights",
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _openInsightsMenu,
                    child: const Icon(
                      Icons.more_horiz_rounded,
                      color: AppColors.purple,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Latest entry',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              if (_latestEntry != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  _formatDate(_latestEntry!.day),
                                  style: GoogleFonts.nunito(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.purple,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _latestEntry == null
                                ? 'No past entries yet — write your first one above!'
                                : _latestEntry!.entryText.isEmpty
                                ? '(empty entry)'
                                : _latestEntry!.entryText,
                            style: GoogleFonts.nunito(
                              fontSize: 11.5,
                              color: AppColors.sub,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDEBFB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.purple,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
