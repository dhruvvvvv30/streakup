import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import 'auth_widgets.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
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
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _password.text),
      );
      if (!mounted) return;

      // Sign out of the temporary recovery session so the user
      // logs back in fresh with their new password.
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
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
      title: 'Reset Password',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Set New Password', style: AppText.headline(size: 28)),
            const SizedBox(height: 4),
            Text('Your new password must be different from previous ones.', style: AppText.body()),
            const SizedBox(height: 28),
            AuthTextField(
              label: 'New Password',
              hint: 'Enter new password',
              controller: _password,
              obscure: true,
              prefixIcon: Icons.lock_outline_rounded,
              validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              label: 'Confirm New Password',
              hint: 'Re-enter new password',
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
            AuthPrimaryButton(label: 'Reset Password', onPressed: _submit, loading: _loading),
          ],
        ),
      ),
    );
  }
}