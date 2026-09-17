import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import 'auth_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _email.text.trim(),
         redirectTo: 'io.supabase.streakup://reset-password',
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _sent = true;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Forgot Password',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Forgot Password?', style: AppText.headline(size: 28)),
            const SizedBox(height: 4),
            Text(
              "No worries, we'll send you reset instructions.",
              style: AppText.body(),
            ),
            const SizedBox(height: 28),
            if (!_sent) ...[
              AuthTextField(
                label: 'Email',
                hint: 'you@example.com',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.mail_outline_rounded,
                validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: AppText.body(size: 12.5, color: AppColors.error, weight: FontWeight.w700)),
              ],
              const SizedBox(height: 24),
              AuthPrimaryButton(label: 'Send Reset Link', onPressed: _submit, loading: _loading),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: appCard(radius: 20),
                child: Column(
                  children: [
                    const Icon(Icons.mark_email_read_rounded, color: AppColors.purple, size: 40),
                    const SizedBox(height: 12),
                    Text('Check your inbox', style: AppText.title()),
                    const SizedBox(height: 6),
                    Text(
                      "We've sent password reset instructions to ${_email.text}",
                      textAlign: TextAlign.center,
                      style: AppText.body(size: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AuthSecondaryButton(
                label: 'Resend Email',
                icon: Icons.refresh_rounded,
                onPressed: () => setState(() => _sent = false),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.purple),
                      const SizedBox(width: 6),
                      Text('Back to Log In', style: AppText.body(size: 13, weight: FontWeight.w900, color: AppColors.purple)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}