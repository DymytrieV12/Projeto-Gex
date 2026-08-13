import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Configuração gerada manualmente a partir do google-services.json fornecido.
///
/// Quando o projeto for configurado oficialmente com `flutterfire configure`,
/// este arquivo pode ser substituído pelo gerado automaticamente.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions não foi configurado para web neste projeto.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions não foi configurado para iOS neste projeto.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions não foi configurado para macOS neste projeto.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions não foi configurado para Windows neste projeto.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions não foi configurado para Linux neste projeto.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions não suporta esta plataforma.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCIBDUoMrGKdieKgfQlZgL7Rg-QLmctIjE',
    appId: '1:912812799729:android:5d12635948eb1020ab9b50',
    messagingSenderId: '912812799729',
    projectId: 'projeto-gex',
    storageBucket: 'projeto-gex.firebasestorage.app',
    databaseURL: 'https://projeto-gex-default-rtdb.firebaseio.com',
  );
}
