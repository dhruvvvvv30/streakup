import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The logged-in user's profile, as stored in Supabase.
class UserProfile {
  final String id;
  final String fullName;
  final String? username;
  final DateTime? birthday;
  final String? avatarPath;
  final String about;
  final String goals;
  final String motivation;
  final int xp;
  final String? friendCode;
  final DateTime? usernameChangedAt;

  const UserProfile({
    required this.id,
    required this.fullName,
    this.username,
    this.birthday,
    this.avatarPath,
    this.about = '',
    this.goals = '',
    this.motivation = '',
    this.xp = 0,
    this.friendCode,
    this.usernameChangedAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    return UserProfile(
      id: map['id'] as String,
      fullName: (map['full_name'] as String?)?.trim().isNotEmpty == true
          ? map['full_name'] as String
          : (map['username'] as String?) ?? 'there',
      username: map['username'] as String?,
      birthday: parseDate(map['date_of_birth']),
      avatarPath: map['avatar_path'] as String?,
      about: map['about'] as String? ?? '',
      goals: map['goals'] as String? ?? '',
      motivation: map['motivation'] as String? ?? '',
      xp: (map['xp'] as int?) ?? 0,
      friendCode: map['friend_code'] as String?,
      usernameChangedAt: parseDate(map['username_changed_at']),
    );
  }
}

/// Result of asking the backend whether the username may be changed.
class UsernameChangeStatus {
  final bool canChange;
  final int daysRemaining;
  const UsernameChangeStatus(this.canChange, this.daysRemaining);

  String get message => canChange
      ? 'You can change your username now.'
      : 'Username can be changed again in $daysRemaining '
            '${daysRemaining == 1 ? 'day' : 'days'}.';
}

/// Global singleton. Listen to it with [AnimatedBuilder] or
/// [ListenableBuilder]; call [ProfileStore.instance.load] once at startup.
class ProfileStore extends ChangeNotifier {
  ProfileStore._();
  static final ProfileStore instance = ProfileStore._();

  final _supabase = Supabase.instance.client;
  String? get username => _profile?.username;
  UserProfile? _profile;
  bool _loading = false;
  RealtimeChannel? _channel;

  UserProfile? get profile => _profile;
  bool get loading => _loading;
  String get displayName => _profile?.fullName ?? 'there';
  String? get avatarPath => _profile?.avatarPath;
  int get xp => _profile?.xp ?? 0;

  // ------------------------------------------------------------------
  // Lifecycle
  // ------------------------------------------------------------------

  /// Loads the profile and opens a realtime subscription on this user's
  /// own profile row, so an XP change or avatar change anywhere in the
  /// app pushes to every listening screen.
  Future<void> load() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      clear();
      return;
    }

    _loading = true;
    notifyListeners();

    try {
      final result = await _supabase.rpc('get_my_profile');
      if (result != null) {
        _profile = UserProfile.fromMap(
          Map<String, dynamic>.from(result as Map),
        );
      }
    } catch (_) {
      // leave the previous profile in place rather than blanking the UI
    } finally {
      _loading = false;
      notifyListeners();
    }

