import 'dart:collection';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../data/auth_store.dart';
import '../../data/ask_ai_service.dart';
import '../../data/focus_queue_store.dart';
import '../../data/project_chat_store.dart';
import '../../data/task_store.dart';
import '../../models/project_item.dart';
import '../../models/task_item.dart';
import '../../widgets/cards/task_card.dart';
import '../shell/main_shell.dart';
import '../tasks/task_editor_dialog.dart';

class ProjectWorkspaceScreen extends StatefulWidget {
  const ProjectWorkspaceScreen({super.key, required this.project});

  final ProjectItem project;

  @override
  State<ProjectWorkspaceScreen> createState() => _ProjectWorkspaceScreenState();
}

class _ProjectWorkspaceScreenState extends State<ProjectWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late List<String> _members;

  final TextEditingController _chatController = _AskAiHighlightController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _askAiController = TextEditingController();
  final List<_AskAiMessage> _askAiMessages = <_AskAiMessage>[];
  bool _askingAi = false;

  final List<String> _stickyNotes = <String>[];
  final List<String> _savedFiles = <String>[];

  bool _allowSelfAssign = true;
  bool _notificationsEnabled = true;

  String get _inviteLink =>
      'https://student-overcooked.app/join?code=${Uri.encodeComponent(widget.project.inviteCode ?? widget.project.id)}';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    final currentLabel = TaskStore.instance.currentMemberLabel();
    final seededMembers = widget.project.memberLabels.isNotEmpty
        ? widget.project.memberLabels
        : [
            currentLabel,
            ...List<String>.generate(
              widget.project.teamCount - 1,
              (index) => 'Member ${index + 2}',
            ),
          ];
    final uniqueMembers = LinkedHashSet<String>.from(seededMembers);
    if (currentLabel.isNotEmpty) {
      uniqueMembers.add(currentLabel);
    }
    _members = uniqueMembers.toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatController.dispose();
    _noteController.dispose();
    _askAiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TaskItem>>(
      stream: TaskStore.instance.projectTasksStream(widget.project.id),
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? <TaskItem>[];
        final tasksError = snapshot.error;

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.project.title),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Tasks'),
                Tab(text: 'Chat'),
                Tab(text: 'Workspace'),
                Tab(text: 'Settings'),
              ],
            ),
          ),
          floatingActionButton: _tabController.index == 0
              ? FloatingActionButton(
                  onPressed: _showCreateTaskDialog,
                  backgroundColor: AppColors.burntOrange,
                  foregroundColor: AppColors.white,
                  child: const Icon(Icons.add),
                )
              : null,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: 3,
            selectedItemColor: AppColors.burntOrange,
            unselectedItemColor: AppColors.textSecondary,
            onTap: _goToTab,
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
          body: TabBarView(
            controller: _tabController,
            children: [
              _TasksTab(
                tasks: tasks,
                projectId: widget.project.id,
                allowSelfAssign: _allowSelfAssign,
                loadError: tasksError,
                onClaimTask: _claimTask,
                onEditTask: _showEditTaskDialog,
                onSendToFocus: _sendTaskToFocus,
              ),
              _ChatTab(
                messageStream: ProjectChatStore.instance.messagesForProject(
                  widget.project.id,
                ),
                inputController: _chatController,
                onSendMessage: _sendChatMessage,
                onSendAiPrompt: _sendChatAiPrompt,
                currentUserId: AuthStore.instance.user.value?.uid,
              ),
              _WorkspaceTab(
                noteController: _noteController,
                stickyNotes: _stickyNotes,
                savedFiles: _savedFiles,
                askAiController: _askAiController,
                askAiMessages: _askAiMessages,
                onAskAi: _sendAskAi,
                askingAi: _askingAi,
                onAddStickyNote: _showAddStickyNoteDialog,
                onUploadFile: _uploadFile,
                onRemoveSticky: _removeSticky,
              ),
              _SettingsTab(
                members: _members,
                allowSelfAssign: _allowSelfAssign,
                notificationsEnabled: _notificationsEnabled,
                inviteLink: _inviteLink,
                onCopyInviteLink: _copyInviteLink,
                onToggleSelfAssign: (value) =>
                    setState(() => _allowSelfAssign = value),
                onToggleNotifications: (value) =>
                    setState(() => _notificationsEnabled = value),
                onRemoveMember: (member) {
                  setState(() => _members.remove(member));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _goToTab(int index) {
    if (index == 3) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => MainShell(initialTabIndex: index)),
      (route) => false,
    );
  }

  Future<void> _showCreateTaskDialog() async {
    final created = await showTaskEditorDialog(
      context,
      fixedProjectId: widget.project.id,
      fixedProjectTitle: widget.project.title,
      allowAssigneeEditing: true,
      members: _members,
    );

    if (created == null) {
      return;
    }

    try {
      await TaskStore.instance.addProjectTask(created);
    } catch (error) {
      _showMessage('Could not create task. ${_cleanError(error)}');
    }
  }

  Future<void> _showEditTaskDialog(TaskItem task) async {
    if (!TaskStore.instance.canEdit(task)) {
      _showMessage('Only the task owner can edit this task.');
      return;
    }

    final edited = await showTaskEditorDialog(
      context,
      existing: task,
      fixedProjectId: widget.project.id,
      fixedProjectTitle: widget.project.title,
      fixedSubject: task.subject,
      allowAssigneeEditing: true,
      members: _members,
    );

    if (edited == null) {
      return;
    }

    try {
      await TaskStore.instance.updateProjectTask(edited);
    } catch (error) {
      _showMessage('Could not update task. ${_cleanError(error)}');
    }
  }

  Future<void> _claimTask(TaskItem task) async {
    if (!_allowSelfAssign) {
      _showMessage('Self-assign is disabled in project settings.');
      return;
    }
    try {
      await TaskStore.instance.claimProjectTask(
        projectId: widget.project.id,
        taskId: task.id,
      );
      _showMessage('You claimed "${task.title}".');
    } catch (error) {
      _showMessage('Could not claim task. ${_cleanError(error)}');
    }
  }

  void _sendTaskToFocus(TaskItem task) {
    if (!TaskStore.instance.isCurrentUserLabel(task.assignee)) {
      _showMessage('Only the task owner can send this project task to Focus.');
      return;
    }
    FocusQueueStore.instance.enqueue(task);
    _showMessage('Added "${task.title}" to Focus queue.');
  }

  void _sendChatMessage(String text) async {
    if (text.isEmpty) {
      return;
    }
    try {
      await ProjectChatStore.instance.sendMessage(
        projectId: widget.project.id,
        text: text,
      );
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _sendChatAiPrompt(
    String prompt, {
    required String rawMessage,
  }) async {
    try {
      await ProjectChatStore.instance.sendMessage(
        projectId: widget.project.id,
        text: rawMessage,
      );
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Bad state: ', ''));
      return;
    }

    try {
      final response = await AskAiService.instance.ask(
        prompt: prompt,
        projectId: widget.project.id,
        projectTitle: widget.project.title,
      );
      if (!mounted) {
        return;
      }
      await ProjectChatStore.instance.sendAiMessage(
        projectId: widget.project.id,
        text: response,
      );
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  void _sendAskAi() async {
    var prompt = _askAiController.text.trim();
    if (prompt.isEmpty) {
      return;
    }

    if (prompt.toLowerCase().startsWith('/askai')) {
      prompt = prompt.substring(6).trim();
      if (prompt.isEmpty) {
        _showMessage('Ask a question directly in the workspace.');
        return;
      }
    }

    setState(() {
      _askingAi = true;
      _askAiMessages.add(_AskAiMessage(role: _AskAiRole.user, text: prompt));
      _askAiController.clear();
    });

    try {
      final response = await AskAiService.instance.ask(
        prompt: prompt,
        projectId: widget.project.id,
        projectTitle: widget.project.title,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _askAiMessages.add(
          _AskAiMessage(role: _AskAiRole.assistant, text: response),
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) {
        setState(() => _askingAi = false);
      }
    }
  }

  Future<void> _showAddStickyNoteDialog() async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Sticky Note'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Type a quick sticky note...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (note == null || note.isEmpty) {
      return;
    }

    setState(() => _stickyNotes.insert(0, note));
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) {
      return;
    }
    final fileName = result.files.first.name;
    setState(() => _savedFiles.insert(0, fileName));
    if (!mounted) {
      return;
    }
    _showMessage('Uploaded $fileName');
  }

  void _removeSticky(String note) {
    setState(() => _stickyNotes.remove(note));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('FirebaseException: ', '')
        .replaceFirst('Bad state: ', '');
  }

  Future<void> _copyInviteLink() async {
    await Clipboard.setData(ClipboardData(text: _inviteLink));
    if (!mounted) {
      return;
    }
    _showMessage('Invite link copied. Share it with your teammates.');
  }
}

class _TasksTab extends StatelessWidget {
  const _TasksTab({
    required this.tasks,
    required this.projectId,
    required this.allowSelfAssign,
    required this.loadError,
    required this.onClaimTask,
    required this.onEditTask,
    required this.onSendToFocus,
  });

  final List<TaskItem> tasks;
  final String projectId;
  final bool allowSelfAssign;
  final Object? loadError;
  final ValueChanged<TaskItem> onClaimTask;
  final ValueChanged<TaskItem> onEditTask;
  final ValueChanged<TaskItem> onSendToFocus;

  @override
  Widget build(BuildContext context) {
    if (loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Could not load project tasks. Check your permissions or connection.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    if (tasks.isEmpty) {
      return Center(
        child: Text(
          'No project tasks yet.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        for (final task in tasks)
          _ProjectTaskCard(
            task: task,
            projectId: projectId,
            allowSelfAssign: allowSelfAssign,
            onClaim: () => onClaimTask(task),
            onEdit: () => onEditTask(task),
            onSendToFocus: () => onSendToFocus(task),
          ),
      ],
    );
  }
}

class _ProjectTaskCard extends StatelessWidget {
  const _ProjectTaskCard({
    required this.task,
    required this.projectId,
    required this.allowSelfAssign,
    required this.onClaim,
    required this.onEdit,
    required this.onSendToFocus,
  });

  final TaskItem task;
  final String projectId;
  final bool allowSelfAssign;
  final VoidCallback onClaim;
  final VoidCallback onEdit;
  final VoidCallback onSendToFocus;

  @override
  Widget build(BuildContext context) {
    final isUnclaimed = task.assignee == null;
    final isMine = TaskStore.instance.isCurrentUserLabel(task.assignee);
    final ownerLabel = isUnclaimed
        ? 'Unclaimed'
        : (isMine ? 'Owner: You' : 'Owner: ${task.assignee}');

    return TaskCard(
      task: task,
      showProjectLink: false,
      canEdit: TaskStore.instance.canEdit(task),
      onEdit: onEdit,
      onEditLocked: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only the task owner can edit this task.'),
          ),
        );
      },
      onAddToFocus: onSendToFocus,
      onToggleComplete: (done) async {
        if (projectId.isEmpty) {
          return;
        }
        try {
          await TaskStore.instance.setProjectTaskCompletion(
            projectId: projectId,
            taskId: task.id,
            done: done,
          );
          FocusQueueStore.instance.markTaskCompletion(task.id, done);
        } catch (error) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Could not update task. ${error.toString().replaceFirst('Exception: ', '')}",
              ),
            ),
          );
        }
      },
      ownerLabel: ownerLabel,
      onClaim: isUnclaimed ? onClaim : null,
      canClaim: allowSelfAssign,
    );
  }
}

