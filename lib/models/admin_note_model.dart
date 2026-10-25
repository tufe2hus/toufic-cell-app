import 'package:cloud_firestore/cloud_firestore.dart';

class AdminNote {
  AdminNote({
    required this.id,
    required this.title,
    required this.message,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.isImportant = false,
  });

  final String id;
  final String title;
  final String message;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isImportant;

  factory AdminNote.fromMap(Map<String, dynamic> data, String id) {
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
    return AdminNote(
      id: id,
      title: data['title'] as String? ?? '',
      message: data['message'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: createdAt ?? updatedAt ?? DateTime.now(),
      updatedAt: updatedAt ?? createdAt ?? DateTime.now(),
      isImportant: data['isImportant'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'message': message,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'isImportant': isImportant,
  };

  AdminNote copyWith({
    String? id,
    String? title,
    String? message,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isImportant,
  }) {
    return AdminNote(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isImportant: isImportant ?? this.isImportant,
    );
  }
}
