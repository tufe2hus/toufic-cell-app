import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/maintenance_job_model.dart';

class MaintenanceService {
  MaintenanceService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _jobsRef =>
      _firestore.collection('maintenance_jobs');

  String newJobId() => _jobsRef.doc().id;

  Stream<List<MaintenanceJob>> jobsStream() {
    return _jobsRef
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MaintenanceJob.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> createJob(MaintenanceJob job) async {
    await _jobsRef.doc(job.id).set(job.toMap());
  }

  Future<void> deleteJob(String id) async {
    await _jobsRef.doc(id).delete();
  }
}
