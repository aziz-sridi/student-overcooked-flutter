import 'package:flutter/material.dart';

import '../models/task_item.dart';

class FocusQueueStore {
  FocusQueueStore._();

  static final FocusQueueStore instance = FocusQueueStore._();

  final ValueNotifier<List<TaskItem>> queue = ValueNotifier<List<TaskItem>>([]);
  final ValueNotifier<Set<String>> completedTaskIds =
      ValueNotifier<Set<String>>({});

  TaskItem applyFocusState(TaskItem task) {
    if (completedTaskIds.value.contains(task.id)) {
      return task.copyWith(state: TaskState.done, completed: true);
    }
    return task;
  }

  void enqueue(TaskItem task) {
    final exists = queue.value.any((item) => item.id == task.id);
    if (exists) {
      return;
    }
    queue.value = [...queue.value, applyFocusState(task)];
  }

  void remove(String taskId) {
    queue.value = queue.value.where((task) => task.id != taskId).toList();
  }

  void markTaskCompletion(String taskId, bool done) {
    final updated = Set<String>.from(completedTaskIds.value);
    if (done) {
      updated.add(taskId);
    } else {
      updated.remove(taskId);
    }
    completedTaskIds.value = updated;

    queue.value = queue.value
        .map(
          (task) => task.id == taskId
              ? task.copyWith(
                  state: done ? TaskState.done : TaskState.notStarted,
                  completed: done,
                )
              : task,
        )
        .toList();
  }
}
