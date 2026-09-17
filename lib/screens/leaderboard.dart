import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared_widgets.dart';
import '../service/group_service.dart';
import '../service/app_events.dart';
import 'group_members.dart';
import 'add_member_screen.dart';

class GroupMember {
  final String name;
  final int xp;
  final bool isYou;

  const GroupMember({
    required this.name,
    required this.xp,
    this.isYou = false,
  });
}

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final String inviteCode;
  final String groupName;
  final String tagline;
  final IconData icon;
  final int streak;
  final int memberCount;
  final int goalDays;
  final List<GroupMember> members;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    required this.inviteCode,
    required this.groupName,
    required this.tagline,
    required this.icon,
    required this.streak,
    required this.memberCount,
    this.goalDays = 50,
    required this.members,
  });

  @override
  State<GroupDetailScreen> createState() =>
      _GroupDetailScreenState();
}

class _GroupDetailScreenState
    extends State<GroupDetailScreen> {
  final _groupService = GroupService();

  late List<GroupMember> _members;
  late int _memberCount;
  late int _streak;

  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();

    _members = List<GroupMember>.from(
      widget.members,
    );

    _memberCount = widget.memberCount;
    _streak = widget.streak;

    AppEvents.groups.addListener(
      _onGroupChanged,
    );

    // So completing a task on this device updates the leaderboard
    // immediately, without waiting on the realtime round-trip.
    AppEvents.progress.addListener(
      _onGroupChanged,
    );

    // So another member's XP change, or a join/leave from another
    // device, updates this screen live.
    _channel = _groupService.subscribeToGroupUpdates(
      widget.groupId,
      _onGroupChanged,
    );

    _refresh();
  }

  @override
  void dispose() {
    AppEvents.groups.removeListener(
      _onGroupChanged,
    );

    AppEvents.progress.removeListener(
      _onGroupChanged,
    );

    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }

    super.dispose();
  }

  void _onGroupChanged() {
    if (!mounted) return;

    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final stats =
      await _groupService.fetchLeaderboard(
        widget.groupId,
      );

      final streak =
      await _groupService.fetchGroupStreak(
        widget.groupId,
      );

      if (!mounted) return;

      setState(() {
        _members = stats
            .map(
              (s) => GroupMember(
            name: s.name,
            xp: s.xp,
            isYou: s.isYou,
          ),
        )
            .toList();

        _memberCount = stats.length;
        _streak = streak;
      });
    } catch (_) {}
  }

  Future<void> _refreshAfterAdd() async {
    await _refresh();
  }

  Future<void> _confirmLeave(
      BuildContext context,
      ) async {
    final confirm =
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(18),
        ),
        title:
        const Text('Leave group?'),
        content: Text(
          'You\'ll need an invite code to rejoin ${widget.groupName}.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, true),
            child: const Text(
              'Leave',
              style: TextStyle(
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) {
      return;
    }

    try {
      await _groupService.leaveGroup(
        widget.groupId,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content:
            Text('Failed to leave: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [..._members]
      ..sort(
            (a, b) => b.xp.compareTo(a.xp),
      );

    return GradientScaffold(
      child: SingleChildScrollView(
        padding:
        const EdgeInsets.fromLTRB(
          20,
          12,
          20,
          30,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () =>
                      Navigator.of(context)
                          .pop(),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color:
                    AppColors.purple,
                    size: 26,
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () =>
                          showAddMembersSheet(
                            context,
                            groupId:
                            widget.groupId,
                            inviteCode:
                            widget.inviteCode,
                            onMemberAdded:
                            _refreshAfterAdd,
                          ),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration:
                        softCard(
                          radius: 10,
                        ),
                        child: const Icon(
                          Icons
                              .person_add_alt_1_rounded,
                          color:
                          AppColors.purple,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    const Icon(
                      Icons
                          .more_vert_rounded,
                      color:
                      AppColors.ink,
                      size: 24,
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildHeader(context),

            const SizedBox(height: 16),

            _buildProgressCard(),

            const SizedBox(height: 16),

            _buildLeaderboardCard(
              sorted,
            ),

            const SizedBox(height: 20),

            _buildLeaveButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context,
      ) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(
              0xFFEDEBFB,
            ),
            borderRadius:
            BorderRadius.circular(18),
          ),
          child: Icon(
            widget.icon,
            color:
            AppColors.purple,
            size: 30,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                widget.groupName,
                style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight:
                  FontWeight.w900,
                  color:
                  AppColors.ink,
                ),
              ),
              Text(
                widget.tagline,
                style: GoogleFonts.nunito(
                  fontSize: 12.5,
                  color:
                  AppColors.sub,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
              const SizedBox(
                height: 6,
              ),
              GestureDetector(
                onTap: () =>
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            GroupMembersScreen(
                              groupName:
                              widget.groupName,
                              tagline:
                              widget.tagline,
                              icon: widget.icon,
                              memberCount:
                              _memberCount,
                              members: _members
                                  .map(
                                    (m) =>
                                    GroupMemberEntry(
                                      name: m.isYou
                                          ? '${m.name} (You)'
                                          : m.name,
                                    ),
                              )
                                  .toList(),
                            ),
                      ),
                    ),
                child: Row(
                  children: [
                    const Icon(
                      Icons
                          .people_alt_rounded,
                      size: 14,
                      color:
                      AppColors.purple,
                    ),
                    Text(
                      ' $_memberCount Members',
                      style:
                      GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight:
                        FontWeight.w700,
                        color:
                        AppColors.sub,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard() {
    final progress =
    (_streak / widget.goalDays)
        .clamp(0.0, 1.0);

    final remaining =
    (widget.goalDays - _streak)
        .clamp(0, widget.goalDays);

    return Container(
      padding:
      const EdgeInsets.all(18),
      decoration:
      softCard(radius: 22),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Group Progress',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight:
                  FontWeight.w900,
                  color:
                  AppColors.ink,
                ),
              ),
              RichText(
                text: TextSpan(
                  style:
                  GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight:
                    FontWeight.w800,
                    color:
                    AppColors.purple,
                  ),
                  children: [
                    TextSpan(
                      text: '$_streak',
                    ),
                    TextSpan(
                      text:
                      ' / ${widget.goalDays} days',
                      style:
                      GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight:
                        FontWeight.w700,
                        color:
                        AppColors.sub,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                  child:
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor:
                    const Color(
                      0xFFE2DDFE,
                    ),
                    valueColor:
                    const AlwaysStoppedAnimation(
                      AppColors.purple,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons
                    .local_fire_department_rounded,
                color:
                AppColors.orange,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Keep going! $remaining more days to reach ${widget.goalDays} days!',
            style: GoogleFonts.nunito(
              fontSize: 12.5,
              color:
              AppColors.sub,
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardCard(
      List<GroupMember> sorted,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(18),
      decoration:
      softCard(radius: 22),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Leaderboard',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight:
                  FontWeight.w900,
                  color:
                  AppColors.ink,
                ),
              ),
              Text(
                'Total XP',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color:
                  AppColors.sub,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children:
            List.generate(
              sorted.length,
                  (i) {
                final m = sorted[i];
                final rank = i + 1;

                return Column(
                  children: [
                    Padding(
                      padding:
                      const EdgeInsets.symmetric(
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child:
                            _rankBadge(rank),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          const CircleAvatar(
                            radius: 20,
                            backgroundColor:
                            Color(
                              0xFFEDEBFB,
                            ),
                            child: Icon(
                              Icons
                                  .person_rounded,
                              color:
                              AppColors.purple,
                            ),
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          Expanded(
                            child: Text(
                              m.isYou
                                  ? '${m.name} (You)'
                                  : m.name,
                              style:
                              GoogleFonts.nunito(
                                fontSize:
                                14.5,
                                fontWeight:
                                FontWeight.w800,
                                color:
                                AppColors.ink,
                              ),
                            ),
                          ),
                          Text(
                            '${m.xp} XP',
                            style:
                            GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight:
                              FontWeight.w900,
                              color:
                              AppColors.purple,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (i !=
                        sorted.length - 1)
                      const Divider(
                        height: 1,
                        color:
                        AppColors.cardBorder,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankBadge(int rank) {
    final medalColors = {
      1: const Color(0xFFF2C94C),
      2: const Color(0xFFB8BCC8),
      3: const Color(0xFFD08A5B),
    };

    if (medalColors.containsKey(rank)) {
      return Icon(
        Icons.emoji_events_rounded,
        color:
        medalColors[rank],
        size: 22,
      );
    }

    return Text(
      '$rank',
      style: GoogleFonts.nunito(
        fontSize: 14,
        fontWeight:
        FontWeight.w800,
        color:
        AppColors.sub,
      ),
    );
  }

  Widget _buildLeaveButton(
      BuildContext context,
      ) {
    return GestureDetector(
      onTap: () =>
          _confirmLeave(context),
      child: Container(
        width: double.infinity,
        padding:
        const EdgeInsets.symmetric(
          vertical: 16,
        ),
        decoration: BoxDecoration(
          color:
          const Color(0xFFFFE5E5),
          borderRadius:
          BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.logout_rounded,
              color: Colors.red,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Leave Group',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight:
                FontWeight.w800,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}