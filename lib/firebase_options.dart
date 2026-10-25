import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBJNVmLEK2sfuw0FwC23unclQJdALaRRuE',
    appId: '1:101862061936:web:a5cf996e39be5f4fc1c1b5',
    messagingSenderId: '101862061936',
    projectId: 'storeapp-9dba6',
    authDomain: 'storeapp-9dba6.firebaseapp.com',
    storageBucket: 'storeapp-9dba6.firebasestorage.app',
    measurementId: 'G-VF04ZW8XBB',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCsTIB_LYs7lCAs376liOs0nAiG_i_qrbg',
    appId: '1:101862061936:android:35caeaa887e2ca37c1c1b5',
    messagingSenderId: '101862061936',
    projectId: 'storeapp-9dba6',
    storageBucket: 'storeapp-9dba6.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAAKZ4l7towcH61Tpb2d5yzUG42dXzzQTc',
    appId: '1:101862061936:ios:8956c06769067496c1c1b5',
    messagingSenderId: '101862061936',
    projectId: 'storeapp-9dba6',
    storageBucket: 'storeapp-9dba6.firebasestorage.app',
    iosBundleId: 'com.example.storeApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAAKZ4l7towcH61Tpb2d5yzUG42dXzzQTc',
    appId: '1:101862061936:ios:8956c06769067496c1c1b5',
    messagingSenderId: '101862061936',
    projectId: 'storeapp-9dba6',
    storageBucket: 'storeapp-9dba6.firebasestorage.app',
    iosBundleId: 'com.example.storeApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBJNVmLEK2sfuw0FwC23unclQJdALaRRuE',
    appId: '1:101862061936:web:b4a67cd1b2ad52a7c1c1b5',
    messagingSenderId: '101862061936',
    projectId: 'storeapp-9dba6',
    authDomain: 'storeapp-9dba6.firebaseapp.com',
    storageBucket: 'storeapp-9dba6.firebasestorage.app',
    measurementId: 'G-DZY5VZRH66',
  );
}
