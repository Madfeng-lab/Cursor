import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_state.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  String? _localError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? '登录' : '注册'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: '邮箱',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '密码',
              ),
            ),
            const SizedBox(height: 20),
            if (_localError != null)
              Text(
                _localError!,
                style: const TextStyle(color: Colors.red),
              ),
            if (auth.error != null)
              Text(
                auth.error!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: auth.isLoading
                  ? null
                  : () {
                      final email = _emailController.text.trim();
                      final password = _passwordController.text;
                      setState(() {
                        _localError = null;
                      });

                      if (email.isEmpty) {
                        setState(() {
                          _localError = '请输入邮箱';
                        });
                        return;
                      }

                      const emailPattern = r'^[^@]+@[^@]+\.[^@]+$';
                      final emailReg = RegExp(emailPattern);
                      if (!emailReg.hasMatch(email)) {
                        setState(() {
                          _localError = '邮箱格式不正确';
                        });
                        return;
                      }

                      if (password.isEmpty) {
                        setState(() {
                          _localError = '请输入密码';
                        });
                        return;
                      }

                      if (_isLogin) {
                        auth.login(email, password);
                      } else {
                        auth.register(email, password);
                      }
                    },
              child: auth.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isLogin ? '登录' : '注册'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLogin = !_isLogin;
                });
              },
              child: Text(_isLogin ? '没有账号？去注册' : '已有账号？去登录'),
            ),
          ],
        ),
      ),
    );
  }
}