class _ChatTab extends StatelessWidget {
  const _ChatTab({
    required this.messageStream,
    required this.inputController,
    required this.onSendMessage,
    required this.onSendAiPrompt,
    required this.currentUserId,
  });

  final Stream<List<ProjectChatMessage>> messageStream;
  final TextEditingController inputController;
  final ValueChanged<String> onSendMessage;
  final Future<void> Function(String prompt, {required String rawMessage})
  onSendAiPrompt;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ProjectChatMessage>>(
            stream: messageStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Chat unavailable right now. Check your connection or permissions.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }

              final messages = snapshot.data ?? <ProjectChatMessage>[];
              if (messages.isEmpty) {
                return Center(
                  child: Text(
                    'No messages yet. Start the conversation.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                children: [
                  for (final message in messages)
                    Align(
                      alignment: message.senderUid == currentUserId
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 300),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: message.senderUid == currentUserId
                              ? AppColors.burntOrange.withValues(alpha: 0.15)
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardStroke),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.senderLabel,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: AppColors.burntOrange,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            if (message.senderUid == 'ai')
                              MarkdownBody(
                                data: message.text,
                                selectable: true,
                                styleSheet:
                                    MarkdownStyleSheet.fromTheme(
                                      Theme.of(context),
                                    ).copyWith(
                                      p: Theme.of(context).textTheme.bodyMedium,
                                    ),
                              )
                            else
                              Text(message.text),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: AnimatedBuilder(
                    animation: inputController,
                    builder: (context, _) {
                      final shouldHide = inputController.text
                          .toLowerCase()
                          .startsWith('/askai');
                      if (shouldHide) return const SizedBox.shrink();
                      return ActionChip(
                        avatar: const Icon(
                          Icons.auto_awesome_rounded,
                          size: 16,
                          color: AppColors.burntOrange,
                        ),
                        label: RichText(
                          text: TextSpan(
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                            children: const [
                              TextSpan(
                                text: '/askai',
                                style: TextStyle(
                                  color: AppColors.burntOrange,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              TextSpan(text: '  Ask the AI assistant'),
                            ],
                          ),
                        ),
                        backgroundColor: AppColors.burntOrange.withValues(
                          alpha: 0.10,
                        ),
                        side: const BorderSide(color: AppColors.burntOrange),
                        onPressed: () {
                          inputController.text = '/askai ';
                          inputController
                              .selection = TextSelection.fromPosition(
                            TextPosition(offset: inputController.text.length),
                          );
                        },
                      );
                    },
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: inputController,
                        decoration: InputDecoration(
                          hintText: 'Type a message or /askai to ask AI',
                          filled: true,
                          fillColor: AppColors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.cardStroke,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.cardStroke,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      onPressed: () {
                        final raw = inputController.text.trim();
                        if (raw.isEmpty) {
                          return;
                        }
                        inputController.clear();
                        if (raw.toLowerCase().startsWith('/askai')) {
                          final prompt = raw.substring(6).trim();
                          if (prompt.isEmpty) {
                            return;
                          }
                          onSendAiPrompt(prompt, rawMessage: raw);
                          return;
                        }
                        onSendMessage(raw);
                      },
                      backgroundColor: AppColors.burntOrange,
                      foregroundColor: AppColors.white,
                      child: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WorkspaceTab extends StatelessWidget {
  const _WorkspaceTab({
    required this.noteController,
    required this.stickyNotes,
    required this.savedFiles,
    required this.askAiController,
    required this.askAiMessages,
    required this.onAskAi,
    required this.askingAi,
    required this.onAddStickyNote,
    required this.onUploadFile,
    required this.onRemoveSticky,
  });

  final TextEditingController noteController;
  final List<String> stickyNotes;
  final List<String> savedFiles;
  final TextEditingController askAiController;
  final List<_AskAiMessage> askAiMessages;
  final VoidCallback onAskAi;
  final bool askingAi;
  final VoidCallback onAddStickyNote;
  final VoidCallback onUploadFile;
  final ValueChanged<String> onRemoveSticky;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Shared Notes',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: onAddStickyNote,
              icon: const Icon(Icons.sticky_note_2_outlined),
              label: const Text('New Sticky'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onUploadFile,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Upload File'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (stickyNotes.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final note in stickyNotes)
                _StickyNoteChip(
                  note: note,
                  onRemove: () => onRemoveSticky(note),
                ),
            ],
          )
        else
          Text(
            'No sticky notes yet.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: noteController,
          maxLines: 8,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            hintText: 'Write shared notes here...',
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Ask AI',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Ask the workspace directly.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        if (askAiMessages.isNotEmpty)
          Column(
            children: [
              for (final message in askAiMessages)
                Align(
                  alignment: message.role == _AskAiRole.user
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 320),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: message.role == _AskAiRole.user
                          ? AppColors.progressTrack
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardStroke),
                    ),
                    child: message.role == _AskAiRole.assistant
                        ? MarkdownBody(
                            data: message.text,
                            selectable: true,
                            styleSheet:
                                MarkdownStyleSheet.fromTheme(
                                  Theme.of(context),
                                ).copyWith(
                                  p: Theme.of(context).textTheme.bodyMedium,
                                ),
                          )
                        : Text(message.text),
                  ),
                ),
            ],
          )
        else
          Text(
            'No AI responses yet.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        if (askingAi)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: LinearProgressIndicator(minHeight: 4),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: askAiController,
                decoration: InputDecoration(
                  hintText: 'Summarize today\'s blockers',
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.cardStroke),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.cardStroke),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              onPressed: askingAi ? null : onAskAi,
              backgroundColor: AppColors.burntOrange,
              foregroundColor: AppColors.white,
              child: const Icon(Icons.auto_awesome_rounded),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Files',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (final fileName in savedFiles)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.insert_drive_file_outlined),
            title: Text(fileName),
            trailing: const Icon(Icons.download_rounded),
          ),
        if (savedFiles.isEmpty)
          Text(
            'No files uploaded yet.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
      ],
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({
    required this.members,
    required this.allowSelfAssign,
    required this.notificationsEnabled,
    required this.inviteLink,
    required this.onCopyInviteLink,
    required this.onToggleSelfAssign,
    required this.onToggleNotifications,
    required this.onRemoveMember,
  });

  final List<String> members;
  final bool allowSelfAssign;
  final bool notificationsEnabled;
  final String inviteLink;
  final VoidCallback onCopyInviteLink;
  final ValueChanged<bool> onToggleSelfAssign;
  final ValueChanged<bool> onToggleNotifications;
  final ValueChanged<String> onRemoveMember;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardStroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invite Teammates',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Share this link or QR to let people join this project quickly.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardStroke),
                  ),
                  child: QrImageView(
                    data: inviteLink,
                    size: 142,
                    backgroundColor: AppColors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SelectableText(
                inviteLink,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onCopyInviteLink,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.burntOrange,
                    foregroundColor: AppColors.white,
                  ),
                  icon: const Icon(Icons.copy_all_rounded),
                  label: const Text('Copy Invite Link'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardStroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Project Preferences',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: allowSelfAssign,
                onChanged: onToggleSelfAssign,
                title: const Text('Allow members to claim unclaimed tasks'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: notificationsEnabled,
                onChanged: onToggleNotifications,
                title: const Text('Notifications for task updates'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Members',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (members.isEmpty)
          Text(
            'No members left in this project.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          )
        else
          for (final member in members)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.progressTrack,
                child: Text(member.characters.first),
              ),
              title: Text(member),
              trailing: TaskStore.instance.isCurrentUserLabel(member)
                  ? const Text('You')
                  : IconButton(
                      icon: const Icon(Icons.person_remove_alt_1_outlined),
                      onPressed: () => onRemoveMember(member),
                    ),
            ),
      ],
    );
  }
}

class _StickyNoteChip extends StatelessWidget {
  const _StickyNoteChip({required this.note, required this.onRemove});

  final String note;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.mustardYellow.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Text(
              note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 16),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

enum _AskAiRole { user, assistant }

class _AskAiMessage {
  const _AskAiMessage({required this.role, required this.text});

  final _AskAiRole role;
  final String text;
}

class _AskAiHighlightController extends TextEditingController {
  static final RegExp _pattern = RegExp(r'^/askai\b', caseSensitive: false);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final match = _pattern.firstMatch(text);
    if (match == null) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final highlightStyle = (style ?? const TextStyle()).copyWith(
      color: AppColors.burntOrange,
      fontWeight: FontWeight.w800,
      backgroundColor: AppColors.burntOrange.withValues(alpha: 0.12),
    );
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: text.substring(0, match.end), style: highlightStyle),
        TextSpan(text: text.substring(match.end)),
      ],
    );
  }
}
