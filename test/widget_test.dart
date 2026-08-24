import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studentovercoocked/models/task_item.dart';
import 'package:studentovercoocked/widgets/cards/task_card.dart';
import 'package:studentovercoocked/widgets/common/app_top_bar.dart';

void main() {
  testWidgets('task completion requires confirmation on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    bool? completion;
    final task = TaskItem(
      id: 'task-1',
      title: 'A very long assignment title that must fit on a narrow phone',
      subject: 'Introduction to Computer Science',
      dueAt: DateTime.now().add(const Duration(hours: 3)),
      priority: TaskPriority.high,
      state: TaskState.notStarted,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskCard(
            task: task,
            onToggleComplete: (value) => completion = value,
            onEdit: () {},
            onAddToFocus: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(find.text('Mark this task complete?'), findsOneWidget);
    expect(completion, isNull);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(completion, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark complete'));
    await tester.pumpAndSettle();

    expect(completion, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared top bar keeps a long title on one line', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SafeArea(child: AppTopBar(title: 'Student Overcooked')),
        ),
      ),
    );

    expect(find.text('Student Overcooked'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
