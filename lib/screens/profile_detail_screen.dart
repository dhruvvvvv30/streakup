import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shared_widgets.dart';
import 'settings.dart';
import 'streak_progress_screen.dart';
import '../service/profile_service.dart';

class ProfileDetailScreen extends StatefulWidget {
  const ProfileDetailScreen({super.key});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  final _profileService = ProfileService();
  ProfileDetailData? _data;
  bool _loading = true;

  static final List<String> _maleAvatars = List.generate(6, (i) => 'assets/avatars/male_${i + 1}.png');
  static final List<String> _femaleAvatars = List.generate(6, (i) => 'assets/avatars/female_${i + 1}.png');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _profileService.fetchProfileDetail();
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    }
  }

  Future<void> _editNameUsername() async {
    final nameController = TextEditingController(text: _data?.fullName);
    final usernameController = TextEditingController(text: _data?.username);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Edit Profile', style: GoogleFonts.nunito(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name')),
            const SizedBox(height: 12),
            TextField(controller: usernameController, decoration: const InputDecoration(labelText: 'Username')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.purple),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (saved == true) {
      try {
        await _profileService.updateNameUsername(
          nameController.text.trim(),
          usernameController.text.trim(),
        );
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
        }
      }
    }
  }

  Future<void> _editBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2005, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.purple)),
        child: child!,
      ),
    );
    if (picked != null) {
      try {
        await _profileService.updateBirthday(picked);
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
        }
      }
    }
  }

  Future<void> _pickAvatar() async {
    String gender = 'male';
    int selectedIndex = 0;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final avatars = gender == 'male' ? _maleAvatars : _femaleAvatars;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Choose Avatar', style: GoogleFonts.nunito(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Male'),
                        selected: gender == 'male',
                        onSelected: (_) => setSheetState(() { gender = 'male'; selectedIndex = 0; }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Female'),
                        selected: gender == 'female',
                        onSelected: (_) => setSheetState(() { gender = 'female'; selectedIndex = 0; }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: avatars.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 16, mainAxisSpacing: 16,
                  ),
                  itemBuilder: (context, index) {
                    final selected = selectedIndex == index;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedIndex = index),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: selected ? AppColors.purple : Colors.transparent, width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: AppColors.lightPurple,
                          backgroundImage: AssetImage(avatars[index]),
                          onBackgroundImageError: (_, __) {},
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.purple, padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await _profileService.updateAvatar(avatars[selectedIndex], gender);
                        _load();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
                        }
                      }
                    },
                    child: const Text('Save', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back_rounded, color: AppColors.purple, size: 26),
                ),
                Text('Profile', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink)),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                  child: const Icon(Icons.settings_outlined, color: AppColors.purple, size: 26),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading || _data == null
                ? const Center(child: CircularProgressIndicator(color: AppColors.purple))
                : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.purple,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  children: [
                    _buildHeaderCard(_data!),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      icon: Icons.person_outline_rounded,
                      title: 'Avatar',
                      subtitle: 'Choose your avatar',
                      trailing: _avatarThumbnails(_data!),
                      onTap: _pickAvatar,
                    ),
                    _buildInfoRow(
                      icon: Icons.person_outline_rounded,
                      title: 'Name',
                      subtitle: _data!.fullName,
                      onTap: _editNameUsername,
                    ),
                    _buildInfoRow(
                      icon: Icons.alternate_email_rounded,
                      title: 'Username',
                      subtitle: _data!.username.isNotEmpty ? '@${_data!.username}' : 'Not set',
                      onTap: _editNameUsername,
                    ),
                    _buildInfoRow(
                      icon: Icons.calendar_today_rounded,
                      title: 'Birthday',
                      subtitle: _data!.birthdayFormatted ?? 'Not set',
                      onTap: _editBirthday,
                    ),
                    const SizedBox(height: 4),
                    _buildStatsRow(_data!),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      icon: Icons.bar_chart_rounded,
                      title: 'Habit Stats',
                      subtitle: 'View your habit trends and insights',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StreakProgressScreen())),
                    ),
                    _buildInfoRow(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      subtitle: 'Notifications, privacy and more',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(ProfileDetailData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: softCard(radius: 22),
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickAvatar,
            child: Stack(
              children: [
                ClipOval(
                  child: Container(
                    width: 68,
                    height: 68,
                    color: AppColors.purple.withOpacity(0.1),
                    child: data.avatarPath != null
                        ? Image.asset(data.avatarPath!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: AppColors.purple, size: 36))
                        : const Icon(Icons.person_rounded, color: AppColors.purple, size: 36),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(color: AppColors.purple, shape: BoxShape.circle),
                    child: const Icon(Icons.edit_rounded, size: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.fullName, style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink)),
                Text(
                  data.username.isNotEmpty ? '@${data.username}' : '',
                  style: GoogleFonts.nunito(fontSize: 13, color: AppColors.sub, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  data.tagline,
                  style: GoogleFonts.nunito(fontSize: 12.5, color: AppColors.sub, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _editNameUsername,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFEDEBFB), borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  const Icon(Icons.edit_outlined, size: 15, color: AppColors.purple),
                  const SizedBox(width: 6),
                  Text('Edit Profile', style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.purple)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarThumbnails(ProfileDetailData data) {
    return ClipOval(
      child: Container(
        width: 32,
        height: 32,
        color: AppColors.lightPurple,
        child: data.avatarPath != null
            ? Image.asset(data.avatarPath!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, size: 18, color: AppColors.sub))
            : const Icon(Icons.person_rounded, size: 18, color: AppColors.sub),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: softCard(radius: 18),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: const Color(0xFFEDEBFB), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppColors.purple, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    Text(subtitle, style: GoogleFonts.nunito(fontSize: 12, color: AppColors.sub, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (trailing != null) trailing,
              if (trailing == null) const Icon(Icons.chevron_right_rounded, color: AppColors.sub, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(ProfileDetailData data) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: softCard(radius: 18, fill: const Color(0xFFEDEBFB).withOpacity(0.6)),
      child: Row(
        children: [
          Expanded(child: _stat(Icons.local_fire_department_rounded, '${data.currentStreak}', 'Day Streak')),
          Container(width: 1, height: 40, color: AppColors.cardBorder),
          Expanded(child: _stat(Icons.menu_book_rounded, '${data.totalJournalEntries}', 'Total Journal\nEntries')),
          Container(width: 1, height: 40, color: AppColors.cardBorder),
          Expanded(child: _stat(Icons.check_circle_outline_rounded, '${data.completedTasks}', 'Completed Tasks')),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.purple, size: 20),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink)),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 10.5, color: AppColors.sub, fontWeight: FontWeight.w700)),
      ],
    );
  }
}