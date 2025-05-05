import 'dart:convert';

/// Represents the backup data structure
class BackupData {
  final List<TodoBackup> todos;
  final Map<String, dynamic> appSettings;
  final DateTime timestamp;
  final List<ImageReference> images;

  BackupData({
    required this.todos,
    required this.appSettings,
    required this.timestamp,
    required this.images,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'todos': todos.map((todo) => todo.toJson()).toList(),
      'appSettings': appSettings,
      'timestamp': timestamp.toIso8601String(),
      'images': images.map((img) => img.toJson()).toList(),
    };
  }

  /// Create from JSON when restoring
  factory BackupData.fromJson(Map<String, dynamic> json) {
    return BackupData(
      todos: (json['todos'] as List)
          .map((todoJson) => TodoBackup.fromJson(todoJson))
          .toList(),
      appSettings: json['appSettings'] ?? {},
      timestamp: DateTime.parse(json['timestamp']),
      images: (json['images'] as List?)
              ?.map((imgJson) => ImageReference.fromJson(imgJson))
              .toList() ??
          [],
    );
  }

  /// Serialize to a string
  String serialize() {
    return jsonEncode(toJson());
  }

  /// Deserialize from a string
  static BackupData deserialize(String data) {
    return BackupData.fromJson(jsonDecode(data));
  }
}

/// Represents a todo item in the backup
class TodoBackup {
  final String id;
  final bool isDone;
  final String title;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String> imageIds; // References to images stored in Google Drive

  TodoBackup({
    required this.id,
    required this.isDone,
    required this.title,
    required this.createdAt,
    this.updatedAt,
    this.imageIds = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'isDone': isDone,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      'imageIds': imageIds,
    };
  }

  factory TodoBackup.fromJson(Map<String, dynamic> json) {
    return TodoBackup(
      id: json['id'],
      isDone: json['isDone'] ?? false,
      title: json['title'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      imageIds: (json['imageIds'] as List?)?.cast<String>() ?? [],
    );
  }

  /// Convert from a ToDo model
  factory TodoBackup.fromToDo(todo, List<String> imageIds) {
    return TodoBackup(
      id: todo.id,
      isDone: todo.isDone,
      title: todo.title,
      createdAt: todo.createdAt,
      updatedAt: todo.updatedAt,
      imageIds: imageIds,
    );
  }
}

/// Represents an image reference in Google Drive
class ImageReference {
  final String id; // Google Drive file ID
  final String name;
  final String driveId; // Google Drive ID
  final String todoId; // Associated Todo ID
  final DateTime uploadTime;

  ImageReference({
    required this.id,
    required this.name,
    required this.driveId,
    required this.todoId,
    required this.uploadTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'driveId': driveId,
      'todoId': todoId,
      'uploadTime': uploadTime.toIso8601String(),
    };
  }

  factory ImageReference.fromJson(Map<String, dynamic> json) {
    return ImageReference(
      id: json['id'],
      name: json['name'],
      driveId: json['driveId'],
      todoId: json['todoId'],
      uploadTime: DateTime.parse(json['uploadTime']),
    );
  }
}
