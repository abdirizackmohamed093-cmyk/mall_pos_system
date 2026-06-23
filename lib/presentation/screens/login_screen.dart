import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database_provider.dart';
import '../providers/session_provider.dart';
import 'main_layout_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _usernameController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  bool _isLoading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final db = ref.read(databaseProvider);

      final username =
          _usernameController.text.trim();

      final password =
          _passwordController.text.trim();

      if (username.isEmpty || password.isEmpty) {
        throw Exception(
          'Username and password are required.',
        );
      }

      final user = await (db.select(db.users)
      ..where((u) => u.username.equals(username)))
    .getSingleOrNull();

if (user == null || !user.isActive) {
  throw Exception(
    'Invalid username or password.',
  );
}

      if (user.passwordHash != password) {
        throw Exception(
          'Invalid username or password.',
        );
      }

      final role = await (db.select(db.roles)
            ..where(
              (r) => r.id.equals(user.roleId),
            ))
          .getSingle();

      final branch = await (db.select(db.branches)
            ..where(
              (b) => b.id.equals(user.branchId),
            ))
          .getSingle();

      ref
          .read(sessionProvider.notifier)
          .login(
            userId: user.id,
            username: user.username,
            branchId: branch.id,
            branchName: branch.name,
            role: role.roleName,
          );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              const MainLayoutScreen(),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: SizedBox(
          width: 420,
          child: Card(
            elevation: 4,
            child: Padding(
              padding:
                  const EdgeInsets.all(24),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  const Text(
                    'MALL POS LOGIN',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  TextField(
                    controller:
                        _usernameController,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Username',
                    ),
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  TextField(
                    controller:
                        _passwordController,
                    obscureText: true,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Password',
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  if (_error != null)
                    Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: 12,
                      ),
                      child: Text(
                        _error!,
                        style:
                            const TextStyle(
                          color: Colors.red,
                        ),
                      ),
                    ),

                  SizedBox(
                    width:
                        double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _isLoading
                              ? null
                              : _login,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text(
                              'LOGIN',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}