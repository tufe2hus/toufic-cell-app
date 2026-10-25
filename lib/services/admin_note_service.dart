import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_note_model.dart';

class AdminNoteService {
  AdminNoteService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notesRef =>
      _firestore.collection('admin_notes');

  String newNoteId() => _notesRef.doc().id;

  Stream<List<AdminNote>> notesStream() {
    return _notesRef
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AdminNote.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> createNote(AdminNote note) async {
    await _notesRef.doc(note.id).set({
      ...note.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isImportant': note.isImportant,
    });
  }

  Future<void> updateNote(AdminNote note) async {
    await _notesRef.doc(note.id).update({
      'title': note.title,
      'message': note.message,
      'createdBy': note.createdBy,
      'isImportant': note.isImportant,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteNote(String id) async {
    await _notesRef.doc(id).delete();
  }
}
