import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main.dart'; // <-- ADJUST: path to wherever main.dart lives relative to this file
import 'screens/main_wrapper.dart'; // <-- ADJUST: path to wherever MainWrapper lives
import 'screens/notifications_screen.dart'; // adjust path if your screens folder is elsewhere
import 'screens/profile_detail_screen.dart';
import '../service/profile_store.dart'; // <-- ADJUST: path to wherever ProfileStore lives

void showAddOptionsSheet(
  BuildContext context, {
  required VoidCallback onAddTask,
  required VoidCallback onAddJournal,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 48,
            height: 5,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFD6D3EE),
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Add Task
          _AddOptionCard(
            icon: Icons.description_outlined,
            badgeIcon: Icons.add,
            title: 'Add Task',
            onTap: () {
              Navigator.pop(context);
              onAddTask();
            },
          ),

          const SizedBox(height: 14),

          // Journal Entry
          _AddOptionCard(
            icon: Icons.auto_stories_outlined,
            badgeIcon: Icons.edit,
            title: 'Journal Entry',
            onTap: () {
              Navigator.pop(context);
              onAddJournal();
            },
          ),

          const SizedBox(height: 24),

          // Close button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFFEDEBFB),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: AppColors.purple,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AddOptionCard extends StatelessWidget {
  final IconData icon;
  final IconData badgeIcon;
  final String title;
  final VoidCallback onTap;

  const _AddOptionCard({
    required this.icon,
    required this.badgeIcon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.cardBorder, width: 1.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 32, color: AppColors.purple),
                Positioned(
                  right: -5,
                  bottom: -4,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppColors.purple,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(badgeIcon, size: 11, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppGradient {
  static const bg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFA9D6FF), Color(0xFFC9D9FF), Color(0xFFDDD2FF)],
  );
}

class AppColors {
  static const purple = Color(0xFF6C5DD3);
  static const ink = Color(0xFF1E1B3A);
  static const sub = Color(0xFF6F6C8C);
  static const cardBorder = Color(0xFFECEFFC);
  static const green = Color(0xFF4CAF7D);
  static const orange = Color(0xFFFF7A45);
  static const white = Colors.white; // NEW
  static const lightPurple = Color(0xFFEDEBFB);
}

BoxDecoration softCard({double radius = 22, Color? fill}) => BoxDecoration(
  color: fill ?? Colors.white.withValues(alpha: 0.85),
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: AppColors.cardBorder, width: 1.2),
  boxShadow: [
    BoxShadow(
      color: AppColors.purple.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ],
);

class GradientScaffold extends StatelessWidget {
  final Widget child;
  final Widget? bottomNavigationBar;
  final Widget? endDrawer;
  const GradientScaffold({
    super.key,
    required this.child,
    this.bottomNavigationBar,
    this.endDrawer,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      bottomNavigationBar: bottomNavigationBar,
      endDrawer: endDrawer,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppGradient.bg),
        child: SafeArea(child: child),
      ),
    );
  }
}

class AppTopBar extends StatelessWidget {
  final VoidCallback? onBack;

  /// Set true only on the homescreen: shows a hamburger icon that opens
  /// the end drawer instead of a back arrow that navigates home.
  final bool showMenu;

  const AppTopBar({super.key, this.onBack, this.showMenu = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Builder(
          builder: (innerContext) => _circleBtn(
            icon: showMenu ? Icons.menu_rounded : Icons.arrow_back_rounded,
            onTap:
                onBack ??
                (showMenu
                    ? () => Scaffold.of(innerContext).openEndDrawer()
                    : _goHome),
          ),
        ),
        Row(
          children: [
            _circleBtn(
              icon: Icons.notifications_none_rounded,
              badge: true,
              onTap: () => navigatorKey.currentState?.push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
            ),
            const SizedBox(width: 10),
            const _AppTopBarAvatar(),
          ],
        ),
      ],
    );
  }

  void _goHome() {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainWrapper()),
      (route) => false,
    );
  }

  Widget _circleBtn({
    required IconData icon,
    required VoidCallback onTap,
    bool badge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: softCard(
          radius: 14,
          fill: Colors.white.withValues(alpha: 0.9),
        ),
        child: Stack(
          children: [
            Center(child: Icon(icon, color: AppColors.ink, size: 20)),
            if (badge)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shows the user's actual chosen avatar (from ProfileStore) instead of a
/// hardcoded asset, and updates automatically if the user changes it.
class _AppTopBarAvatar extends StatelessWidget {
  const _AppTopBarAvatar();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ProfileStore.instance,
      builder: (context, _) {
        final avatarPath = ProfileStore.instance.profile?.avatarPath;
        return GestureDetector(
          onTap: () => navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => const ProfileDetailScreen()),
          ),
          child: ClipOval(
            child: Container(
              width: 44,
              height: 44,
              color: Colors.white,
              child: avatarPath != null
                  ? Image.asset(
                      avatarPath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.person_rounded,
                        color: AppColors.purple,
                        size: 26,
                      ),
                    )
                  : const Icon(
                      Icons.person_rounded,
                      color: AppColors.purple,
                      size: 26,
                    ),
            ),
          ),
        );
      },
    );
  }
}

class AppBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;
  const AppBottomNav({
    super.key,
    required this.index,
    required this.onTap,
    required this.onAdd,
  });

  static const _icons = [
    Icons.home_rounded,
    Icons.assignment_turned_in_rounded,
    null,
    Icons.menu_book_rounded,
    Icons.groups_rounded,
  ];
  static const _labels = ['Home', 'Tasks', '', 'Journal', 'Social'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (i) {
            if (i == 2) {
              return GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.purple, Color(0xFF8B7BE8)],
                    ),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              );
            }
            final navIdx = i < 2 ? i : i - 1;
            final active = index == navIdx;
            return GestureDetector(
              onTap: () => onTap(navIdx),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFEDEBFB) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _icons[i],
                      size: 21,
                      color: active ? AppColors.purple : AppColors.sub,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _labels[i],
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: active ? AppColors.purple : AppColors.sub,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
