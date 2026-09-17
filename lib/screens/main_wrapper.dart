import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'todo_screen.dart';
import 'journal_screen.dart';
import 'community_screen.dart';
import 'ProfileScreen.dart';
import '../shared_widgets.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});
  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;
  final _todoKey = GlobalKey<TodoScreenState>(); // NEW
  final _journalKey = GlobalKey<JournalScreenContentState>(); // NEW

  void _goToTab(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onNavigateToTab: _goToTab),
      TodoScreen(key: _todoKey), // was: const TodoScreen()
      JournalScreenContent(key: _journalKey), // was: const JournalScreenContent()
      const CommunityScreenContent(),
    ];
    return GradientScaffold(
      endDrawer: const ProfileScreen(),
      child: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: AppBottomNav(
        index: _currentIndex,
        onTap: _goToTab,
        onAdd: () => showAddOptionsSheet(
          context,
          onAddTask: () {
            _goToTab(1); // switch to Tasks tab so the dialog appears in context
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _todoKey.currentState?.triggerAddTask();
            });
          },
          onAddJournal: () {
            _goToTab(2); // switch to Journal tab
            _journalKey.currentState?.triggerStartWriting();
          },
        ),
      ),
    );
  }
}