import 'package:flutter/material.dart';

class AppNavigator {
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  /// Task ID waiting to be opened (set when a notification is tapped).
  /// HomeScreen listens to this and opens the matching task.
  static final ValueNotifier<String?> pendingTaskId = ValueNotifier<String?>(
    null,
  );

  /// Called when the user taps a notification (push or local).
  /// Goes back to the Task List screen and, if a task ID is given,
  /// asks the Task List to open that task.
  static void openTask(String? taskId) {
    key.currentState?.popUntil((route) => route.isFirst);

    if (taskId == null || taskId.isEmpty) return;

    pendingTaskId.value = null;
    pendingTaskId.value = taskId;
  }
}
