import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/classroom_store.dart';
import '../../widgets/common/app_top_bar.dart';
import '../shop/shop_screen.dart';
import '../../data/auth_store.dart';
import '../../data/notification_store.dart';
import '../../data/theme_store.dart';
import '../auth/sign_in_screen.dart';
import '../auth/sign_up_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    ClassroomStore.instance.initialize();
  }

  Future<void> _openImportManager(BuildContext context) async {
    final store = ClassroomStore.instance;
    if (!store.state.value.isConnected) {
      return;
    }
    final selection = await showDialog<_ImportSelection>(
      context: context,
      builder: (_) => _ImportManagerDialog(state: store.state.value),
    );
    if (selection == null) {
      return;
    }
    await store.applyImports(
      courseIds: selection.courseIds,
      assignmentIds: selection.assignmentIds,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Imports updated.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: AppTopBar(
              title: 'Profile',
              onShopTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ShopScreen()),
                );
              },
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.progressTrack,
                        child: Icon(Icons.person, size: 34),
                      ),
                      const SizedBox(width: 12),
                      ValueListenableBuilder<User?>(
                        valueListenable: AuthStore.instance.user,
                        builder: (context, user, _) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName ?? user?.email ?? 'Student',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                user?.emailVerified == true ? 'Email verified' : 'Email not verified',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Preferences',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<bool>(
                    valueListenable: NotificationStore.instance.enabled,
                    builder: (context, enabled, _) {
                      return SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.notifications_outlined),
                        title: const Text('Notifications'),
                        value: enabled,
                        onChanged: (value) => NotificationStore.instance.setEnabled(value),
                      );
                    },
                  ),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: ThemeStore.instance.mode,
                    builder: (context, mode, _) {
                      final useSystem = mode == ThemeMode.system;
                      final isDark = mode == ThemeMode.dark;
                      return Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: const Icon(Icons.palette_outlined),
                            title: const Text('Use system theme'),
                            value: useSystem,
                            onChanged: (value) {
                              if (value) {
                                ThemeStore.instance.set(ThemeMode.system);
                              } else {
                                ThemeStore.instance.set(isDark ? ThemeMode.dark : ThemeMode.light);
                              }
                            },
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: const Icon(Icons.dark_mode_outlined),
                            title: const Text('Dark mode'),
                            value: isDark,
                            onChanged: useSystem
                                ? null
                                : (value) => ThemeStore.instance.set(
                                      value ? ThemeMode.dark : ThemeMode.light,
                                    ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Google Classroom',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<ClassroomState>(
                    valueListenable: ClassroomStore.instance.state,
                    builder: (context, state, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!state.isConnected)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Connect to see your classes and assignments.',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                FilledButton.icon(
                                  onPressed: ClassroomStore.instance.connect,
                                  icon: const Icon(Icons.link_rounded),
                                  label: const Text('Connect Google Classroom'),
                                ),
                              ],
                            )
                          else ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: ClassroomStore.instance.refresh,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Refresh'),
                                ),
                                FilledButton.icon(
                                  onPressed: () => _openImportManager(context),
                                  icon: const Icon(Icons.checklist_rounded),
                                  label: const Text('Manage imports'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: ClassroomStore.instance.disconnect,
                                  icon: const Icon(Icons.link_off_rounded),
                                  label: const Text('Disconnect'),
                                ),
                              ],
                            ),
                          ],
                          if (state.isLoading)
                            const Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: LinearProgressIndicator(minHeight: 4),
                            ),
                          if (state.errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                state.errorMessage!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.tomatoRed,
                                    ),
                              ),
                            ),
                          if (state.isConnected) ...[
                            const SizedBox(height: 12),
                            Builder(builder: (context) {
                              final importedCourses = state.courses
                                  .where((c) => state.importedCourseIds.contains(c.id))
                                  .toList();
                              final importedAssignments = state.assignments
                                  .where((a) => state.importedAssignmentIds.contains(a.id))
                                  .toList();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tracked classes (${importedCourses.length})',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  if (importedCourses.isEmpty)
                                    Text(
                                      'Nothing imported yet. Tap "Manage imports" to choose what to track.',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    )
                                  else
                                    for (final course in importedCourses)
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(Icons.class_rounded),
                                        title: Text(course.name),
                                        subtitle: course.section == null
                                            ? null
                                            : Text(course.section!),
                                      ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Tracked assignments (${importedAssignments.length})',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  if (importedAssignments.isEmpty)
                                    Text(
                                      'No assignments tracked.',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    )
                                  else
                                    for (final assignment in importedAssignments)
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(Icons.assignment_outlined),
                                        title: Text(assignment.title),
                                        subtitle: Text('${assignment.courseName} • ${assignment.dueLabel}'),
                                      ),
                                ],
                              );
                            }),
                          ],
                        ],
                      );
                    },
                  ),
                  ValueListenableBuilder(
                    valueListenable: AuthStore.instance.user,
                    builder: (context, value, _) {
                      if (value == null) {
                        return Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignInScreen())),
                                child: const Text('Sign in'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignUpScreen())),
                              child: const Text('Register'),
                            ),
                          ],
                        );
                      }

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.logout),
                        title: Text('Sign out (${value.displayName ?? value.email ?? 'Account'})'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await AuthStore.instance.signOut();
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ImportSelection {
  const _ImportSelection({required this.courseIds, required this.assignmentIds});
  final Set<String> courseIds;
  final Set<String> assignmentIds;
}

class _ImportManagerDialog extends StatefulWidget {
  const _ImportManagerDialog({required this.state});

  final ClassroomState state;

  @override
  State<_ImportManagerDialog> createState() => _ImportManagerDialogState();
}

class _ImportManagerDialogState extends State<_ImportManagerDialog> {
  late Set<String> _selectedCourses;
  late Set<String> _selectedAssignments;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedCourses = {...widget.state.importedCourseIds};
    _selectedAssignments = {...widget.state.importedAssignmentIds};
  }

  void _toggleCourse(ClassroomCourse course, bool checked, List<ClassroomAssignment> courseAssignments) {
    setState(() {
      if (checked) {
        _selectedCourses.add(course.id);
        _selectedAssignments.addAll(courseAssignments.map((a) => a.id));
      } else {
        _selectedCourses.remove(course.id);
        for (final a in courseAssignments) {
          _selectedAssignments.remove(a.id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final courses = widget.state.courses;
    final assignments = widget.state.assignments;
    final q = _query.trim().toLowerCase();

    final assignmentsByCourse = <String, List<ClassroomAssignment>>{};
    for (final a in assignments) {
      assignmentsByCourse.putIfAbsent(a.courseId, () => []).add(a);
    }
    final orphanAssignments = assignments
        .where((a) => !courses.any((c) => c.id == a.courseId))
        .toList();

    bool matches(String text) => q.isEmpty || text.toLowerCase().contains(q);

    return AlertDialog(
      title: const Text('Choose what to track'),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      content: SizedBox(
        width: 520,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search classes or assignments',
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 6),
            Text(
              'Tip: checking a class also picks its assignments.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  if (courses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No classes available.'),
                    )
                  else
                    for (final course in courses)
                      _buildCourseGroup(
                        course,
                        assignmentsByCourse[course.id] ?? const [],
                        matches,
                      ),
                  if (orphanAssignments.isNotEmpty) ...[
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Other assignments',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    for (final assignment in orphanAssignments.where(
                        (a) => matches(a.title) || matches(a.courseName)))
                      _buildAssignmentTile(assignment),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _ImportSelection(
              courseIds: _selectedCourses,
              assignmentIds: _selectedAssignments,
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildCourseGroup(
    ClassroomCourse course,
    List<ClassroomAssignment> courseAssignments,
    bool Function(String) matches,
  ) {
    final courseMatches = matches(course.name);
    final visibleAssignments = courseAssignments
        .where((a) => courseMatches || matches(a.title))
        .toList();
    if (!courseMatches && visibleAssignments.isEmpty) {
      return const SizedBox.shrink();
    }
    final courseSelected = _selectedCourses.contains(course.id);
    final selectedCount = courseAssignments
        .where((a) => _selectedAssignments.contains(a.id))
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.cardStroke),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            controlAffinity: ListTileControlAffinity.leading,
            value: courseSelected,
            title: Text(
              course.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${courseAssignments.length} assignment${courseAssignments.length == 1 ? '' : 's'}'
              ' • $selectedCount selected'
              '${course.section == null ? '' : ' • ${course.section}'}',
            ),
            onChanged: (checked) =>
                _toggleCourse(course, checked == true, courseAssignments),
          ),
          if (visibleAssignments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 8, bottom: 4),
              child: Column(
                children: [
                  for (final assignment in visibleAssignments)
                    _buildAssignmentTile(assignment),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAssignmentTile(ClassroomAssignment assignment) {
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: _selectedAssignments.contains(assignment.id),
      title: Text(assignment.title),
      subtitle: Text(assignment.dueLabel),
      onChanged: (checked) => setState(() {
        if (checked == true) {
          _selectedAssignments.add(assignment.id);
        } else {
          _selectedAssignments.remove(assignment.id);
        }
      }),
    );
  }
}
