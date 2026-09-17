import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shared_widgets.dart';
import '../service/friend_service.dart';
import '../service/group_service.dart';

Future<void> showAddMembersSheet(
    BuildContext context, {
      required String groupId,
      required String inviteCode,
      VoidCallback? onMemberAdded,
    }) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddMembersSheet(
      groupId: groupId,
      inviteCode: inviteCode,
      onMemberAdded: onMemberAdded,
    ),
  );
}

class _AddMembersSheet extends StatefulWidget {
  final String groupId;
  final String inviteCode;
  final VoidCallback? onMemberAdded;

  const _AddMembersSheet({
    required this.groupId,
    required this.inviteCode,
    this.onMemberAdded,
  });

  @override
  State<_AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends State<_AddMembersSheet> {
  final _friendService = FriendService();
  final _groupService = GroupService();

  List<Friend> _friends = [];
  Set<String> _memberIds = {};
  final Set<String> _addingIds = {};
  final Set<String> _justAddedIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _friendService.fetchFriends(),
        _groupService.fetchMemberUserIds(widget.groupId),
      ]);
      if (mounted) {
        setState(() {
          _friends = results[0] as List<Friend>;
          _memberIds = results[1] as Set<String>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load friends: $e')),
        );
      }
    }
  }

  Future<void> _addFriend(Friend f) async {
    setState(() => _addingIds.add(f.id));
    try {
      await _groupService.addMemberToGroup(widget.groupId, f.userId);
      if (mounted) {
        setState(() {
          _addingIds.remove(f.id);
          _justAddedIds.add(f.id);
        });
        widget.onMemberAdded?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _addingIds.remove(f.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add: $e')),
        );
      }
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite code copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableFriends =
    _friends.where((f) => !_memberIds.contains(f.userId)).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3E1F5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text(
                  'Add members',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: GestureDetector(
                  onTap: _copyCode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDEBFB),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.link_rounded, color: AppColors.purple, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Invite code',
                                style: GoogleFonts.nunito(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.sub,
                                ),
                              ),
                              Text(
                                widget.inviteCode,
                                style: GoogleFonts.nunito(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.purple,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.copy_rounded, color: AppColors.purple, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Or add from your friends'),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.purple))
                    : availableFriends.isEmpty
                    ? Center(
                  child: Text(
                    _friends.isEmpty
                        ? 'You have no friends to add yet'
                        : 'All your friends are already in this group',
                    style: GoogleFonts.nunito(color: AppColors.sub, fontWeight: FontWeight.w700),
                  ),
                )
                    : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: availableFriends.length,
                  itemBuilder: (context, i) {
                    final f = availableFriends[i];
                    final adding = _addingIds.contains(f.id);
                    final added = _justAddedIds.contains(f.id);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 20,
                            backgroundColor: Color(0xFFEDEBFB),
                            child: Icon(Icons.person_rounded, color: AppColors.purple),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              f.fullName,
                              style: GoogleFonts.nunito(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink),
                            ),
                          ),
                          if (added)
                            Text('Added', style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.green))
                          else
                            GestureDetector(
                              onTap: adding ? null : () => _addFriend(f),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.purple,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: adding
                                    ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                                    : Text('Add', style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}