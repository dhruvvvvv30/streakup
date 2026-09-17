import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_gate.dart';
import 'service/profile_store.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://dcuakwjmjzmnxktynzkz.supabase.co',
    anonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRjdWFrd2ptanptbnhrdHluemt6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc1OTU4MTIsImV4cCI6MjEwMzE3MTgxMn0.2ofpBfCIylxpyguic1Z-OSnu-D9bFuchh3F_v_mgNoQ',
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Keep the shared profile in step with the auth session.
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    switch (data.event) {
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.initialSession:
      case AuthChangeEvent.userUpdated:
        ProfileStore.instance.load();
        break;
      case AuthChangeEvent.signedOut:
        ProfileStore.instance.clear();
        break;
      default:
        break;
    }
  });

  if (Supabase.instance.client.auth.currentUser != null) {
    await ProfileStore.instance.load();
  }

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'StreakUp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C5DD3)),
        scaffoldBackgroundColor: Colors.transparent,
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}