import 'package:cloud_functions/cloud_functions.dart';

class AdminAuthService {
  AdminAuthService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<void> changeUserPassword({
    required String uid,
    required String newPassword,
  }) async {
    final callable = _functions.httpsCallable('setUserPassword');
    await callable.call<void>({'targetUid': uid, 'newPassword': newPassword});
  }
}
