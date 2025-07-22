import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:appbirdify/services/auth_service.dart';

void main() {
  group('AuthService Tests', () {
    test('authStateChanges should return a stream', () {
      final stream = AuthService.authStateChanges;
      expect(stream, isA<Stream<User?>>());
    });

    test('isUserLoggedIn should return correct boolean', () {
      final isLoggedIn = AuthService.isUserLoggedIn;
      expect(isLoggedIn, isA<bool>());
    });

    test('isAnonymous should return boolean', () {
      final isAnonymous = AuthService.isAnonymous;
      expect(isAnonymous, isA<bool>());
    });

    test('isEmailVerified should return boolean', () {
      final isVerified = AuthService.isEmailVerified;
      expect(isVerified, isA<bool>());
    });

    test('isNewUser should return boolean', () {
      final isNew = AuthService.isNewUser;
      expect(isNew, isA<bool>());
    });



    test('listenToAuthChanges should return a stream', () {
      final stream = AuthService.listenToAuthChanges();
      expect(stream, isA<Stream<User?>>());
    });
  });
} 