import 'package:cloud_firestore/cloud_firestore.dart';

class ToDo {
  String id;
  bool isDone;
  String title;
  DateTime createdAt;
  DateTime? updatedAt;

  ToDo({
    required this.id,
    required this.isDone,
    required this.title,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'isDone': isDone,
      'title': title,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  factory ToDo.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ToDo(
      id: doc.id,
      isDone: data['isDone'] ?? false,
      title: data['title'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
