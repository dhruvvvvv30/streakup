import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import 'main_wrapper.dart'; // adjust path if needed

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSaving = false;

  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _aboutController = TextEditingController();
  final _goalsController = TextEditingController();
  final _motivationController = TextEditingController();
  DateTime? _dob;

  String _gender = 'male';
  int _selectedAvatarIndex = 0;

  final List<String> _maleAvatars = List.generate(6, (i) => 'assets/avatars/M${i + 1}.png');
  final List<String> _femaleAvatars = List.generate(6, (i) => 'assets/avatars/F${i + 1}.png');

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _aboutController.dispose();
    _goalsController.dispose();
    _motivationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _completeProfile();
    }
  }

  void _prevPage() async {
    if (_currentPage > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      // No screen to pop back to — this is the first step, so back
      // means "cancel and return to login," not navigate within the app.
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancel profile setup?'),
          content: const Text("You'll need to log in again to continue setting up your profile."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
          ],
        ),
      );
      if (confirm == true) {
        await Supabase.instance.client.auth.signOut();
        // No manual navigation needed — AuthGate reacts to the sign-out
        // and shows LoginScreen automatically.
      }
    }
  }
  Future<void> _pickDob() async {
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
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _completeProfile() async {
    if (_fullNameController.text.trim().isEmpty || _usernameController.text.trim().isEmpty) {
      _showSnack('Please fill in your name and username before continuing.');
      _pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    debugPrint('🔵 [Profile] currentUser id: $userId');
    debugPrint('🔵 [Profile] session: ${Supabase.instance.client.auth.currentSession}');

    if (userId == null) {
      _showSnack('No logged-in user found. Please register again.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final avatarPath = _gender == 'male'
          ? _maleAvatars[_selectedAvatarIndex]
          : _femaleAvatars[_selectedAvatarIndex];

      debugPrint('🔵 [Profile] Starting upsert...');

      await Supabase.instance.client.from('profiles').upsert({
        'id': userId,
        'full_name': _fullNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'date_of_birth': _dob?.toIso8601String(),
        'gender': _gender,
        'avatar_path': avatarPath,
        'about': _aboutController.text.trim(),
        'goals': _goalsController.text.trim(),
        'motivation': _motivationController.text.trim(),
        'profile_completed': true,
      }).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Upsert timed out after 10s — likely network or RLS issue'),
      );

      debugPrint('✅ [Profile] Upsert succeeded');

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainWrapper()),
            (route) => false,
      );
    } on PostgrestException catch (e) {
      debugPrint('🔴 [Profile] PostgrestException: ${e.message} | code: ${e.code} | details: ${e.details}');
      _showSnack('Could not save profile: ${e.message}');
    } catch (e) {
      debugPrint('🔴 [Profile] Unexpected error: $e');
      _showSnack('Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _prevPage,
                    child: const Icon(Icons.arrow_back, color: AppColors.purple, size: 28),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text('Create Your Profile', style: AppText.title(size: 20)),
                        const SizedBox(height: 4),
                        Text("Let's build your StreakUp identity", style: AppText.body(size: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 28),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildProgressBar(),
            const SizedBox(height: 24),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildStep1BasicInfo(),
                  _buildStep2GenderAvatar(),
                  _buildStep3AboutYou(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.purple,
                        disabledBackgroundColor: AppColors.purple.withOpacity(0.6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                      )
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_currentPage == 2 ? 'Complete Profile' : 'Continue', style: AppText.button()),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                        ],
                      ),
                    ),
                  ),
                  if (_currentPage > 0) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _isSaving ? null : _prevPage,
                      child: Text('Back', style: AppText.body(size: 15, weight: FontWeight.w900, color: AppColors.purple)),
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildProgressNode(1, 'Basic Info', 0),
          _buildProgressLine(0),
          _buildProgressNode(2, 'Gender & Avatar', 1),
          _buildProgressLine(1),
          _buildProgressNode(3, 'About You', 2),
        ],
      ),
    );
  }

  Widget _buildProgressNode(int step, String label, int index) {
    bool isCompleted = _currentPage > index;
    bool isActive = _currentPage == index;
    return Column(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: isCompleted || isActive ? AppColors.purple : AppColors.white,
            border: Border.all(color: isCompleted || isActive ? AppColors.purple : AppColors.cardBorder, width: 2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text('$step', style: AppText.body(size: 14, weight: FontWeight.w800, color: isActive ? Colors.white : AppColors.sub)),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: AppText.body(size: 10, weight: FontWeight.w700, color: isActive ? AppColors.purple : AppColors.sub)),
      ],
    );
  }

  Widget _buildProgressLine(int index) {
    bool isCompleted = _currentPage > index;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 24, left: 8, right: 8),
        color: isCompleted ? AppColors.purple : AppColors.cardBorder,
      ),
    );
  }

  Widget _buildStep1BasicInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text("Let's start with the basics", style: AppText.title(size: 20)),
          const SizedBox(height: 4),
          Text('Fill in your basic information to get started.', style: AppText.body(size: 14)),
          const SizedBox(height: 32),
          _buildInputBox(icon: Icons.person_outline, label: 'Full Name', hint: 'Enter your full name', controller: _fullNameController),
          const SizedBox(height: 20),
          _buildInputBox(icon: Icons.alternate_email, label: 'Username', hint: 'Choose a username', controller: _usernameController),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _pickDob,
            child: AbsorbPointer(
              child: _buildInputBox(
                icon: Icons.calendar_today_outlined,
                label: 'Date of Birth',
                hint: _dob == null ? 'DD MMM YYYY' : '${_dob!.day}/${_dob!.month}/${_dob!.year}',
                controller: TextEditingController(text: _dob == null ? '' : '${_dob!.day}/${_dob!.month}/${_dob!.year}'),
                suffix: const Icon(Icons.keyboard_arrow_down, color: AppColors.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2GenderAvatar() {
    List<String> currentAvatars = _gender == 'male' ? _maleAvatars : _femaleAvatars;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text('Choose Your Gender', style: AppText.title(size: 20)),
          const SizedBox(height: 4),
          Text('This helps us show you avatars that suit you!', style: AppText.body(size: 14)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildGenderCard('male', Icons.male, 'Male', AppColors.purple)),
              const SizedBox(width: 16),
              Expanded(child: _buildGenderCard('female', Icons.female, 'Female', const Color(0xFFE8358B))),
            ],
          ),
          const SizedBox(height: 32),
          Text('Pick Your Avatar', style: AppText.title(size: 20)),
          const SizedBox(height: 4),
          Text('Select an avatar that represents you', style: AppText.body(size: 14)),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 16, mainAxisSpacing: 16),
            itemBuilder: (context, index) {
              bool isSelected = _selectedAvatarIndex == index;
              return GestureDetector(
                onTap: () => setState(() => _selectedAvatarIndex = index),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? (_gender == 'male' ? AppColors.purple : const Color(0xFFE8358B)) : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.lightPurple,
                    backgroundImage: AssetImage(currentAvatars[index]),
                    onBackgroundImageError: (_, __) {},
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          _buildTipCard('You can change your avatar anytime in settings.'),
        ],
      ),
    );
  }

  Widget _buildGenderCard(String value, IconData icon, String label, Color color) {
    bool isSelected = _gender == value;
    return GestureDetector(
      onTap: () => setState(() {
        _gender = value;
        _selectedAvatarIndex = 0;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: appCard(radius: 16).copyWith(
          border: Border.all(color: isSelected ? color : AppColors.cardBorder, width: 2),
          boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(label, style: AppText.body(size: 16, weight: FontWeight.w800, color: isSelected ? color : AppColors.sub)),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3AboutYou() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text('Tell us about you', style: AppText.title(size: 20)),
          const SizedBox(height: 4),
          Text('These are optional, but help us know you better!', style: AppText.body(size: 14)),
          const SizedBox(height: 32),
          _buildTextAreaBox(icon: Icons.person_outline, label: 'About You (Optional)', hint: 'E.g. I love fitness, enjoy late night walks and building cool things.', maxLength: 200, controller: _aboutController),
          const SizedBox(height: 20),
          _buildTextAreaBox(icon: Icons.track_changes_outlined, label: 'Primary Goals (Optional)', hint: 'E.g. Build a consistent workout streak, stay healthy, run a marathon.', maxLength: 150, controller: _goalsController),
          const SizedBox(height: 20),
          _buildTextAreaBox(icon: Icons.star_border_rounded, label: 'Motivation (Optional)', hint: 'E.g. To become the best version of myself and inspire others.', maxLength: 150, controller: _motivationController),
          const SizedBox(height: 24),
          _buildTipCard('You can update or add to these later in your profile settings.'),
        ],
      ),
    );
  }

  Widget _buildInputBox({required IconData icon, required String label, required String hint, required TextEditingController controller, Widget? suffix}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appCard(radius: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.lightPurple, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.purple, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.body(size: 12, weight: FontWeight.w800, color: AppColors.purple)),
                TextFormField(
                  controller: controller,
                  style: AppText.body(size: 16, weight: FontWeight.w600, color: AppColors.ink),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: AppText.body(size: 16, weight: FontWeight.w600, color: AppColors.ink),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          if (suffix != null) suffix,
        ],
      ),
    );
  }

  Widget _buildTextAreaBox({required IconData icon, required String label, required String hint, required int maxLength, required TextEditingController controller}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appCard(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.lightPurple, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: AppColors.purple, size: 18),
              ),
              const SizedBox(width: 12),
              Text(label, style: AppText.body(size: 14, weight: FontWeight.w800, color: AppColors.purple)),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller,
            maxLines: 2,
            maxLength: maxLength,
            style: AppText.body(size: 14, weight: FontWeight.w500, color: AppColors.ink),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppText.body(size: 14, weight: FontWeight.w500, color: AppColors.sub),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.lightPurple.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline, color: AppColors.sub, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppText.body(size: 12, weight: FontWeight.w600))),
        ],
      ),
    );
  }
}