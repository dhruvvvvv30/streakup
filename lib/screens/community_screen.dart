import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shared_widgets.dart';
import '../service/friend_service.dart';
import '../service/group_service.dart';
import 'friends_profile_screen.dart';
import 'add_friend_screen.dart';
import 'friend_request_screen.dart';
import 'leaderboard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../service/app_events.dart';

class CommunityScreenContent extends StatefulWidget {
  const CommunityScreenContent({super.key});

  @override
  State<CommunityScreenContent> createState() => _CommunityScreenContentState();
}

RealtimeChannel? _groupsChannel;
RealtimeChannel? _friendsChannel;

class _CommunityScreenContentState extends State<CommunityScreenContent> {
  bool _groupsTab = false;
  final _friendService = FriendService();
  final _groupService = GroupService();
  List<Friend> _friends = [];
  bool _loading = true;

  List<GroupModel> _groups = [];
  bool _groupsLoading = true;

  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _loadGroups();

    AppEvents.groups.addListener(_loadGroups);
    AppEvents.tasks.addListener(_loadGroups); // group streaks can shift when tasks complete
    _groupsChannel = _groupService.subscribeToMyGroups(_loadGroups);
    _friendsChannel = _friendService.subscribeToFriendChanges(_loadFriends);
  }

  @override
  void dispose() {
    AppEvents.groups.removeListener(_loadGroups);
    AppEvents.tasks.removeListener(_loadGroups);
    if (_groupsChannel != null) Supabase.instance.client.removeChannel(_groupsChannel!);
    if (_friendsChannel != null) Supabase.instance.client.removeChannel(_friendsChannel!);
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() => _loading = true);
    try {
      final friends = await _friendService.fetchFriends();
      if (mounted) setState(() { _friends = friends; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load friends: $e')),
        );
      }
    }
  }

  Future<void> _loadGroups() async {
    setState(() => _groupsLoading = true);
    try {
      final groups = await _groupService.fetchMyGroups();
      if (mounted) setState(() { _groups = groups; _groupsLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _groupsLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load groups: $e')),
        );
      }
    }
  }

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _friends.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(_friends.map((f) => f.id));
      }
    });
  }

  Future<void> _removeSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Remove friends?'),
        content: Text('Remove ${_selectedIds.length} friend(s)? This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    final idsToRemove = _selectedIds.toList();
    final removedFriends = _friends.where((f) => idsToRemove.contains(f.id)).toList();

    setState(() {
      _friends.removeWhere((f) => idsToRemove.contains(f.id));
      _selectMode = false;
      _selectedIds.clear();
    });

    try {
      await _friendService.removeFriends(idsToRemove);
    } catch (e) {
      setState(() => _friends.addAll(removedFriends));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove: $e')),
        );
      }
    }
  }

  Future<void> _openGroup(GroupModel g) async {
    List<GroupMemberStat> stats;
    try {
      stats = await _groupService.fetchLeaderboard(g.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load leaderboard: $e')),
        );
      }
      return;
    }

    if (!mounted) return;
    final left = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupDetailScreen(
          groupId: g.id,
          inviteCode: g.inviteCode,
          groupName: g.name,
          tagline: g.tagline,
          icon: iconForName(g.iconName),
          streak: g.streak,
          memberCount: g.memberCount,
          members: stats
              .map((s) => GroupMember(name: s.name, xp: s.xp, isYou: s.isYou))
              .toList(),
        ),
      ),
    );
    if (left == true) _loadGroups();
  }

  Future<void> _createGroupDialog() async {
    final nameController = TextEditingController();
    final taglineController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Create Group', style: GoogleFonts.nunito(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Group name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: taglineController,
              decoration: const InputDecoration(hintText: 'Tagline (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.purple),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != true || nameController.text.trim().isEmpty || !mounted) return;

    try {
      final group = await _groupService.createGroup(
        name: nameController.text.trim(),
        tagline: taglineController.text.trim(),
      );
      await _loadGroups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Group created! Invite code: ${group.inviteCode}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: $e')),
        );
      }
    }
  }

  Future<void> _joinGroupDialog() async {
    final codeController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Join via Code', style: GoogleFonts.nunito(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: codeController,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'Enter invite code'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.purple),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Join', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != true || codeController.text.trim().isEmpty || !mounted) return;

    try {
      final group = await _groupService.joinGroupByCode(codeController.text.trim());
      await _loadGroups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joined ${group.name}!')),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('ALREADY_MEMBER')
            ? 'You\'re already in this group'
            : e.toString().contains('Invalid code')
            ? 'Invalid invite code'
            : 'Failed to join: $e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        const AppTopBar(),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Community', style: GoogleFonts.schoolbell(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.ink)),
            Row(
              children: [
                if (!_groupsTab) ...[
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendRequestsScreen()));
                      _loadFriends();
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: softCard(radius: 12),
                      child: const Icon(Icons.mail_outline_rounded, size: 18, color: AppColors.purple),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _toggleSelectMode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: softCard(radius: 12),
                      child: Text(
                        _selectMode ? 'Cancel' : 'Select',
                        style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.purple),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddFriendScreen()));
                      _loadFriends();
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: softCard(radius: 12),
                      child: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: AppColors.purple),
                    ),
                  ),
                ] else
                  GestureDetector(
                    onTap: _createGroupDialog,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: softCard(radius: 12),
                      child: const Icon(Icons.add_rounded, size: 20, color: AppColors.purple),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _tabBtn('Groups', _groupsTab, () => setState(() { _groupsTab = true; _selectMode = false; _selectedIds.clear(); })),
            const SizedBox(width: 24),
            _tabBtn('Friends', !_groupsTab, () => setState(() => _groupsTab = false)),
          ],
        ),
        const SizedBox(height: 16),
        if (_selectMode) ...[
          Row(
            children: [
              GestureDetector(
                onTap: _toggleSelectAll,
                child: Row(
                  children: [
                    Icon(
                      _selectedIds.length == _friends.length && _friends.isNotEmpty
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      color: AppColors.purple,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text('Select all', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                  ],
                ),
              ),
              const Spacer(),
              if (_selectedIds.isNotEmpty)
                GestureDetector(
                  onTap: _removeSelected,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFFFE5E5), borderRadius: BorderRadius.circular(14)),
                    child: Text('Remove (${_selectedIds.length})', style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.red)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Container(
          padding: const EdgeInsets.all(16),
          decoration: softCard(),
          child: Column(
            children: _groupsTab ? _buildGroups() : _buildFriends(),
          ),
        ),
      ],
    );
  }

  Widget _tabBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: active ? AppColors.purple : AppColors.sub)),
          const SizedBox(height: 4),
          Container(height: 3, width: 40, color: active ? AppColors.purple : Colors.transparent),
        ],
      ),
    );
  }

  List<Widget> _buildFriends() {
    if (_loading) {
      return [const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: CircularProgressIndicator(color: AppColors.purple)))];
    }
    if (_friends.isEmpty) {
      return [Padding(padding: const EdgeInsets.symmetric(vertical: 30), child: Center(child: Text('No friends yet', style: GoogleFonts.nunito(color: AppColors.sub, fontWeight: FontWeight.w700))))];
    }

    return _friends.map((f) {
      final selected = _selectedIds.contains(f.id);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: GestureDetector(
          onTap: () {
            if (_selectMode) {
              setState(() {
                if (selected) {
                  _selectedIds.remove(f.id);
                } else {
                  _selectedIds.add(f.id);
                }
              });
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FriendProfileScreen(friendUserId: f.userId)),
              );
            }
          },
          child: Row(
            children: [
              if (_selectMode) ...[
                Icon(
                  selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  color: AppColors.purple,
                  size: 22,
                ),
                const SizedBox(width: 10),
              ],
              const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFFEDEBFB),
                child: Icon(Icons.person_rounded, color: AppColors.purple),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(f.fullName, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
              ),
              if (!_selectMode) const Icon(Icons.chevron_right_rounded, color: AppColors.purple),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildGroups() {
    if (_groupsLoading) {
      return [const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: CircularProgressIndicator(color: AppColors.purple)))];
    }

    return [
      if (_groups.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(child: Text('No groups yet — create or join one below', style: GoogleFonts.nunito(color: AppColors.sub, fontWeight: FontWeight.w700))),
        ),
      ..._groups.map((g) => GestureDetector(
        onTap: () => _openGroup(g),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: const Color(0xFFEDEBFB), borderRadius: BorderRadius.circular(14)),
                child: Icon(iconForName(g.iconName), color: AppColors.purple, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.name, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded, size: 14, color: AppColors.orange),
                        Text(' ${g.streak} day streak', style: GoogleFonts.nunito(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.purple)),
                        Text('   |   ', style: GoogleFonts.nunito(fontSize: 11, color: AppColors.sub)),
                        const Icon(Icons.people_alt_rounded, size: 13, color: AppColors.purple),
                        Text(' ${g.memberCount} Members', style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.sub)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.purple),
            ],
          ),
        ),
      )),
      const SizedBox(height: 10),
      _actionCard(Icons.add_rounded, 'Create group', 'Start a new group and invite members', _createGroupDialog),
      const SizedBox(height: 10),
      _actionCard(Icons.link_rounded, 'Join via code', 'Enter a code to join an existing group', _joinGroupDialog),
    ];
  }

  Widget _actionCard(IconData icon, String title, String sub, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: AppColors.purple, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.purple)),
                  Text(sub, style: GoogleFonts.nunito(fontSize: 11, color: AppColors.sub, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}