import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_navigator.dart';
import '../models/task_model.dart';
import '../services/auth_services.dart';
import '../services/notification_lab_screen.dart';
import '../services/notification_service.dart';
import '../services/push_service.dart';
import '../services/task_services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TaskService _service = TaskService();
  final AuthService _auth = AuthService();
  final TextEditingController _searchController = TextEditingController();

  List<TaskModel> _tasks = [];

  bool _loading = true;
  bool _saving = false;

  String _filter = 'all';
  String _query = '';

  static const Color _primary = Colors.indigo;

  StreamSubscription<List<TaskModel>>? _sub;

  @override
  void initState() {
    super.initState();

    _listen();

    // Save this device's FCM token in Firestore (users/{uid}.fcmToken)
    PushService.saveTokenForCurrentUser();

    // Open a task when its notification is tapped
    AppNavigator.pendingTaskId.addListener(_onPendingTask);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPendingTask());
  }

  @override
  void dispose() {
    AppNavigator.pendingTaskId.removeListener(_onPendingTask);
    _sub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // NOTIFICATION ID
  // --------------------------------------------------

  int _nid(TaskModel task) {
    return NotificationService.notificationIdFor(task.id);
  }

  // --------------------------------------------------
  // LOAD TASKS
  // --------------------------------------------------

  // Real-time updates from Cloud Firestore
  void _listen() {
    _sub?.cancel();

    _sub = _service.watchTasks().listen(
      (tasks) {
        if (!mounted) return;

        setState(() {
          _tasks = tasks;
          _loading = false;
        });
      },
      onError: (Object e) {
        if (!mounted) return;

        setState(() {
          _loading = false;
        });

        _toast('Task load failed: $e');
      },
    );
  }

  // Pull-to-refresh: Firestore is real-time, so just re-attach the listener.
  Future<void> _load() async {
    _listen();

    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  // --------------------------------------------------
  // NOTIFICATION TAP -> OPEN TASK
  // --------------------------------------------------

  void _onPendingTask() {
    final id = AppNavigator.pendingTaskId.value;

    if (id == null || id.isEmpty) return;

    AppNavigator.pendingTaskId.value = null;

    _openTaskById(id);
  }

  Future<void> _openTaskById(String id) async {
    try {
      final task = await _service.getTask(id);

      if (task != null && mounted) {
        await _openForm(task);
      }
    } catch (e) {
      debugPrint('Could not open task from notification: $e');
    }
  }

  Future<void> _copyToken() async {
    final token = await PushService.getToken();

    if (token == null || token.isEmpty) {
      _toast('FCM token not available yet');
      return;
    }

    await Clipboard.setData(ClipboardData(text: token));

    _toast('FCM token copied');
  }

  // --------------------------------------------------
  // SNACKBAR
  // --------------------------------------------------

  void _toast(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // --------------------------------------------------
  // FILTER
  // --------------------------------------------------

  List<TaskModel> get _visible {
    return _tasks.where((task) {
      final matchesQuery = task.title.toLowerCase().contains(
        _query.toLowerCase(),
      );

      final matchesFilter =
          _filter == 'all' ||
          (_filter == 'active' && !task.isCompleted) ||
          (_filter == 'done' && task.isCompleted);

      return matchesQuery && matchesFilter;
    }).toList();
  }

  int get _doneCount => _tasks.where((task) => task.isCompleted).length;

  int get _activeCount => _tasks.where((task) => !task.isCompleted).length;

  // --------------------------------------------------
  // PRIORITY
  // --------------------------------------------------

  Color _priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.green;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.high:
        return Colors.red;
    }
  }

  String _priorityLabel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }

  // --------------------------------------------------
  // DATE AND TIME
  // --------------------------------------------------

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;

    return '$day/$month/$year';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;

    return '$displayHour:$minute $period';
  }

  String _dueText(DateTime date) {
    final localDate = date.toLocal();

    return '${_formatDate(localDate)} '
        '${_formatTime(localDate)}';
  }

  // --------------------------------------------------
  // ADD / EDIT TASK
  // --------------------------------------------------

  Future<void> _openForm([TaskModel? task]) async {
    if (_saving) return;

    final titleController = TextEditingController(text: task?.title ?? '');

    final descriptionController = TextEditingController(
      text: task?.description ?? '',
    );

    TaskPriority priority = task?.priority ?? TaskPriority.medium;

    DateTime? due = task?.dueDate?.toLocal();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                task == null ? 'নতুন টাস্ক' : 'টাস্ক এডিট',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        prefixIcon: const Icon(Icons.task_alt),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        alignLabelWithHint: true,
                        prefixIcon: const Icon(Icons.description),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Priority',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<TaskPriority>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment<TaskPriority>(
                            value: TaskPriority.low,
                            label: Text('Low'),
                          ),
                          ButtonSegment<TaskPriority>(
                            value: TaskPriority.medium,
                            label: Text('Medium'),
                          ),
                          ButtonSegment<TaskPriority>(
                            value: TaskPriority.high,
                            label: Text('High'),
                          ),
                        ],
                        selected: {priority},
                        onSelectionChanged: (selection) {
                          setDialogState(() {
                            priority = selection.first;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Reminder',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_month, size: 18),
                            label: Text(
                              due == null ? 'Pick date' : _formatDate(due!),
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () async {
                              final now = DateTime.now();

                              final initialDate = due ?? now;

                              final selectedDate = await showDatePicker(
                                context: dialogContext,
                                initialDate: initialDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );

                              if (selectedDate == null) {
                                return;
                              }

                              final existingTime = due != null
                                  ? TimeOfDay.fromDateTime(due!)
                                  : TimeOfDay.now();

                              setDialogState(() {
                                due = DateTime(
                                  selectedDate.year,
                                  selectedDate.month,
                                  selectedDate.day,
                                  existingTime.hour,
                                  existingTime.minute,
                                );
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time, size: 18),
                            label: Text(
                              due == null ? 'Pick time' : _formatTime(due!),
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () async {
                              final selectedTime = await showTimePicker(
                                context: dialogContext,
                                initialTime: due != null
                                    ? TimeOfDay.fromDateTime(due!)
                                    : TimeOfDay.now(),
                              );

                              if (selectedTime == null) {
                                return;
                              }

                              final currentDate = due ?? DateTime.now();

                              setDialogState(() {
                                due = DateTime(
                                  currentDate.year,
                                  currentDate.month,
                                  currentDate.day,
                                  selectedTime.hour,
                                  selectedTime.minute,
                                );
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    if (due != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              due = null;
                            });
                          },
                          icon: const Icon(Icons.clear, size: 18),
                          label: const Text('Clear reminder'),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),

              ],
            );
          },

        );
      },
    );

    if (saved != true) {
      titleController.dispose();
      descriptionController.dispose();
      return;
    }

    final title = titleController.text.trim();
    final description = descriptionController.text.trim();

    if (title.isEmpty) {
      _toast('Task title দিন');

      titleController.dispose();
      descriptionController.dispose();
      return;
    }

    if (due != null && !due!.isAfter(DateTime.now())) {
      _toast('ভবিষ্যতের তারিখ ও সময় নির্বাচন করুন');

      titleController.dispose();
      descriptionController.dispose();
      return;
    }

    final data = <String, dynamic>{
      'title': title,
      'description': description,
      'priority': priority.name,
      'dueDate': due,
    };

    setState(() {
      _saving = true;
    });

    try {
      if (task == null) {
        final newId = await _service.createTask(data);

        if (due != null) {
          await NotificationService.scheduleTaskNotification(
            id: NotificationService.notificationIdFor(newId),
            title: title,
            scheduledDate: due!,
            taskId: newId,
            priority: priority.name,
          );
        }

        _toast('Task তৈরি হয়েছে');
      } else {
        await _service.updateTask(task.id, {
          ...data,
          'isCompleted': task.isCompleted,
        });

        await NotificationService.cancelTaskNotification(id: _nid(task));

        if (due != null && !task.isCompleted) {
          await NotificationService.scheduleTaskNotification(
            id: _nid(task),
            title: title,
            scheduledDate: due!,
            taskId: task.id,
            priority: priority.name,
          );
        }

        _toast('Task update হয়েছে');
      }
    } catch (e) {
      _toast('Save failed: $e');
    } finally {
      titleController.dispose();
      descriptionController.dispose();

      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // --------------------------------------------------
  // COMPLETE / ACTIVE
  // --------------------------------------------------

  Future<void> _toggle(TaskModel task) async {
    if (_saving) return;

    final completed = !task.isCompleted;

    try {
      await _service.updateTask(task.id, {'isCompleted': completed});

      if (completed) {
        await NotificationService.cancelTaskNotification(id: _nid(task));

        _toast('Task completed');
      } else {
        final due = task.dueDate;

        if (due != null && due.isAfter(DateTime.now())) {
          await NotificationService.scheduleTaskNotification(
            id: _nid(task),
            title: task.title,
            scheduledDate: due,
            taskId: task.id,
            priority: task.priority.name,
          );
        }
      }
    } catch (e) {
      _toast('Update failed: $e');
    }
  }

  // --------------------------------------------------
  // DELETE
  // --------------------------------------------------

  Future<void> _delete(TaskModel task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 36),
          title: const Text('ডিলিট করবেন?'),
          content: Text(task.title, textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _service.deleteTask(task.id);

      await NotificationService.cancelTaskNotification(id: _nid(task));

      if (!mounted) return;

      setState(() {
        _tasks.removeWhere((item) => item.id == task.id);
      });

      _toast('Task deleted');
    } catch (e) {
      _toast('Delete failed: $e');
    }
  }

  // --------------------------------------------------
  // LOGOUT
  // --------------------------------------------------

  Future<void> _logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      _toast('Logout failed: $e');
    }
  }

  // --------------------------------------------------
  // HEADER
  // --------------------------------------------------

  Widget _buildHeader() {
    final user = _auth.currentUser;
    final name = user?.displayName ?? user?.email ?? 'User';

    final total = _tasks.length;
    final done = _doneCount;
    final progress = total == 0 ? 0.0 : done / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.indigo.shade700, Colors.indigo.shade400],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello, $name',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            total == 0
                ? 'এখনো কোনো টাস্ক নেই'
                : '$_activeCount টি টাস্ক বাকি আছে',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$done / $total completed',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // SEARCH
  // --------------------------------------------------

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _query = value;
          });
        },
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();

                    setState(() {
                      _query = '';
                    });
                  },
                ),
          hintText: 'Search tasks',
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // FILTER CHIP
  // --------------------------------------------------

  Widget _filterChip(String key, String label, IconData icon, int count) {
    final selected = _filter == key;

    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? _primary : Colors.grey.shade600,
      ),
      label: Text('$label · $count'),
      selected: selected,
      showCheckmark: false,
      selectedColor: Colors.indigo.shade100,
      backgroundColor: Colors.white,
      side: BorderSide.none,
      onSelected: (_) {
        setState(() {
          _filter = key;
        });
      },
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _filterChip('all', 'All', Icons.list_alt, _tasks.length),
          const SizedBox(width: 8),
          _filterChip('active', 'Active', Icons.pending_actions, _activeCount),
          const SizedBox(width: 8),
          _filterChip('done', 'Done', Icons.task_alt, _doneCount),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // INFO CHIP
  // --------------------------------------------------

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // EMPTY STATE
  // --------------------------------------------------

  Widget _buildEmpty() {
    final searching = _query.isNotEmpty || _filter != 'all';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Icon(
          searching ? Icons.search_off : Icons.checklist_rounded,
          size: 72,
          color: Colors.indigo.shade200,
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            searching ? 'কিছু পাওয়া যায়নি' : 'কোনো টাস্ক নেই',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            searching
                ? 'সার্চ বা ফিল্টার বদলে দেখুন'
                : 'নতুন টাস্ক যোগ করতে নিচের বাটনে চাপুন',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------
  // TASK CARD
  // --------------------------------------------------

  Widget _buildTaskCard(TaskModel task) {
    final color = _priorityColor(task.priority);
    final due = task.dueDate?.toLocal();

    final overdue =
        due != null && !task.isCompleted && due.isBefore(DateTime.now());

    return Dismissible(
      key: ValueKey('task_${task.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _delete(task);
        return false;
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  color: task.isCompleted ? Colors.grey.shade300 : color,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: task.isCompleted,
                          shape: const CircleBorder(),
                          onChanged: _saving ? null : (_) => _toggle(task),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: task.isCompleted
                                        ? Colors.grey
                                        : Colors.black87,
                                    decoration: task.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                if (task.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    task.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _infoChip(
                                      Icons.flag,
                                      _priorityLabel(task.priority),
                                      task.isCompleted ? Colors.grey : color,
                                    ),
                                    if (due != null)
                                      _infoChip(
                                        overdue
                                            ? Icons.warning_amber_rounded
                                            : Icons.schedule,
                                        _dueText(due),
                                        task.isCompleted
                                            ? Colors.grey
                                            : overdue
                                            ? Colors.red
                                            : _primary,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert,
                            color: Colors.grey.shade600,
                          ),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _openForm(task);
                            } else if (value == 'delete') {
                              _delete(task);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.edit),
                                title: Text('Edit'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                title: Text('Delete'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // BUILD
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final list = _visible;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'My Tasks',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: 'Notification Lab',
            icon: const Icon(Icons.notifications_active),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationLabScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Copy FCM token',
            icon: const Icon(Icons.vpn_key_outlined),
            onPressed: _copyToken,
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add task'),
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildSearch(),
          _buildFilters(),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: list.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(top: 4, bottom: 90),
                            itemCount: list.length,
                            itemBuilder: (_, index) =>
                                _buildTaskCard(list[index]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
