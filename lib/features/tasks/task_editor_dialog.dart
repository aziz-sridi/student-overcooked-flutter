import 'package:flutter/material.dart';

import '../../models/task_item.dart';

Future<TaskItem?> showTaskEditorDialog(
  BuildContext context, {
  TaskItem? existing,
  String? fixedSubject,
  String? fixedProjectId,
  String? fixedProjectTitle,
  bool allowAssigneeEditing = false,
  List<String> members = const <String>[],
}) async {
  return showDialog<TaskItem>(
    context: context,
    builder: (context) => _TaskEditorDialog(
      existing: existing,
      fixedSubject: fixedSubject,
      fixedProjectId: fixedProjectId,
      fixedProjectTitle: fixedProjectTitle,
      allowAssigneeEditing: allowAssigneeEditing,
      members: members,
    ),
  );
}

class _TaskEditorDialog extends StatefulWidget {
  const _TaskEditorDialog({
    this.existing,
    this.fixedSubject,
    this.fixedProjectId,
    this.fixedProjectTitle,
    required this.allowAssigneeEditing,
    required this.members,
  });

  final TaskItem? existing;
  final String? fixedSubject;
  final String? fixedProjectId;
  final String? fixedProjectTitle;
  final bool allowAssigneeEditing;
  final List<String> members;

  @override
  State<_TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<_TaskEditorDialog> {
  late TextEditingController _titleController;
  late TextEditingController _subjectController;
  late DateTime _dueAt;
  late TaskPriority _priority;
  String? _assignee;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existing?.title ?? '');
    _subjectController = TextEditingController(text: widget.existing?.subject ?? widget.fixedSubject ?? '');
    _dueAt = widget.existing?.dueAt ?? DateTime.now().add(const Duration(days: 1));
    _priority = widget.existing?.priority ?? TaskPriority.medium;
    _assignee = widget.existing?.assignee;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Create Task' : 'Edit Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Task title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _subjectController,
              enabled: widget.fixedSubject == null,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Due date'),
              subtitle: Text(
                '${_dueAt.year}-${_dueAt.month.toString().padLeft(2, '0')}-${_dueAt.day.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.calendar_today_rounded, size: 18),
              onTap: _pickDate,
            ),
            DropdownButtonFormField<TaskPriority>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: const [
                DropdownMenuItem(value: TaskPriority.low, child: Text('Low')),
                DropdownMenuItem(value: TaskPriority.medium, child: Text('Medium')),
                DropdownMenuItem(value: TaskPriority.high, child: Text('High')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _priority = value);
                }
              },
            ),
            if (widget.allowAssigneeEditing) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: _assignee,
                decoration: const InputDecoration(labelText: 'Owner'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Unclaimed')),
                  ...widget.members
                      .map((member) => DropdownMenuItem<String?>(value: member, child: Text(member))),
                ],
                onChanged: (value) => setState(() => _assignee = value),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _save,
          child: Text(widget.existing == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime(2024),
      lastDate: DateTime(2032),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _dueAt = DateTime(selected.year, selected.month, selected.day, _dueAt.hour, _dueAt.minute);
    });
  }

  void _save() {
    final title = _titleController.text.trim();
    final subject = _subjectController.text.trim();
    if (title.isEmpty || subject.isEmpty) {
      return;
    }

    final task = TaskItem(
      id: widget.existing?.id ?? 'task-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      subject: subject,
      dueAt: _dueAt,
      priority: _priority,
      state: widget.existing?.state ?? TaskState.notStarted,
      projectId: widget.fixedProjectId ?? widget.existing?.projectId,
      projectTitle: widget.fixedProjectTitle ?? widget.existing?.projectTitle,
      assignee: widget.allowAssigneeEditing ? _assignee : (widget.existing?.assignee ?? 'You'),
      completed: widget.existing?.completed ?? false,
    );

    Navigator.pop(context, task);
  }
}
