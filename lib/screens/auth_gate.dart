import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main_wrapper.dart';
import 'create_profile_screen.dart';
import 'auth/login_screen.dart';
import 'auth/reset_password_screen.dart';
import '../main.dart'; // for navigatorKey

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Session? _session = Supabase.instance.client.auth.currentSession;

  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
        );
        return;
      }
      if (mounted) {
        setState(() => _session = data.session);
      }
    });
  }

  Future<bool> _isProfileComplete(String userId) async {
    try {
      debugPrint('🔵 [AuthGate] Checking profile for $userId');
      final row = await Supabase.instance.client
          .from('profiles')
          .select('profile_completed')
          .eq('id', userId)
          .maybeSingle()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Profile check timed out'),
      );
      debugPrint('🟢 [AuthGate] Result: $row');
      return row?['profile_completed'] == true;
    } catch (e) {
      debugPrint('🔴 [AuthGate] Error checking profile: $e');
      return false; // fail safe — send them to CreateProfileScreen rather than hang
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) return const LoginScreen();

    // Session exists — check whether onboarding is done before deciding where to send them.
    return FutureBuilder<bool>(
      future: _isProfileComplete(_session!.user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final completed = snapshot.data ?? false;
        return completed ? const MainWrapper() : const CreateProfileScreen();
      },
    );
  }
}