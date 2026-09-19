import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'settings.dart'; // Ensure this matches your settings file name
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_detail_screen.dart';
import 'streak_progress_screen.dart';
import 'help_feedback_screen.dart';
import 'about_streakup_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;
  bool _darkStyleEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      width: MediaQuery.of(context).size.width * 0.85,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          bottomLeft: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 1. Header Section
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 16, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Avatar (Flame Logo)
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF0EC),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Image.asset(
                        'assets/streak_logo.png', // Replace with your exact asset path
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Name and View Profile Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, Hasit',
                          style: GoogleFonts.nunito(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF1E1C3B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context); // close the drawer first
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProfileDetailScreen(),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Text(
                                'View your profile',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF6C5CE7),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: Color(0xFF6C5CE7),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Close Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF6C5CE7),
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            // 2. Scrollable List of Options
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildDrawerItem(
                      icon: Icons.bar_chart_rounded,
                      title: 'Statistics',
                      subtitle: 'Badges, streaks, progress & more',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StreakProgressScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerSwitchItem(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications',
                      subtitle: 'Turn notifications on or off',
                      value: _notificationsEnabled,
                      onChanged: (val) =>
                          setState(() => _notificationsEnabled = val),
                    ),
                    _buildDrawerSwitchItem(
                      icon: Icons.dark_mode_outlined,
                      title: 'Dark Style',
                      subtitle: 'Switch between light and dark',
                      value: _darkStyleEnabled,
                      onChanged: (val) =>
                          setState(() => _darkStyleEnabled = val),
                    ),
                    _buildDrawerItem(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      subtitle: 'Account, privacy, security & language',
                      onTap: () {
                        // Close the drawer first, then navigate
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & Feedback',
                      subtitle: 'FAQs, report a problem, send feedback',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HelpFeedbackScreen(),
                          ),
                        );
                      },
                    ),

                    _buildDrawerItem(
                      icon: Icons.info_outline_rounded,
                      title: 'About StreakUp',
                      subtitle: 'App version, terms & privacy, credits',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AboutStreakUpScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // 3. Log Out Button
                    GestureDetector(
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Log out?'),
                            content: const Text(
                              'Are you sure you want to log out?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Log out'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await Supabase.instance.client.auth.signOut();
                          // No manual navigation needed — AuthGate's onAuthStateChange listener
                          // detects the sign-out and automatically shows LoginScreen.
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0F0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.logout_rounded,
                              color: Color(0xFFFF4D4D),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Log out',
                              style: GoogleFonts.nunito(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFFF4D4D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for standard rows with a chevron
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1EFFF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: const Color(0xFF6C5CE7), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E1C3B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8B8C9E),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF8B8C9E),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for rows with a toggle switch
  Widget _buildDrawerSwitchItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1EFFF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: const Color(0xFF6C5CE7), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E1C3B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8B8C9E),
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFF6C5CE7),
          ),
        ],
      ),
    );
  }
}
