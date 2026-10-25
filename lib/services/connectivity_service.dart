import 'package:connectivity_plus/connectivity_plus.dart';

/// Lightweight wrapper around connectivity_plus.
/// Use [isConnected] for one-shot checks (e.g., before image upload).
/// Use [connectivityStream] to react to network changes in the UI.
class ConnectivityService {
  const ConnectivityService._();

  /// Returns true if the device currently has any network interface up.
  static Future<bool> isConnected() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true; // Fail open – don't block the user on check errors.
    }
  }

  /// Emits a new list of [ConnectivityResult] whenever the network state
  /// changes (e.g., WiFi drops, mobile data connects).
  static Stream<List<ConnectivityResult>> get connectivityStream =>
      Connectivity().onConnectivityChanged;

  /// Convenience: maps the stream to a simple bool (true = online).
  static Stream<bool> get onlineStream =>
      connectivityStream.map(
        (results) => results.any((r) => r != ConnectivityResult.none),
      );
}
