import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:simple_infinite_scroll/simple_infinite_scroll.dart';

import '../models/TodoModel.dart';

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  static const _pageSize = 12;
  static const _initialPage = 1;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SimpleInfiniteScrollController _scrollController =
      SimpleInfiniteScrollController();
  final TextEditingController _taskController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('MMM d, y • h:mm a');

  @override
  void dispose() {
    _scrollController.dispose();
    _taskController.dispose();
    super.dispose();
  }

  Future<List<ToDo>?> _fetchTodos(int page, int limit) async {
    try {
      Query query = _firestore
          .collection('todos')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (page > _initialPage) {
        final snapshot = await _firestore
            .collection('todos')
            .orderBy('createdAt', descending: true)
            .limit((page - 1) * limit)
            .get();

        if (snapshot.docs.isNotEmpty) {
          query = query.startAfterDocument(snapshot.docs.last);
        }
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => ToDo.fromDocument(doc)).toList();
    } catch (e) {
      debugPrint("Error fetching todos: $e");
      return null;
    }
  }

  Future<void> _toggleTodo(ToDo todo) async {
    try {
      final newStatus = !todo.isDone;
      await _firestore.collection('todos').doc(todo.id).update({
        'isDone': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      setState(() => todo.isDone = newStatus);
    } catch (e) {
      debugPrint("Error updating todo: $e");
      _showErrorSnackbar("Failed to update task");
    }
  }

  Future<void> _addTask() async {
    final taskName = _taskController.text.trim();
    if (taskName.isEmpty) return;

    try {
      await _firestore.collection('todos').add({
        'title': taskName,
        'isDone': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _taskController.clear();
      if (mounted) {
        Navigator.pop(context);
        _scrollController.refresh();
      }
    } catch (e) {
      debugPrint("Error adding task: $e");
      if (mounted) {
        _showErrorSnackbar("Failed to add task");
      }
    }
  }

  Future<void> _deleteTodo(ToDo todo) async {
    try {
      await _firestore.collection('todos').doc(todo.id).delete();
      if (mounted) {
        _scrollController.refresh();
      }
    } catch (e) {
      debugPrint("Error deleting todo: $e");
      if (mounted) {
        _showErrorSnackbar("Failed to delete task");
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // void _showAddTaskSheet() {
  //   WoltModalSheet.show<void>(
  //     context: context,
  //     pageListBuilder: (modalSheetContext) {
  //       final textTheme = Theme.of(context).textTheme;
  //       return [
  //         WoltModalSheetPage(
  //           hasSabGradient: false,
  //           isTopBarLayerAlwaysVisible: true,
  //           topBarTitle: Text('Add Task', style: textTheme.titleMedium),
  //           trailingNavBarWidget: IconButton(
  //             icon: const Icon(Icons.close),
  //             onPressed: () => Navigator.of(modalSheetContext).pop(),
  //           ),
  //           stickyActionBar: Padding(
  //             padding: const EdgeInsets.all(16),
  //             child: Row(
  //               children: [
  //                 Expanded(
  //                   child: OutlinedButton(
  //                     onPressed: () => Navigator.of(modalSheetContext).pop(),
  //                     child: const Text('Cancel'),
  //                   ),
  //                 ),
  //                 const SizedBox(width: 16),
  //                 Expanded(
  //                   child: ElevatedButton(
  //                     onPressed: _addTask,
  //                     child: const Text('Add Task'),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //           child: Padding(
  //             padding: EdgeInsets.only(
  //               left: 16,
  //               right: 16,
  //               top: 24,
  //               bottom: MediaQuery.of(modalSheetContext).viewInsets.bottom + 24,
  //             ),
  //             child: Column(
  //               mainAxisSize: MainAxisSize.min,
  //               children: [
  //                 TextField(
  //                   controller: _taskController,
  //                   decoration: InputDecoration(
  //                     labelText: "Task Name",
  //                     border: OutlineInputBorder(
  //                       borderRadius: BorderRadius.circular(12),
  //                     ),
  //                     filled: true,
  //                     fillColor: Theme.of(context).colorScheme.surfaceVariant,
  //                   ),
  //                   autofocus: true,
  //                   textInputAction: TextInputAction.done,
  //                   onSubmitted: (_) => _addTask(),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //       ];
  //     },
  //     modalTypeBuilder: (context) {
  //       final width = MediaQuery.of(context).size.width;
  //       return width < 768
  //           ? const WoltBottomSheetType()
  //           : const WoltDialogType();
  //     },
  //   );
  // }

  void _showAddTaskSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add New Task',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _taskController,
                decoration: InputDecoration(
                  labelText: "Task Name",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceVariant,
                ),
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addTask(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _addTask,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Add Task'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTodoItem(ToDo todo) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Dismissible(
        key: Key(todo.id),
        background: Container(
          decoration: BoxDecoration(
            color: Colors.red.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: Colors.red),
        ),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          return await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Confirm Delete"),
              content: const Text("Are you sure you want to delete this task?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child:
                      const Text("Delete", style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        },
        onDismissed: (direction) => _deleteTodo(todo),
        child: InkWell(
          onTap: () => _showEditTaskSheet(todo),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: todo.isDone,
                      onChanged: (value) => _toggleTodo(todo),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        todo.title,
                        style: TextStyle(
                          fontSize: 16,
                          decoration: todo.isDone
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          color: todo.isDone ? Colors.grey : null,
                          fontWeight:
                              todo.isDone ? FontWeight.normal : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const SizedBox(width: 40), // Align with checkbox
                    Text(
                      _dateFormat.format(todo.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditTaskSheet(ToDo todo) {
    _taskController.text = todo.title;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Edit Task',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _taskController,
                decoration: InputDecoration(
                  labelText: "Task Name",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceVariant,
                ),
                autofocus: true,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final newTitle = _taskController.text.trim();
                        if (newTitle.isNotEmpty) {
                          try {
                            await _firestore
                                .collection('todos')
                                .doc(todo.id)
                                .update({
                              'title': newTitle,
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                            _taskController.clear();
                            if (mounted) {
                              Navigator.pop(context);
                              _scrollController.refresh();
                            }
                          } catch (e) {
                            debugPrint("Error updating task: $e");
                            if (mounted) {
                              _showErrorSnackbar("Failed to update task");
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("Update Task"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo List',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () => _showSortOptions(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SimpleInfiniteScroll<ToDo>(
            controller: _scrollController,
            initialPage: _initialPage,
            limit: _pageSize,
            fetch: _fetchTodos,
            loadingWidget: const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            emptyWidget: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    "No tasks yet!",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tap the + button to add a new task",
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            refreshIndicatorStyle: RefreshIndicatorStyle(
              color: Theme.of(context).colorScheme.primary,
              displacement: 40.0,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            ),
            itemBuilder: (context, index, todo) => _buildTodoItem(todo),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskSheet,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Sort By',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.sort_by_alpha),
                title: const Text('Alphabetical (A-Z)'),
                onTap: () {
                  Navigator.pop(context);
                  _scrollController.refresh();
                },
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Recent First'),
                onTap: () {
                  Navigator.pop(context);
                  _scrollController.refresh();
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Completed First'),
                onTap: () {
                  Navigator.pop(context);
                  _scrollController.refresh();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
