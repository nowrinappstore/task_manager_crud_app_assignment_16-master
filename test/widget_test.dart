import 'package:flutter_test/flutter_test.dart';

import 'package:task_manager_crud_app/models/task_model.dart';
import 'package:task_manager_crud_app/services/notification_service.dart';

void main() {
  test('TaskModel.fromJson reads priority and completed status', () {
    final task = TaskModel.fromJson({
      'id': 'abc',
      'title': 'Complete Flutter Assignment',
      'description': 'Firebase push + local notification',
      'priority': 'high',
      'isCompleted': true,
    });

    expect(task.id, 'abc');
    expect(task.priority, TaskPriority.high);
    expect(task.isCompleted, isTrue);
    expect(task.dueDate, isNull);
  });

  test('notificationIdFor is positive and stable', () {
    final first = NotificationService.notificationIdFor('task-123');
    final second = NotificationService.notificationIdFor('task-123');

    expect(first, second);
    expect(first, greaterThan(0));
  });
}
