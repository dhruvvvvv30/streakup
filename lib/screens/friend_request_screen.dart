import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shared_widgets.dart';
import '../service/friend_service.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  final _service = FriendService();
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  final Set<Future> _pendingOps = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final requests = await _service.fetchIncomingRequests();
      if (mounted) setState(() { _requests = requests; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load requests: $e')),
        );
      }
    }
  }

  Future<void> _accept(Map<String, dynamic> req) async {
    final id = req['id'] as String;
    setState(() => _requests.removeWhere((r) => r['id'] == id));
    final op = _service.acceptRequest(id);
    _pendingOps.add(op);
    try {
      await op;
    } catch (e) {
      setState(() => _requests.add(req));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept: $e')),
        );
      }
    } finally {
      _pendingOps.remove(op);
    }
  }

  Future<void> _decline(Map<String, dynamic> req) async {
    final id = req['id'] as String;
    setState(() => _requests.removeWhere((r) => r['id'] == id));
    final op = _service.declineRequest(id);
    _pendingOps.add(op);
    try {
      await op;
    } catch (e) {
      setState(() => _requests.add(req));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to decline: $e')),
        );
      }
    } finally {
      _pendingOps.remove(op);
    }
  }

  Future<void> _goBack() async {
    if (_pendingOps.isNotEmpty) {
      await Future.wait(_pendingOps.toList());
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: _pendingOps.isEmpty,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _goBack();
        },
        child: GradientScaffold(
          child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: _goBack,
                  child: const Icon(Icons.arrow_back_rounded, color: AppColors.purple, size: 26),
                ),
                const SizedBox(width: 14),
                Text('Friend Requests', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink)),
              ],
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: AppColors.purple)))
            else if (_requests.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text('No pending requests', style: GoogleFonts.nunito(color: AppColors.sub, fontWeight: FontWeight.w700))),
              )
            else
              ..._requests.map((req) {
                final profile = req['profiles'] as Map<String, dynamic>?;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: softCard(radius: 18),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 22,
                          backgroundColor: Color(0xFFEDEBFB),
                          child: Icon(Icons.person_rounded, color: AppColors.purple),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(profile?['full_name'] as String? ?? 'Unknown', style: GoogleFonts.nunito(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                        ),
                        GestureDetector(
                          onTap: () => _decline(req),
                          child: Container(
                            width: 36, height: 36,
                            decoration: const BoxDecoration(color: Color(0xFFFFE5E5), shape: BoxShape.circle),
                            child: const Icon(Icons.close_rounded, color: Colors.red, size: 18),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _accept(req),
                          child: Container(
                            width: 36, height: 36,
                            decoration: const BoxDecoration(color: AppColors.purple, shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    ),
    );
  }
}