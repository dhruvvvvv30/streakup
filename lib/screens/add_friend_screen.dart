  import 'package:flutter/material.dart';
  import 'package:google_fonts/google_fonts.dart';
  import '../shared_widgets.dart';
  import '../service/friend_service.dart';

  class AddFriendScreen extends StatefulWidget {
    const AddFriendScreen({super.key});

    @override
    State<AddFriendScreen> createState() => _AddFriendScreenState();
  }

  class _AddFriendScreenState extends State<AddFriendScreen> {
    final _service = FriendService();
    final _controller = TextEditingController();
    Map<String, dynamic>? _foundUser;
    bool _loading = false;
    bool _searched = false;
    bool _sent = false;
    String? _myCode;

    @override
    void initState() {
      super.initState();
      _loadMyCode();
    }

    Future<void> _loadMyCode() async {
      final code = await _service.fetchMyFriendCode();
      if (mounted) setState(() => _myCode = code);
    }

    Future<void> _lookup() async {
      final code = _controller.text.trim();
      if (code.isEmpty) return;

      setState(() { _loading = true; _searched = true; _sent = false; });
      try {
        final user = await _service.findUserByFriendCode(code);
        if (mounted) setState(() { _foundUser = user; _loading = false; });
      } catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lookup failed: $e')),
          );
        }
      }
    }

    Future<void> _sendRequest() async {
      if (_foundUser == null) return;
      setState(() => _sent = true);
      try {
        await _service.sendFriendRequest(_foundUser!['id'] as String);
      } on FriendRequestException catch (e) {
        setState(() => _sent = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
      } catch (e) {
        setState(() => _sent = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send request: $e')),
          );
        }
      }
    }

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
                  const SizedBox(width: 14),
                  Text('Add Friend', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink)),
                ],
              ),
              const SizedBox(height: 20),
              // Your own code, so you can share it
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: softCard(radius: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Friend Code', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.sub)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          _myCode ?? '......',
                          style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.purple, letterSpacing: 2),
                        ),
                        const Spacer(),
                        if (_myCode != null)
                          GestureDetector(
                            onTap: () {
                              // Clipboard copy — add package:flutter/services.dart import if not present in shared_widgets
                            },
                            child: const Icon(Icons.copy_rounded, size: 18, color: AppColors.purple),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Share this with friends so they can add you', style: GoogleFonts.nunito(fontSize: 11.5, color: AppColors.sub, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Enter a Friend Code', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: softCard(radius: 16),
                      child: TextField(
                        controller: _controller,
                        textCapitalization: TextCapitalization.characters,
                        style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                        decoration: InputDecoration(
                          hintText: 'e.g. A1B2C3',
                          hintStyle: GoogleFonts.nunito(color: AppColors.sub, fontWeight: FontWeight.w600),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _lookup(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _lookup,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(color: AppColors.purple, shape: BoxShape.circle),
                      child: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_loading)
                const Center(child: CircularProgressIndicator(color: AppColors.purple))
              else if (_searched && _foundUser == null)
                Center(
                  child: Text('No user found with that code', style: GoogleFonts.nunito(color: AppColors.sub, fontWeight: FontWeight.w700)),
                )
              else if (_foundUser != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: softCard(radius: 18),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 22,
                          backgroundColor: Color(0xFFEDEBFB),
                          child: Icon(Icons.person_rounded, color: AppColors.purple),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_foundUser!['full_name'] as String? ?? 'Unknown', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
                              if (_foundUser!['username'] != null)
                                Text('@${_foundUser!['username']}', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.sub, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _sent ? null : _sendRequest,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: _sent ? const Color(0xFFEDEBFB) : AppColors.purple,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              _sent ? 'Sent' : 'Add',
                              style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w800, color: _sent ? AppColors.purple : Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      );
    }
  }