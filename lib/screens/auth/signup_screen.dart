import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import 'auth_widgets.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        data: {'full_name': _name.text.trim()},
      );
      if (!mounted) return;

      if (response.session == null) {
        // Email confirmation is ON — no session yet, AuthGate will show
        // LoginScreen on its own once this dialog closes.
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Check your email'),
            content: Text("We've sent a confirmation link to ${_email.text.trim()}. Please verify before logging in."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), // just close the dialog
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      // If response.session != null (confirmation OFF), do nothing here —
      // AuthGate detects the new session and routes to CreateProfileScreen
      // automatically since profile_completed is false for a brand-new user.
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create Account',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create Account', style: AppText.headline()),
            const SizedBox(height: 4),
            Text('Start your streak journey today!', style: AppText.body()),
            const SizedBox(height: 28),
            AuthTextField(
              label: 'Full Name',
              hint: 'Your name',
              controller: _name,
              prefixIcon: Icons.person_outline_rounded,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              label: 'Email',
              hint: 'you@example.com',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.mail_outline_rounded,
              validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              label: 'Password',
              hint: 'Create a password',
              controller: _password,
              obscure: true,
              prefixIcon: Icons.lock_outline_rounded,
              validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              label: 'Confirm Password',
              hint: 'Re-enter your password',
              controller: _confirm,
              obscure: true,
              prefixIcon: Icons.lock_outline_rounded,
              validator: (v) => v != _password.text ? "Passwords don't match" : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: AppText.body(size: 12.5, color: AppColors.error, weight: FontWeight.w700)),
            ],
            const SizedBox(height: 24),
            AuthPrimaryButton(label: 'Sign Up', onPressed: _submit, loading: _loading),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Already have an account? ', style: AppText.body(size: 13)),
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                  child: Text('Log In', style: AppText.body(size: 13, weight: FontWeight.w900, color: AppColors.purple)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}