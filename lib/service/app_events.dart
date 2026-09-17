import 'package:flutter/foundation.dart';

/// Tiny app-wide event bus.
///
/// A screen that changes shared data calls the matching `emit`; screens
/// that display that data listen and reload. Cheaper than giving every
/// screen its own realtime subscription, and it fires instantly on the
/// device that made the change.
class AppEvents {
  AppEvents._();

  /// Tasks created, completed, uncompleted, or deleted.
  static final tasks = ChangeNotifier_();

  /// Journal entries created, edited, or deleted.
  static final journal = ChangeNotifier_();

  /// XP or streak changed.
  static final progress = ChangeNotifier_();

  /// Group created, joined, left, or membership changed.
  static final groups = ChangeNotifier_();

  /// A notification arrived or was read/dismissed.
  static final notifications = ChangeNotifier_();
}

/// A ChangeNotifier whose only job is to be poked.
class ChangeNotifier_ extends ChangeNotifier {
  void emit() => notifyListeners();
}