import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import 'auth_widgets.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
const LoginScreen({super.key});
@override
State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
final _formKey = GlobalKey<FormState>();
final _email = TextEditingController();
final _password = TextEditingController();
bool _loading = false;
String? _error;

@override
void dispose() {
_email.dispose();
_password.dispose();
super.dispose();
}

Future<void> _submit() async {
  debugPrint('🔵 [Login] Button tapped, _loading=$_loading');

  if (!_formKey.currentState!.validate()) {
    debugPrint('🔴 [Login] Form validation failed');
    return;
  }

  debugPrint('🔵 [Login] Validation passed, calling signInWithPassword...');
  setState(() {
    _loading = true;
    _error = null;
  });
  try {
    await Supabase.instance.client.auth.signInWithPassword(
      email: _email.text.trim(),
      password: _password.text,
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('signInWithPassword timed out'),
    );
    debugPrint('✅ [Login] signInWithPassword succeeded');
  } on AuthException catch (e) {
    debugPrint('🔴 [Login] AuthException: ${e.message}');
    if (!mounted) return;
    setState(() => _error = e.message);
  } catch (e) {
    debugPrint('🔴 [Login] Unexpected error: $e');
    if (!mounted) return;
    setState(() => _error = 'Something went wrong. Please try again.');
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}

@override
Widget build(BuildContext context) {
return AuthScaffold(
title: 'Welcome Back',
showBack: false,
child: Form(
key: _formKey,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const AuthBrandMark(),
const SizedBox(height: 20),
Text('Welcome Back', style: AppText.headline()),
const SizedBox(height: 4),
Text("Let's get you back to your streak!", style: AppText.body()),
const SizedBox(height: 28),
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
hint: 'Enter your password',
controller: _password,
obscure: true,
prefixIcon: Icons.lock_outline_rounded,
validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
),
const SizedBox(height: 10),
Align(
alignment: Alignment.centerRight,
child: GestureDetector(
onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
child: Text('Forgot Password?', style: AppText.body(size: 12.5, weight: FontWeight.w800, color: AppColors.purple)),
),
),
if (_error != null) ...[
const SizedBox(height: 8),
Text(_error!, style: AppText.body(size: 12.5, color: AppColors.error, weight: FontWeight.w700)),
],
const SizedBox(height: 20),
AuthPrimaryButton(label: 'Log In', onPressed: _submit, loading: _loading),
const SizedBox(height: 20),
Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Text("Don't have an account? ", style: AppText.body(size: 13)),
GestureDetector(
onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen())),
child: Text('Sign Up', style: AppText.body(size: 13, weight: FontWeight.w900, color: AppColors.purple)),
),
],
),
],
),
),
);
}
}