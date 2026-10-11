import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/task_model.dart';

/// Stores tasks in Cloud Firestore:  users/{uid}/tasks/{taskId}
class TaskService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Please login first.');
    }

    return _db.collection('users').doc(user.uid).collection('tasks');
  }

  // `dueDate` is passed as DateTime? and stored as a Firestore Timestamp.
  Map<String, dynamic> _toDoc(Map<String, dynamic> data) {
    final out = Map<String, dynamic>.from(data);

    if (out.containsKey('dueDate')) {
      final due = out['dueDate'];
      out['dueDate'] = due is DateTime ? Timestamp.fromDate(due) : null;
    }

    return out;
  }

  // Real-time list of tasks (newest first)
  Stream<List<TaskModel>> watchTasks() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(TaskModel.fromDoc).toList());
  }

  // Get a single task (used when a notification is tapped)
  Future<TaskModel?> getTask(String id) async {
    final doc = await _col.doc(id).get();

    return doc.exists ? TaskModel.fromDoc(doc) : null;
  }

  // Create a task and return its document ID
  Future<String> createTask(Map<String, dynamic> data) async {
    final ref = await _col.add({
      ..._toDoc(data),
      'isCompleted': data['isCompleted'] ?? false,
      'createdAt': Timestamp.now(),
    });

    return ref.id;
  }

  // Update some fields of a task
  Future<void> updateTask(String id, Map<String, dynamic> data) {
    return _col.doc(id).update(_toDoc(data));
  }

  // Delete a task
  Future<void> deleteTask(String id) {
    return _col.doc(id).delete();
  }
}
