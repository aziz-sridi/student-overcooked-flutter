import 'dart:collection';

import 'package:flutter/material.dart';

import '../../data/subject_store.dart';
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
  String? _selectedSubject;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );
    final initialSubject = widget.existing?.subject ??
        (widget.fixedProjectId != null
            ? (widget.fixedProjectTitle ?? widget.fixedSubject ?? '')
            : (widget.fixedSubject ?? ''));
    _subjectController = TextEditingController(text: initialSubject);
    _selectedSubject = initialSubject.isEmpty ? null : initialSubject;
    _dueAt =
        widget.existing?.dueAt ?? DateTime.now().add(const Duration(days: 1));
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
    final memberOptions = LinkedHashSet<String?>();
    memberOptions.add(null);
    memberOptions.addAll(widget.members);
    if (_assignee != null && _assignee!.isNotEmpty) {
      memberOptions.add(_assignee);
    }

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
            if (widget.fixedProjectId == null)
              _SubjectPicker(
                fixedSubject: widget.fixedSubject,
                selected: _selectedSubject,
                onChanged: (value) {
                  setState(() {
                    _selectedSubject = value;
                    _subjectController.text = value ?? '';
                  });
                },
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Linked project'),
                subtitle: Text(widget.fixedProjectTitle ?? 'Project task'),
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
                DropdownMenuItem(
                  value: TaskPriority.medium,
                  child: Text('Medium'),
                ),
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
                items: memberOptions.map((member) {
                  if (member == null) {
                    return const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Unclaimed'),
                    );
                  }
                  return DropdownMenuItem<String?>(
                    value: member,
                    child: Text(member),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _assignee = value),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
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
      _dueAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        _dueAt.hour,
        _dueAt.minute,
      );
    });
  }

  void _save() {
    final title = _titleController.text.trim();
    final subject = widget.fixedProjectId != null
        ? (widget.existing?.subject.trim().isNotEmpty == true
            ? widget.existing!.subject.trim()
            : (widget.fixedProjectTitle ?? widget.fixedSubject ?? '').trim())
        : _subjectController.text.trim();
    if (title.isEmpty || subject.isEmpty) {
      return;
    }

    final task = TaskItem(
      id:
          widget.existing?.id ??
          'task-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      subject: subject,
      dueAt: _dueAt,
      priority: _priority,
      state: widget.existing?.state ?? TaskState.notStarted,
      projectId: widget.fixedProjectId ?? widget.existing?.projectId,
      projectTitle: widget.fixedProjectTitle ?? widget.existing?.projectTitle,
      assignee: widget.allowAssigneeEditing
          ? _assignee
          : (widget.existing?.assignee ?? 'You'),
      completed: widget.existing?.completed ?? false,
    );

    Navigator.pop(context, task);
  }
}

class _SubjectPicker extends StatelessWidget {
  const _SubjectPicker({
    required this.fixedSubject,
    required this.selected,
    required this.onChanged,
  });

  final String? fixedSubject;
  final String? selected;
  final ValueChanged<String?> onChanged;

  static const _addNewSentinel = '__add_new__';

  @override
  Widget build(BuildContext context) {
    if (fixedSubject != null) {
      return TextField(
        enabled: false,
        controller: TextEditingController(text: fixedSubject),
        decoration: const InputDecoration(labelText: 'Subject'),
      );
    }

    return ValueListenableBuilder<List<String>>(
      valueListenable: SubjectStore.instance.subjects,
      builder: (context, subjects, _) {
        final options = LinkedHashSet<String>();
        if (selected != null && selected!.isNotEmpty) {
          options.add(selected!);
        }
        options.addAll(subjects);

        return DropdownButtonFormField<String>(
          initialValue: options.contains(selected) ? selected : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Subject'),
          hint: const Text('Choose a subject'),
          items: [
            for (final subject in options)
              DropdownMenuItem<String>(
                value: subject,
                child: Text(subject, overflow: TextOverflow.ellipsis),
              ),
            const DropdownMenuItem<String>(
              value: _addNewSentinel,
              child: Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Add new subject…'),
                ],
              ),
            ),
          ],
          onChanged: (value) async {
            if (value == _addNewSentinel) {
              final created = await _promptForNewSubject(context);
              if (created != null && created.isNotEmpty) {
                await SubjectStore.instance.addSubject(created);
                onChanged(created);
              }
              return;
            }
            onChanged(value);
          },
        );
      },
    );
  }

  Future<String?> _promptForNewSubject(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('New subject'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Subject name',
              hintText: 'e.g. Calculus',
            ),
            onSubmitted: (value) =>
                Navigator.of(dialogContext).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null || result.isEmpty) return null;
    return result;
  }
}
