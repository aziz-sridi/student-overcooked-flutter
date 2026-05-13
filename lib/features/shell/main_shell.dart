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

  final screens = const [
    FocusScreen(),
    TasksScreen(),
    HomeScreen(),
    ProjectsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    tabIndex = widget.initialTabIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: KeyedSubtree(
        key: ValueKey(tabIndex),
        child: screens[tabIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tabIndex,
        onTap: (index) => setState(() => tabIndex = index),
        selectedItemColor: AppColors.burntOrange,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.timer_rounded), label: 'Focus'),
          BottomNavigationBarItem(icon: Icon(Icons.task_rounded), label: 'Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_rounded),
            label: 'Projects',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
