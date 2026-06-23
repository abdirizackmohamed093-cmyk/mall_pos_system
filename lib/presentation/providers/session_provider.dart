import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserSession {
  final int userId;
  final String username;
  final int branchId;
  final String branchName;
  final String role;

  const UserSession({
    required this.userId,
    required this.username,
    required this.branchId,
    required this.branchName,
    required this.role,
  });
}

class SessionNotifier extends StateNotifier<UserSession?> {
  SessionNotifier() : super(null);

  void login({
    required int userId,
    required String username,
    required int branchId,
    required String branchName,
    required String role,
  }) {
    state = UserSession(
      userId: userId,
      username: username,
      branchId: branchId,
      branchName: branchName,
      role: role,
    );
  }

  void logout() {
    state = null;
  }

  bool get isLoggedIn => state != null;
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, UserSession?>(
  (ref) => SessionNotifier(),
);