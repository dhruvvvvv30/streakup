import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'calendar_widgets.dart';
import '../service/streak_service.dart';

class StreakProgressScreen extends StatefulWidget {
  const StreakProgressScreen({super.key});

  @override
  State<StreakProgressScreen> createState() => _StreakProgressScreenState();
}

class _StreakProgressScreenState extends State<StreakProgressScreen> {
  final _streakService = StreakService();
  StreakStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final stats = await _streakService.fetchStats();
      if (mounted) setState(() { _stats = stats; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load streak stats: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FF),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColorsSP.purple))
            : RefreshIndicator(
          onRefresh: _loadStats,
          color: AppColorsSP.purple,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(context),
                const SizedBox(height: 16),
                _buildProfileXpRow(_stats!),
                const SizedBox(height: 16),
                _streakBannerRow(_stats!),
                const SizedBox(height: 16),
                _sectionCard(
                  title: 'Streak Overview',
                  child: _statsRow([
                    _StatItem(Icons.local_fire_department_rounded, AppColorsSP.purple, '${_stats!.currentStreak}', 'Current Streak'),
                    _StatItem(Icons.emoji_events_rounded, const Color(0xFF3E9AE8), '${_stats!.longestStreak}', 'Longest Streak'),
                    _StatItem(Icons.event_available_rounded, const Color(0xFFE85878), '${_stats!.successRate.round()}%', 'Success Rate'),
                    _StatItem(Icons.check_circle_rounded, const Color(0xFF4CAF7D), '${_stats!.daysThisMonth}', 'Days This Month'),
                    _StatItem(Icons.star_rounded, const Color(0xFFB48CEA), '${_stats!.totalXp}', 'Total XP'),
                  ]),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  title: 'Streak Calendar',
                  child: const MonthlyStreakCalendar(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            if (Navigator.canPop(context)) Navigator.pop(context);
          },
          child: const Icon(Icons.arrow_back_rounded, color: AppColorsSP.purple, size: 26),
        ),
        const SizedBox(width: 14),
        Text(
          'Personal Progress',
          style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: AppColorsSP.ink),
        ),
      ],
    );
  }

  Widget _buildProfileXpRow(StreakStats stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          ClipOval(
            child: Container(
              width: 56,
              height: 56,
              color: AppColorsSP.purple.withOpacity(0.1),
              child: Image.asset(
                'assets/avatar.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: AppColorsSP.purple, size: 30),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stats.fullName, style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: AppColorsSP.ink)),
                Text(
                  'Small steps. Big progress. 💜',
                  style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColorsSP.sub),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFF1EFFF), borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events_rounded, color: AppColorsSP.purple, size: 20),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${stats.totalXp} Xp', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w900, color: AppColorsSP.ink)),
                    Text('Total XP', style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: AppColorsSP.sub)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _streakBannerRow(StreakStats stats) {
    final goalDays = ((stats.currentStreak ~/ 30) + 1) * 30;
    final daysToGo = goalDays - stats.currentStreak;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(color: Color(0xFFEDEBFB), shape: BoxShape.circle),
                    child: const Icon(Icons.local_fire_department_rounded, color: AppColorsSP.purple, size: 24),
                  ),
                  const SizedBox(height: 10),
                  Text('${stats.currentStreak}', style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w900, color: AppColorsSP.ink)),
                  Text('day streak!', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: AppColorsSP.ink)),
                  const SizedBox(height: 4),
                  Text(
                    stats.currentStreak > 0 ? 'Keep it going! 🔥' : 'Complete a task today to start!',
                    style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: AppColorsSP.sub),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
              child: _goalCard(
                'Reach a $goalDays-day streak',
                '$daysToGo days to go',
                goalDays == 0 ? 0.0 : stats.currentStreak / goalDays,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalCard(String title, String subtitle, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(color: Color(0xFFEDEBFB), shape: BoxShape.circle),
          child: const Icon(Icons.track_changes_rounded, color: AppColorsSP.purple, size: 18),
        ),
        const SizedBox(height: 10),
        Text(title, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: AppColorsSP.ink)),
        const SizedBox(height: 2),
        Text(subtitle, style: GoogleFonts.nunito(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColorsSP.sub)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 7,
            backgroundColor: const Color(0xFFE2DDFE),
            valueColor: const AlwaysStoppedAnimation(AppColorsSP.purple),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({required String title, Widget? trailing, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: AppColorsSP.ink)),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _statsRow(List<_StatItem> items) {
    return Row(
      children: items.map((s) {
        return Expanded(
          child: Column(
            children: [
              Icon(s.icon, color: s.color, size: 22),
              const SizedBox(height: 8),
              Text(s.value, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w900, color: AppColorsSP.ink)),
              const SizedBox(height: 2),
              Text(s.label, textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColorsSP.sub)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StatItem {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  _StatItem(this.icon, this.color, this.value, this.label);
}

class AppColorsSP {
  static const purple = Color(0xFF6C5CE7);
  static const ink = Color(0xFF1E1C3B);
  static const sub = Color(0xFF8B8C9E);
}