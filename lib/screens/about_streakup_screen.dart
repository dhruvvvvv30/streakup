import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AboutStreakUpScreen extends StatelessWidget {
  const AboutStreakUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E1C3B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'About StreakUp',
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1E1C3B),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
        child: Column(
          children: [
            // Logo + branding
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFF8B7CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/streak_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'StreakUp',
                    style: GoogleFonts.nunito(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Build habits. Build yourself.',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // What is StreakUp?
            _sectionTitle('What is StreakUp?'),

            const SizedBox(height: 8),

            Text(
              'StreakUp is a productivity and self-development app designed to help you stay consistent, build better habits, and keep track of your everyday progress.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6F7082),
                height: 1.5,
              ),
            ),

            const SizedBox(height: 26),

            // Features
            _sectionTitle('What you can do with StreakUp'),

            const SizedBox(height: 14),

            _featureCard(
              icon: Icons.check_circle_outline_rounded,
              title: 'Complete Tasks',
              subtitle: 'Stay organized and keep track of what you need to do.',
            ),

            _featureCard(
              icon: Icons.local_fire_department_rounded,
              title: 'Build Streaks',
              subtitle: 'Stay consistent and watch your progress grow.',
            ),

            _featureCard(
              icon: Icons.emoji_events_outlined,
              title: 'Earn Points',
              subtitle: 'Turn completed tasks into points and progress.',
            ),

            _featureCard(
              icon: Icons.groups_outlined,
              title: 'Compete With Friends',
              subtitle:
                  'Create groups and compare your progress on the leaderboard.',
            ),

            _featureCard(
              icon: Icons.menu_book_rounded,
              title: 'Reflect Through Journaling',
              subtitle:
                  'Take a moment to write about your day and reflect on your journey.',
            ),

            const SizedBox(height: 18),

            // Version
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1EFFF),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.phone_android_rounded,
                      color: Color(0xFF6C5CE7),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'App Version',
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E1C3B),
                      ),
                    ),
                  ),
                  Text(
                    'v1.0.0',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8B8C9E),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            Text(
              'Made with ❤️ by the StreakUp Team',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF8B8C9E),
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Stay consistent. Keep moving forward.',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFB0B0BE),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GoogleFonts.nunito(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF1E1C3B),
        ),
      ),
    );
  }

  Widget _featureCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFF1EFFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF6C5CE7), size: 23),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E1C3B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8B8C9E),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
