import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../service/profile_store.dart';
import '../shared_widgets.dart';
import '../service/group_service.dart';
import '../service/app_events.dart';
import '../service/profile_store.dart';


class GroupProgressScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String tagline;
  final IconData icon;

  const GroupProgressScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.tagline,
    required this.icon,
  });

  @override
  State<GroupProgressScreen> createState() => _GroupProgressScreenState();
}

class _GroupProgressScreenState extends State<GroupProgressScreen> {
  static const _green = Color(0xFF34A853);
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  final _groupService = GroupService();
  RealtimeChannel? _channel;
  GroupProgressData? _data;
  bool _loading = true;
  bool _sortByStatus = false;

  @override
  void initState() {
    super.initState();
    _load();
    AppEvents.progress.addListener(_load);
    AppEvents.groups.addListener(_load);
    _channel = _groupService.subscribeToGroupUpdates(widget.groupId, _load);
  }

  @override
  void dispose() {
    AppEvents.progress.removeListener(_load);
    AppEvents.groups.removeListener(_load);
    if (_channel != null) Supabase.instance.client.removeChannel(_channel!);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await _groupService.fetchGroupProgress(widget.groupId);
      if (mounted) setState(() { _data = d; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      final firstLoad = _data == null;
      setState(() => _loading = false);
      if (firstLoad) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load group progress: $e')),
        );
      }
    }
  }

  List<GroupProgressMember> get _sortedMembers {
    final list = [...?_data?.members];
    int byName(GroupProgressMember a, GroupProgressMember b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (_sortByStatus) {
      list.sort((a, b) {
        if (a.doneToday != b.doneToday) return a.doneToday ? -1 : 1;
        return byName(a, b);
      });
    } else {
      list.sort(byName);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    return GradientScaffold(
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.purple,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topBar(),
              const SizedBox(height: 16),
              _header(data?.members.length ?? 0),
              const SizedBox(height: 16),
              if (data == null && _loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator(color: AppColors.purple)),
                )
              else if (data != null) ...[
                _todayCard(data),
                const SizedBox(height: 16),
                if (data.task != null) ...[
                  _taskCard(data.task!),
                  const SizedBox(height: 16),
                ],
                _membersCard(),              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back_rounded, color: AppColors.purple, size: 26),
        ),
        Expanded(
          child: Center(
            child: Text('Group Progress',
                style: GoogleFonts.schoolbell(
                    fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.ink)),
          ),
        ),
        const SizedBox(width: 26),
      ],
    );
  }

  Widget _header(int count) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFEDEBFB),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(widget.icon, color: AppColors.purple, size: 30),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.groupName,
                  style: GoogleFonts.nunito(
                      fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.ink)),
              Text('$count ${count == 1 ? 'member' : 'members'}',
                  style: GoogleFonts.nunito(
                      fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.sub)),
              if (widget.tagline.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDEBFB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(widget.tagline,
                      style: GoogleFonts.nunito(
                          fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.purple)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _todayCard(GroupProgressData d) {
    final now = DateTime.now();
    final total = d.members.length;
    final done = d.completedToday;
    final value = total == 0 ? 0.0 : done / total;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: softCard(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Today's Group Progress",
                  style: GoogleFonts.schoolbell(
                      fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink)),
              Text('${_months[now.month - 1]} ${now.day}, ${now.year}',
                  style: GoogleFonts.nunito(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.sub)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 11,
                        strokeCap: StrokeCap.round,
                        backgroundColor: const Color(0xFFE2DDFE),
                        valueColor: const AlwaysStoppedAnimation(AppColors.purple),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$done/$total',
                            style: GoogleFonts.nunito(
                                fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.ink)),
                        Text('completed',
                            style: GoogleFonts.nunito(
                                fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.sub)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: d.members.map(_avatar).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatar(GroupProgressMember m) {
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          UserAvatar(size: 40, avatarPath: m.avatarPath),
          Positioned(right: -2, bottom: -2, child: _statusDot(m.doneToday)),
        ],
      ),
    );
  }

  Widget _statusDot(bool done) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? _green : Colors.white,
        border: Border.all(color: done ? _green : const Color(0xFFC7C5DE), width: 1.6),
      ),
      child: done ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
    );
  }

  bool _completing = false;

  Future<void> _markDone() async {
    if (_completing) return;
    setState(() => _completing = true);
    try {
      await _groupService.completeGroupTask(widget.groupId);
      AppEvents.progress.emit(); // triggers _load() here + refreshes GroupDetailScreen
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark done: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  Widget _taskCard(GroupTask task) {
    final done = task.doneByYou;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: softCard(radius: 22),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEDEBFB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.assignment_turned_in_rounded, color: AppColors.purple),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's Group Task",
                    style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.sub)),
                const SizedBox(height: 2),
                Text(task.title,
                    style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: done ? null : _markDone,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: done ? const Color(0xFFE3F5EA) : AppColors.purple,
                borderRadius: BorderRadius.circular(14),
              ),
              child: _completing
                  ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Row(
                children: [
                  Icon(Icons.check_rounded, size: 16, color: done ? _green : Colors.white),
                  const SizedBox(width: 6),
                  Text(done ? 'Done' : 'Mark as Done',
                      style: GoogleFonts.nunito(
                          fontSize: 13, fontWeight: FontWeight.w800,
                          color: done ? _green : Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _membersCard() {
    final list = _sortedMembers;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      decoration: softCard(radius: 22),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Members (${list.length})',
                  style: GoogleFonts.nunito(
                      fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.ink)),
              PopupMenuButton<bool>(
                onSelected: (v) => setState(() => _sortByStatus = v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: false, child: Text('Name')),
                  PopupMenuItem(value: true, child: Text('Status')),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Sort: ${_sortByStatus ? 'Status' : 'Name'}',
                        style: GoogleFonts.nunito(
                            fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.sub)),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.sub),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...List.generate(list.length, (i) {
            final m = list[i];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      UserAvatar(size: 40, avatarPath: m.avatarPath),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(m.isYou ? '${m.name} (You)' : m.name,
                            style: GoogleFonts.nunito(
                                fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                      ),
                      Icon(
                        m.doneToday ? Icons.check_circle_rounded : Icons.circle_outlined,
                        size: 20,
                        color: m.doneToday ? _green : const Color(0xFFC7C5DE),
                      ),
                      const SizedBox(width: 6),
                      Text(m.doneToday ? 'Completed' : 'Not yet completed',
                          style: GoogleFonts.nunito(
                              fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.sub)),
                    ],
                  ),
                ),
                if (i != list.length - 1) const Divider(height: 1, color: AppColors.cardBorder),
              ],
            );
          }),
        ],
      ),
    );
  }
}