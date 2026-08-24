import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../focus/focus_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../projects/projects_screen.dart';
import '../tasks/tasks_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialTabIndex = 2});

  final int initialTabIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int tabIndex;
  late final List<ScrollController> _scrollControllers;
  late final TasksScreenController _tasksController;
  late final List<Widget> screens;

  @override
  void initState() {
    super.initState();
    tabIndex = widget.initialTabIndex;
    _scrollControllers = List.generate(5, (_) => ScrollController());
    _tasksController = TasksScreenController();
    screens = [
      FocusScreen(scrollController: _scrollControllers[0]),
      TasksScreen(
        scrollController: _scrollControllers[1],
        controller: _tasksController,
      ),
      HomeScreen(scrollController: _scrollControllers[2]),
      ProjectsScreen(scrollController: _scrollControllers[3]),
      ProfileScreen(scrollController: _scrollControllers[4]),
    ];
  }

  @override
  void dispose() {
    for (final controller in _scrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == 1) {
      _tasksController.resetForVisit();
    }
    setState(() => tabIndex = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = _scrollControllers[index];
      if (controller.hasClients) {
        controller.jumpTo(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: tabIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tabIndex,
        onTap: _selectTab,
        selectedItemColor: AppColors.burntOrange,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.timer_rounded),
            label: 'Focus',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.task_rounded),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_rounded),
            label: 'Projects',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
