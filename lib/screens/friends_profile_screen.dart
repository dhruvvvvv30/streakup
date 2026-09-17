import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shared_widgets.dart';
import '../service/friend_service.dart';
import '../service/streak_service.dart';

class FriendProfileScreen extends StatefulWidget {
  final String friendUserId;
  const FriendProfileScreen({super.key, required this.friendUserId});

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  final _friendService = FriendService();
  StreakStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final stats = await _friendService.fetchFriendStats(widget.friendUserId);
      if (mounted) setState(() { _stats = stats; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(Icons.arrow_back_rounded, color: AppColors.purple, size: 26),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator(color: AppColors.purple)),
              )
            else if (_stats == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: Text("Couldn't load this profile", style: GoogleFonts.nunito(color: AppColors.sub, fontWeight: FontWeight.w700)),
                ),
              )
            else ...[
                _buildHeader(_stats!),
                const SizedBox(height: 16),
                _buildStatsCard(_stats!),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(StreakStats stats) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 34,
          backgroundColor: Color(0xFFEDEBFB),
          child: Icon(Icons.person_rounded, color: AppColors.purple, size: 34),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(stats.fullName, style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink)),
        ),
      ],
    );
  }

  Widget _buildStatsCard(StreakStats stats) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: softCard(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Streak & Stats', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.ink)),
          const SizedBox(height: 14),
          Row(
            children: [
              _stat(Icons.local_fire_department_rounded, AppColors.purple, '${stats.currentStreak}', 'Current Streak'),
              _stat(Icons.emoji_events_rounded, const Color(0xFF3E9AE8), '${stats.longestStreak}', 'Longest Streak'),
              _stat(Icons.event_available_rounded, const Color(0xFFE85878), '${stats.successRate.round()}%', 'Success Rate'),
              _stat(Icons.star_rounded, const Color(0xFFB48CEA), '${stats.totalXp}', 'Total XP'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, Color color, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.ink)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.sub)),
        ],
      ),
    );
  }
}