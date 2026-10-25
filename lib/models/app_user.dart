import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  AppUser({
    required this.uid,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  final String uid;
  final String email;
  final String role;
  final bool isActive;
  final DateTime createdAt;

  bool get isAdmin => role.toLowerCase() == 'admin';

  factory AppUser.fromMap(Map<String, dynamic> data, String uid) {
    return AppUser(
      uid: uid,
      email: data['email'] as String? ?? '',
      role: data['role'] as String? ?? 'user',
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'email': email,
    'role': role,
    'isActive': isActive,
    'createdAt': createdAt,
  };
}
