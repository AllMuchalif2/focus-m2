import 'package:firebase_auth/firebase_auth.dart';
import '../data/models/app_user.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth;

  AuthService({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  Stream<AppUser?> get authStateChanges {
    return _firebaseAuth
        .authStateChanges()
        .map((user) => user != null ? AppUser.fromFirebaseUser(user) : null);
  }

  AppUser? get currentUser {
    final user = _firebaseAuth.currentUser;
    return user != null ? AppUser.fromFirebaseUser(user) : null;
  }

  Future<AppUser> register({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw 'Gagal membuat pengguna.';
      }
      return AppUser.fromFirebaseUser(user);
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw 'Gagal masuk akun.';
      }
      return AppUser.fromFirebaseUser(user);
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> logout() async {
    try {
      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> resetPassword({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw e.toString();
    }
  }

  String _handleFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Akun dengan email ini tidak ditemukan.';
      case 'wrong-password':
        return 'Kata sandi salah. Silakan periksa kembali.';
      case 'invalid-credential':
        return 'Email atau kata sandi tidak sesuai.';
      case 'email-already-in-use':
        return 'Email sudah terdaftar. Silakan login atau gunakan email lain.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'weak-password':
        return 'Kata sandi terlalu lemah. Gunakan minimal 6 karakter.';
      case 'user-disabled':
        return 'Akun ini telah dinonaktifkan.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan gagal. Silakan coba lagi beberapa saat lagi.';
      case 'network-request-failed':
        return 'Koneksi internet bermasalah. Periksa jaringan Anda.';
      default:
        return e.message ?? 'Terjadi kesalahan otentikasi.';
    }
  }
}