    _subscribe(userId);
  }

  void _subscribe(String userId) {
    _channel?.unsubscribe();
    _channel = _supabase.channel('profile:$userId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'profiles',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: userId,
        ),
        callback: (payload) {
          final row = payload.newRecord;
          _profile = UserProfile.fromMap(Map<String, dynamic>.from(row));
          notifyListeners();
        },
      )
      ..subscribe();
  }

  /// Re-reads from the database. Use after an action that changed XP
  /// via an RPC, where the realtime event may not carry the full row.
  Future<void> refresh() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final result = await _supabase.rpc('get_my_profile');
      if (result != null) {
        _profile = UserProfile.fromMap(
          Map<String, dynamic>.from(result as Map),
        );
        notifyListeners();
      }
    } catch (_) {
      // non-fatal
    }
  }

  void clear() {
    _channel?.unsubscribe();
    _channel = null;
    _profile = null;
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Mutations
  // ------------------------------------------------------------------

  Future<UsernameChangeStatus> usernameChangeStatus() async {
    try {
      final result = await _supabase.rpc('username_change_status');
      final map = Map<String, dynamic>.from(result as Map);
      return UsernameChangeStatus(
        map['can_change'] as bool? ?? true,
        (map['days_remaining'] as int?) ?? 0,
      );
    } catch (_) {
      return const UsernameChangeStatus(true, 0);
    }
  }

  /// Saves any subset of fields. Pass null to leave a field untouched.
  /// Throws [ProfileUpdateException] with a user-readable message.
  Future<void> updateProfile({
    String? fullName,
    String? username,
    DateTime? birthday,
    String? avatarPath,
    String? about,
    String? goals,
    String? motivation,
  }) async {
    try {
      final result = await _supabase.rpc(
        'update_my_profile',
        params: {
          'p_full_name': fullName,
          'p_username': username,
          'p_birthday': birthday == null
              ? null
              : '${birthday.year.toString().padLeft(4, '0')}-'
                    '${birthday.month.toString().padLeft(2, '0')}-'
                    '${birthday.day.toString().padLeft(2, '0')}',
          'p_avatar': avatarPath,
          'p_about': about,
          'p_goals': goals,
          'p_motivation': motivation,
        },
      );

      if (result != null) {
        _profile = UserProfile.fromMap(
          Map<String, dynamic>.from(result as Map),
        );
        notifyListeners();
      }
    } on PostgrestException catch (e) {
      throw ProfileUpdateException(_readableError(e.message));
    } catch (e) {
      throw ProfileUpdateException('Could not save changes. Please try again.');
    }
  }

  String _readableError(String raw) {
    if (raw.contains('USERNAME_COOLDOWN')) {
      final match = RegExp(r'USERNAME_COOLDOWN:(\d+)').firstMatch(raw);
      final days = match == null ? null : int.tryParse(match.group(1)!);
      if (days != null) {
        return 'Username can be changed again in $days '
            '${days == 1 ? 'day' : 'days'}.';
      }
      return 'Username was changed recently. Try again in a few days.';
    }
    if (raw.contains('USERNAME_TAKEN') ||
        raw.contains('profiles_username_lower_idx') ||
        raw.contains('duplicate key')) {
      return 'That username is already taken.';
    }
    return 'Could not save changes. Please try again.';
  }

  // ------------------------------------------------------------------
  // Account actions
  // ------------------------------------------------------------------

  Future<void> signOut() async {
    clear();
    await _supabase.auth.signOut();
  }

  Future<void> deleteAccount() async {
    await _supabase.rpc('delete_my_account');
    clear();
    await _supabase.auth.signOut();
  }
}

class ProfileUpdateException implements Exception {
  final String message;
  ProfileUpdateException(this.message);
  @override
  String toString() => message;
}

/// Drop-in replacement for every hardcoded avatar icon in the app.
///
/// With no [avatarPath], shows the signed-in user's avatar and rebuilds
/// itself whenever that avatar changes. Pass [avatarPath] explicitly to
/// show somebody else's (a friend, a group member, a notification actor).
class UserAvatar extends StatelessWidget {
  final double size;
  final String? avatarPath;
  final bool isCurrentUser;
  final Color background;

  const UserAvatar({
    super.key,
    this.size = 44,
    this.avatarPath,
    this.isCurrentUser = false,
    this.background = const Color(0xFFEDEBFB),
  });

  /// The signed-in user's avatar, live-updating.
  const UserAvatar.me({
    super.key,
    this.size = 44,
    this.background = const Color(0xFFEDEBFB),
  }) : avatarPath = null,
       isCurrentUser = true;

  @override
  Widget build(BuildContext context) {
    if (isCurrentUser) {
      return ListenableBuilder(
        listenable: ProfileStore.instance,
        builder: (context, _) => _build(ProfileStore.instance.avatarPath),
      );
    }
    return _build(avatarPath);
  }

  Widget _build(String? path) {
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: background,
        child: (path == null || path.isEmpty)
            ? Icon(
                Icons.person_rounded,
                color: const Color(0xFF6C5DD3),
                size: size * 0.58,
              )
            : Image.asset(
                path,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.person_rounded,
                  color: const Color(0xFF6C5DD3),
                  size: size * 0.58,
                ),
              ),
      ),
    );
  }
}
