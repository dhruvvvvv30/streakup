import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../service/profile_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _store = ProfileStore.instance;

  @override
  void initState() {
    super.initState();
    if (_store.profile == null) _store.load();
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirm == true) {
      await _store.signOut();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account and all your data. This can\'t be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    try {
      await _store.deleteAccount();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
      }
    }
  }

  Future<void> _editNameAndUsername(BuildContext context) async {
    final nameController = TextEditingController(text: _store.profile?.fullName ?? '');
    final usernameController = TextEditingController(text: _store.profile?.username ?? '');

    final status = await _store.usernameChangeStatus();

    if (!context.mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Edit profile', style: GoogleFonts.nunito(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: usernameController,
              enabled: status.canChange,
              decoration: InputDecoration(
                labelText: 'Username',
                helperText: status.canChange ? null : status.message,
                helperMaxLines: 2,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != true || !context.mounted) return;

    final newName = nameController.text.trim();
    final newUsername = usernameController.text.trim();
    if (newName.isEmpty) return;

    // Only send a username change if it's actually allowed and different.
    final usernameToSave = (status.canChange && newUsername != (_store.profile?.username ?? ''))
        ? newUsername
        : null;

    if (newUsername.isEmpty && status.canChange) return;

    try {
      await _store.updateProfile(fullName: newName, username: usernameToSave);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
    } on ProfileUpdateException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final newPasswordController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Change password', style: GoogleFonts.nunito(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newPasswordController,
                autofocus: true,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm new password'),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7)),
              onPressed: () {
                if (newPasswordController.text.length < 6) {
                  setDialogState(() => errorText = 'Password must be at least 6 characters.');
                  return;
                }
                if (newPasswordController.text != confirmController.text) {
                  setDialogState(() => errorText = 'Passwords don\'t match.');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result != true || !context.mounted) return;

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPasswordController.text),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated')),
        );
      }
    } on AuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update password: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final profile = _store.profile;
        final authUser = Supabase.instance.client.auth.currentUser;
        final email = authUser?.email ?? '';
        final phone = (authUser?.phone?.isNotEmpty == true) ? authUser!.phone! : '';

        return Scaffold(
          backgroundColor: const Color(0xFFF7F6FF),
          body: SafeArea(
            child: Column(
              children: [
                // Top App Bar / Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          height: 44,
                          width: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Color(0xFF1E1C3B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Settings',
                        style: GoogleFonts.nunito(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1E1C3B),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: (profile == null && _store.loading)
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C5CE7)))
                      : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section: Account Information
                        Text(
                          'Account Information',
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF6C5CE7),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFEFEFFE)),
                          ),
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: () => _editNameAndUsername(context),
                                child: _buildSettingRow(
                                  icon: Icons.person_outline_rounded,
                                  title: 'Username',
                                  value: profile?.username ?? 'Not set',
                                  showDivider: true,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _editNameAndUsername(context),
                                child: _buildSettingRow(
                                  icon: Icons.badge_outlined,
                                  title: 'Full Name',
                                  value: profile?.fullName ?? 'there',
                                  showDivider: true,
                                ),
                              ),
                              _buildSettingRow(
                                icon: Icons.mail_outline_rounded,
                                title: 'Email',
                                value: email.isEmpty ? 'Not set' : email,
                                showDivider: true,
                                showArrow: false,
                              ),
                              _buildSettingRow(
                                icon: Icons.phone_iphone_rounded,
                                title: 'Phone',
                                value: phone.isEmpty ? 'Not set' : phone,
                                showDivider: false,
                                showArrow: false,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Section: How you sign into your account
                        Text(
                          'How you sign into your account',
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF6C5CE7),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFEFEFFE)),
                          ),
                          child: GestureDetector(
                            onTap: () => _changePassword(context),
                            child: _buildSettingRow(
                              icon: Icons.lock_outline_rounded,
                              title: 'Password',
                              value: '',
                              showDivider: false,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Section: Account Management
                        Text(
                          'Account Management',
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF6C5CE7),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFEFEFFE)),
                          ),
                          child: GestureDetector(
                            onTap: () => _deleteAccount(context),
                            child: _buildSettingRow(
                              icon: Icons.delete_outline_rounded,
                              title: 'Delete Account',
                              value: '',
                              titleColor: const Color(0xFFEB5757),
                              iconColor: const Color(0xFFEB5757),
                              showDivider: false,
                              showArrow: true,
                              arrowColor: const Color(0xFFEB5757),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Log out Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton(
                            onPressed: () => _logout(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFEFEFFE)),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.logout_rounded,
                                  color: Color(0xFF6C5CE7),
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Log out',
                                  style: GoogleFonts.nunito(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF6C5CE7),
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
      },
    );
  }

  // Helper builder for individual list rows
  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    required String value,
    bool showDivider = false,
    Color titleColor = const Color(0xFF1E1C3B),
    Color iconColor = const Color(0xFF6C5CE7),
    bool showArrow = true,
    Color arrowColor = const Color(0xFF8B8C9E),
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor == const Color(0xFFEB5757)
                      ? const Color(0xFFFFEFEF)
                      : const Color(0xFFF1EFFF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
              ),
              if (value.isNotEmpty) ...[
                Text(
                  value,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8B8C9E),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (showArrow)
                Icon(
                  Icons.chevron_right_rounded,
                  color: arrowColor,
                  size: 22,
                ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFF7F6FF),
            indent: 16,
            endIndent: 16,
          ),
      ],
    );
  }
}