import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_gate.dart';
import 'service/profile_store.dart';
import 'service/widget_service.dart';
import 'widgets/app_lifecycle_observer.dart';
import 'dart:async';
import '../service/supabase_config.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  await WidgetService.registerBackgroundCallback();
  await WidgetService.syncPendingToggles(); // catch up on anything missed while closed

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

  runApp(
    AppLifecycleObserver(
      child: const MyApp(),
    ),
  );
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