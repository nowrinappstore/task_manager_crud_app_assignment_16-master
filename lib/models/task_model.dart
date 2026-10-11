import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskPriority { low, medium, high }

class TaskModel {
  final String id;
  final String title;
  final String description;
  final bool isCompleted;
  final TaskPriority priority;
  final DateTime? dueDate;
  final DateTime? createdAt;

  const TaskModel({
    required this.id,
    required this.title,
    required this.description,
    this.isCompleted = false,
    this.priority = TaskPriority.medium,
    this.dueDate,
    this.createdAt,
  });

  // Convert a Firestore document to TaskModel
  factory TaskModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return TaskModel.fromJson({...?doc.data(), 'id': doc.id});
  }

  // Convert JSON to TaskModel
  factory TaskModel.fromJson(Map<String, dynamic> json) {
    final completedValue = json['completed'] ?? json['isCompleted'] ?? false;

    final priorityValue =
        json['priority']?.toString().toLowerCase() ?? 'medium';

    return TaskModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),

      title: (json['title'] ?? '').toString(),

      description: (json['description'] ?? '').toString(),

      isCompleted:
          completedValue == true ||
          completedValue == 1 ||
          completedValue.toString().toLowerCase() == 'true',

      priority: TaskPriority.values.firstWhere(
        (value) => value.name == priorityValue,
        orElse: () => TaskPriority.medium,
      ),

      dueDate: _parseDate(json['dueDate'] ?? json['due_date']),

      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
    );
  }

  // Parse date safely
  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value == null || value.toString().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }

  // Convert TaskModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'completed': isCompleted,
      'priority': priority.name,
      'dueDate': dueDate?.toUtc().toIso8601String(),
      'createdAt': createdAt?.toUtc().toIso8601String(),
    };
  }

  // Copy TaskModel with updated values
  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    TaskPriority? priority,
    DateTime? dueDate,
    DateTime? createdAt,
    bool clearDueDate = false,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
