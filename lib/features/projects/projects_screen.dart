import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/project_store.dart';
import '../../data/subject_store.dart';
import '../../data/task_store.dart';
import '../../models/project_item.dart';
import '../../models/task_item.dart';
import '../../widgets/cards/project_card.dart';
import '../../widgets/common/app_top_bar.dart';
import '../shop/shop_screen.dart';
import 'project_workspace_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _busy ? null : _showProjectActions,
        backgroundColor: AppColors.burntOrange,
        foregroundColor: AppColors.white,
        child: const Icon(Icons.add),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: AppTopBar(
                title: 'Projects',
                onShopTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ShopScreen()),
                  );
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
            sliver: ValueListenableBuilder<List<ProjectItem>>(
              valueListenable: ProjectStore.instance.projectsNotifier,
              builder: (context, projects, _) {
                return ValueListenableBuilder<List<TaskItem>>(
                  valueListenable: TaskStore.instance.tasksNotifier,
                  builder: (context, tasks, _) {
                    if (projects.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 36),
                          child: Text(
                            'No projects yet. Create one or join with an invite code.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ),
                      );
                    }

                    final projectCards = projects
                        .map((project) => _withTaskStats(project, tasks))
                        .toList();

                    return SliverList.builder(
                      itemCount: projectCards.length,
                      itemBuilder: (context, index) => ProjectCard(
                        project: projectCards[index],
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProjectWorkspaceScreen(project: projectCards[index]),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  ProjectItem _withTaskStats(ProjectItem project, List<TaskItem> allTasks) {
    final scoped = allTasks.where((task) => task.projectId == project.id).toList();
    final done = scoped.where((task) => task.isDone).length;
    return project.copyWith(
      completedTasks: done,
      totalTasks: scoped.length,
      teamCount: project.memberLabels.isEmpty ? project.teamCount : project.memberLabels.length,
    );
  }

  Future<void> _showProjectActions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.add_circle_outline_rounded),
                  title: const Text('Create Project'),
                  subtitle: const Text('Start a new workspace for your team'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _showCreateProjectDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.qr_code_scanner_rounded),
                  title: const Text('Join Project'),
                  subtitle: const Text('Paste invite code or invite link'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _showJoinProjectDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreateProjectDialog() async {
    final titleController = TextEditingController();
    final subjectController = TextEditingController();
    String typeLabel = 'Team Project';
    bool linkToSubject = false;
    final subjects = _subjectOptions();
    const String newSubjectValue = '__new_subject__';
    String? selectedSubject = subjects.isNotEmpty ? subjects.first : null;
    bool addingNewSubject = subjects.isEmpty;

    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Create Project'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Project title'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: typeLabel,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: 'Team Project', child: Text('Team Project')),
                      DropdownMenuItem(value: 'Individual', child: Text('Individual')),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setLocalState(() => typeLabel = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    value: linkToSubject,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Link this project to a subject'),
                    onChanged: (value) => setLocalState(() => linkToSubject = value),
                  ),
                  if (linkToSubject)
                    Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: addingNewSubject ? newSubjectValue : selectedSubject,
                          decoration: const InputDecoration(labelText: 'Subject'),
                          items: [
                            for (final subject in subjects)
                              DropdownMenuItem(value: subject, child: Text(subject)),
                            const DropdownMenuItem(
                              value: newSubjectValue,
                              child: Text('Add new subject...'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setLocalState(() {
                              if (value == newSubjectValue) {
                                addingNewSubject = true;
                                selectedSubject = null;
                              } else {
                                addingNewSubject = false;
                                selectedSubject = value;
                              }
                            });
                          },
                        ),
                        if (addingNewSubject) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: subjectController,
                            decoration: const InputDecoration(
                              labelText: 'New subject',
                              hintText: 'e.g. Database Systems',
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (approved != true) {
      return;
    }

    final title = titleController.text.trim();
    if (title.isEmpty) {
      _showMessage('Project title is required.');
      return;
    }

    final subject = linkToSubject
        ? (addingNewSubject ? subjectController.text.trim() : (selectedSubject ?? '').trim())
        : '';
    if (linkToSubject && subject.isEmpty) {
      _showMessage('Subject is required when linking a project to a subject.');
      return;
    }

    setState(() => _busy = true);
    try {
      await ProjectStore.instance.createProject(
        title: title,
        typeLabel: typeLabel,
        subject: linkToSubject ? subject : null,
      );
      if (linkToSubject && subject.isNotEmpty) {
        await SubjectStore.instance.addSubject(subject);
      }
      _showMessage('Project created.');
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _showJoinProjectDialog() async {
    final inviteController = TextEditingController();

    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Join Project'),
          content: TextField(
            controller: inviteController,
            decoration: const InputDecoration(
              labelText: 'Invite code or link',
              hintText: 'ABCD2345 or https://.../join?code=ABCD2345',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Join'),
            ),
          ],
        );
      },
    );

    if (approved != true) {
      return;
    }

    final token = inviteController.text.trim();
    if (token.isEmpty) {
      _showMessage('Enter an invite code or link.');
      return;
    }

    setState(() => _busy = true);
    try {
      await ProjectStore.instance.joinProjectByInvite(token);
      _showMessage('Joined project successfully.');
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  List<String> _subjectOptions() {
    final fromTasks = TaskStore.instance.tasks
        .map((task) => task.subject)
        .where((subject) => subject.trim().isNotEmpty)
        .toSet();
    final merged = <String>{
      ...fromTasks,
      ...SubjectStore.instance.subjects.value,
    };
    final list = merged.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }
}
