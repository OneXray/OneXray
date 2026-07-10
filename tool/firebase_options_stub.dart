import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static const FirebaseOptions currentPlatform = _options;
  static const FirebaseOptions macosSE = _options;

  static const FirebaseOptions _options = FirebaseOptions(
    apiKey: 'test-api-key',
    appId: '1:000000000000:ios:test',
    messagingSenderId: '000000000000',
    projectId: 'onexray-test',
  );
}
