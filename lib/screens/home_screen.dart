import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'streak_progress_screen.dart';
import '../service/home_service.dart';
import '../service/profile_store.dart';
import '../service/app_events.dart';
import '../shared_widgets.dart' hide AppColors;

class FlameLogo extends StatelessWidget {
  final double size;
  final String assetPath;
  const FlameLogo({
    super.key,
    this.size = 76.0,
    this.assetPath = 'assets/streak_logo.png',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFFFF0EC),
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final ValueChanged<int> onNavigateToTab;

  const HomeScreen({
    super.key,
    required this.onNavigateToTab,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> {
  final _homeService = HomeService();

  final _profileStore = ProfileStore.instance;

  HomeData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    AppEvents.tasks.addListener(_sharedDataChanged);
    AppEvents.journal.addListener(_sharedDataChanged);
    AppEvents.progress.addListener(_sharedDataChanged);

    _profileStore.addListener(_profileChanged);

    _load();
  }

  @override
  void dispose() {
    AppEvents.tasks.removeListener(_sharedDataChanged);
    AppEvents.journal.removeListener(_sharedDataChanged);
    AppEvents.progress.removeListener(_sharedDataChanged);
    _profileStore.removeListener(_profileChanged);

    super.dispose();
  }

  void _sharedDataChanged() {
    if (!mounted) return;
    _load();
  }

  void _profileChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _load() async {
    if (mounted && _data == null) {
      setState(() => _loading = true);
    }

    try {
      await _profileStore.refresh();

      final data =
      await _homeService.fetchHomeData();

      if (!mounted) return;

      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load home data: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ProfileStore.instance,
      builder: (context, _) {
        if (_loading || _data == null) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.purple,
            ),
          );
        }

        final baseData = _data!;

        final liveProfile =
            ProfileStore.instance.profile;

        final data = liveProfile == null
            ? baseData
            : HomeData(
          fullName: liveProfile.fullName,
          avatarPath:
          liveProfile.avatarPath,
          currentStreak:
          baseData.currentStreak,
          totalXp:
          liveProfile.xp,
          daysCompletedThisWeek:
          baseData.daysCompletedThisWeek,
          journalDoneToday:
          baseData.journalDoneToday,
          moodSetToday:
          baseData.moodSetToday,
          upcomingTaskTitle:
          baseData.upcomingTaskTitle,
          upcomingTaskCategory:
          baseData.upcomingTaskCategory,
          weekdayCompletion:
          baseData.weekdayCompletion,
        );

        return RefreshIndicator(
          onRefresh: _load,
          color: AppColors.purple,
          child: SingleChildScrollView(
            physics:
            const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const AppTopBar(showMenu: true),
                const SizedBox(height: 16),

                Text(
                  'Hi, ${data.fullName}',
                  style: AppText.headline(size: 28),
                ),

                const SizedBox(height: 2),

                Text(
                  "Let's make today amazing!",
                  style: AppText.body(
                    size: 14,
                    weight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 20),

                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                        const StreakProgressScreen(),
                      ),
                    ).then((_) => _load());
                  },
                  child: _buildStreakCard(data),
                ),

                const SizedBox(height: 16),

                GestureDetector(
                  onTap: () =>
                      widget.onNavigateToTab(2),
                  child:
                  _buildTodayProgressCard(data),
                ),

                const SizedBox(height: 16),

                GestureDetector(
                  onTap: () =>
                      widget.onNavigateToTab(1),
                  child:
                  _buildUpcomingTaskCard(data),
                ),

                const SizedBox(height: 20),

                _buildWeeklyTrackerRow(data),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStreakCard(HomeData data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: appCard(radius: 28).copyWith(
        boxShadow: [
          BoxShadow(
            color:
            AppColors.purple.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const FlameLogo(
            size: 88,
            assetPath: 'assets/streak_logo.png',
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  '${data.currentStreak}',
                  style:
                  AppText.title(size: 48)
                      .copyWith(height: 1.0),
                ),
                Text(
                  'DAY STREAK',
                  style: AppText.body(
                    size: 13,
                    weight: FontWeight.w800,
                  ).copyWith(letterSpacing: 0.5),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.lightPurple,
                    borderRadius:
                    BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.emoji_events_outlined,
                        size: 15,
                        color: AppColors.purple,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${data.totalXp} Xp',
                        style: AppText.body(
                          size: 12,
                          weight: FontWeight.w800,
                          color: AppColors.purple,
                        ),
                      ),
                      Text(
                        '  |  This week',
                        style: AppText.body(
                          size: 11,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayProgressCard(HomeData data) {
    final now = DateTime.now();

    final dayLabel =
        '${now.day} ${_monthName(now.month)}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: appCard(radius: 28),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
      RichText(
      text: TextSpan(
      style: AppText.body(
        size: 18,
        weight: FontWeight.w800,
        color: AppColors.ink,
      ),
      children: [
        const TextSpan(
          text: 'Today, ',
        ),
        TextSpan(
          text: dayLabel,
          style: AppText.body(
            size: 18,
            weight: FontWeight.w900,
            color: AppColors.ink,
          ).copyWith(
            decoration:
            TextDecoration.underline,
          ),
        ),
      ],
    ),
    ),
    const SizedBox(height: 16),
    Row(
    children: [
    SizedBox(
    width: 76,
    height: 76,
    child: Stack(
    alignment: Alignment.center,
    children: [
    SizedBox(
    width: 76,
    height: 76,
    child:
    CircularProgressIndicator(
    value:
    (data.daysCompletedThisWeek /
    7)
        .clamp(0, 1),
    strokeWidth: 9,
    backgroundColor:
    AppColors.lightPurple,
      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.purple),
    strokeCap:
    StrokeCap.round,
    ),
    ),
    Text(
    '${data.daysCompletedThisWeek}/7',
    style:
    AppText.title(size: 18),
    ),
    ],
    ),
    ),
    const SizedBox(width: 20),
    Container(
    width: 1,
    height: 50,
    color: AppColors.cardBorder,
    ),
    const SizedBox(width: 20),
    Expanded(
    child: Column(
    children: [
    Row(
    mainAxisAlignment:
    MainAxisAlignment.spaceBetween,
    children: [
    Text(
    'Journal',
    style:
    AppText.title(size: 16),
    ),
    Icon(
    data.journalDoneToday
    ? Icons
        .check_circle_rounded
        : Icons
        .check_circle_outline_rounded,
    color:
    AppColors.purple,
    size: 24,
    ),
    ],
    ),
    const SizedBox(height: 12),
    Row(
    mainAxisAlignment:
    MainAxisAlignment.spaceBetween,
    children: [
    Text(
    'Mood',
    style:
    AppText.title(size: 16),
    ),
    Icon(
    data.moodSetToday
    ? Icons
        .sentiment_satisfied_alt_rounded
        : Icons
        .sentiment_neutral_rounded,
    color:
    AppColors.purple,
    size: 24,
    ),
    ],
    ),
    ],
    ),
    ),
    ],
    ),
    ],
    ),
    );
    }

  Widget _buildUpcomingTaskCard(HomeData data) {
    final hasTask =
        data.upcomingTaskTitle != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: appCard(radius: 28),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.lightPurple,
                  borderRadius:
                  BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: AppColors.purple,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Upcoming task',
                style:
                AppText.title(size: 16),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color:
              AppColors.lightPurple.withOpacity(
                0.4,
              ),
              borderRadius:
              BorderRadius.circular(18),
            ),
            child: hasTask
                ? Row(
              children: [
                const Icon(
                  Icons
                      .radio_button_unchecked_rounded,
                  color: AppColors.sub,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.upcomingTaskTitle!,
                        style: AppText.body(
                          size: 14,
                          weight:
                          FontWeight.w800,
                          color:
                          AppColors.ink,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.menu_book_rounded,
                            size: 13,
                            color:
                            AppColors.purple,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            data.upcomingTaskCategory ??
                                'Personal',
                            style: AppText.body(
                              size: 12,
                              weight:
                              FontWeight.w700,
                              color:
                              AppColors.purple,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.sub,
                  size: 22,
                ),
              ],
            )
                : Text(
              'No pending tasks ? nice work! ?',
              style: AppText.body(
                size: 13,
                weight: FontWeight.w700,
                color: AppColors.sub,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyTrackerRow(HomeData data) {
    final today = DateTime.now();

    const labels = [
      'M',
      'T',
      'W',
      'Th',
      'F',
      'Sa',
      'S',
    ];

    return Row(
      mainAxisAlignment:
      MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final weekdayNum = i + 1;

        final isPast =
            weekdayNum < today.weekday;

        final isToday =
            weekdayNum == today.weekday;

        final completed =
            data.weekdayCompletion[weekdayNum] ??
                false;

        Color bg;
        Color iconColor;
        String iconType;

        if (completed) {
          bg = const Color(0xFFE9F8EE);
          iconColor = AppColors.success;
          iconType = 'dot';
        } else if (isPast) {
          bg = const Color(0xFFFCEAEB);
          iconColor = AppColors.error;
          iconType = 'minus';
        } else if (isToday) {
          bg = const Color(0xFFFFF7E5);
          iconColor =
          const Color(0xFFF2C94C);
          iconType = 'dot';
        } else {
          bg = AppColors.lightPurple;
          iconColor = AppColors.purple;
          iconType = 'circle';
        }

        return _buildDayCapsule(
          labels[i],
          bg,
          iconColor,
          iconType: iconType,
        );
      }),
    );
  }

  Widget _buildDayCapsule(
      String day,
      Color bgColor,
      Color iconColor, {
        required String iconType,
      }) {
    return Container(
      width: 42,
      padding:
      const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius:
        BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            day,
            style: AppText.body(
              size: 14,
              weight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          if (iconType == 'dot')
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
            )
          else if (iconType == 'minus')
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.remove,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            )
          else
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: iconColor,
                  width: 2,
                ),
              ),
            ),
        ],
      ),
    );
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
}