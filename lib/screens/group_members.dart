import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shared_widgets.dart';

class GroupMemberEntry {
  final String name;
  const GroupMemberEntry({required this.name});
}

class GroupMembersScreen extends StatelessWidget {
  final String groupName;
  final String tagline;
  final IconData icon;
  final int memberCount;
  final List<GroupMemberEntry> members;

  const GroupMembersScreen({
    super.key,
    required this.groupName,
    required this.tagline,
    required this.icon,
    required this.memberCount,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back_rounded, color: AppColors.purple, size: 26),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Group Members',
                      style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink),
                    ),
                  ),
                ),
                const SizedBox(width: 26), // balances the back icon so title stays centered
              ],
            ),
            const SizedBox(height: 20),
            _buildHeaderRow(),
            const SizedBox(height: 20),
            ...List.generate(members.length, (i) {
              final rank = i + 1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _memberRow(rank, members[i]),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: const Color(0xFFEDEBFB), borderRadius: BorderRadius.circular(18)),
          child: Icon(icon, color: AppColors.purple, size: 30),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(groupName, style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink)),
              Text(
                tagline,
                style: GoogleFonts.nunito(fontSize: 12.5, color: AppColors.sub, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.people_alt_rounded, size: 14, color: AppColors.purple),
                  Text(' $memberCount Members', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.sub)),
                ],
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFEDEBFB), borderRadius: BorderRadius.circular(14)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_add_alt_1_rounded, size: 16, color: AppColors.purple),
                const SizedBox(width: 6),
                Text('Invite', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.purple)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _memberRow(int rank, GroupMemberEntry member) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: softCard(radius: 18),
      child: Row(
        children: [
          SizedBox(width: 28, child: _rankBadge(rank)),
          const SizedBox(width: 10),
          const CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFFEDEBFB),
            child: Icon(Icons.person_rounded, color: AppColors.purple),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(member.name, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.sub),
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'remove', child: Text('Remove from group')),
              const PopupMenuItem(value: 'message', child: Text('Message')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rankBadge(int rank) {
    if (rank == 1) {
      return _crown(const Color(0xFFF2C94C), '1');
    } else if (rank == 2) {
      return _crown(const Color(0xFFB8BCC8), '2');
    } else if (rank == 3) {
      return _crown(const Color(0xFFD08A5B), '3');
    }
    return Center(
      child: Text('$rank', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.sub)),
    );
  }

  Widget _crown(Color color, String rankLabel) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.emoji_events_rounded, color: color, size: 26),
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            rankLabel,
            style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ),
      ],
    );
  }
}