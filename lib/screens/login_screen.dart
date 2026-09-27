import 'dart:async';
import 'package:flutter/material.dart';
import '../api_client.dart';
import '../config.dart';
import '../widgets/neu.dart';
import 'register_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _api = ApiClient();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;
  String? _statusHint;
  String? _debugDetail;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final login = _loginController.text.trim();
    final password = _passwordController.text;

    if (login.isEmpty || password.isEmpty) {
      setState(() => _error = 'Введіть логін і пароль');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _statusHint = null;
      _debugDetail = null;
    });

    final hintTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _loading) {
        setState(() => _statusHint = 'Прокидаю сервер, зачекай трохи…');
      }
    });

    try {
      await _api.login(login, password);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on ApiException catch (e) {
      setState(() {
        _error = e.userMessage;
        _debugDetail = e.debugDetail;
      });
    } catch (_) {
      setState(() => _error = 'Сталася невідома помилка');
    } finally {
      hintTimer.cancel();
      if (mounted) {
        setState(() {
          _loading = false;
          _statusHint = null;
        });
      }
    }
  }

  Future<void> _showServerSettings() async {
    final current = await AppConfig.getBaseUrl();
    final controller = TextEditingController(text: current);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBg,
        title: const Text('Адреса сервера', style: TextStyle(color: kTextDark)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'http://host:7979',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Скасувати'),
          ),
          TextButton(
            onPressed: () async {
              await AppConfig.setBaseUrl(controller.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Зберегти'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.settings_outlined, color: kTextGray),
                onPressed: _showServerSettings,
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: NeuCard(
                  radius: 32,
                  padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: neuRaised(radius: 48),
                        child: const Icon(Icons.person, size: 48, color: kAccentBlue),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Вхід',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: kTextDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Увійдіть щоб продовжити чат',
                        style: TextStyle(fontSize: 15, color: kTextGray),
                      ),
                      const SizedBox(height: 32),
                      NeuTextField(controller: _loginController, hint: 'Логін'),
                      const SizedBox(height: 18),
                      NeuTextField(
                        controller: _passwordController,
                        hint: 'Пароль',
                        obscure: _obscurePassword,
                        trailing: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: kTextGray,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          style: const TextStyle(color: kDangerRed, fontSize: 13.5),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (_debugDetail != null) ...[
                        const SizedBox(height: 6),
                        SelectableText(
                          _debugDetail!,
                          style: const TextStyle(color: kTextGray, fontSize: 10.5),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (_statusHint != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _statusHint!,
                          style: const TextStyle(color: kTextGray, fontSize: 13.5),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 26),
                      NeuButton(
                        label: 'Увійти  →',
                        onTap: _handleLogin,
                        loading: _loading,
                      ),
                      const SizedBox(height: 22),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          );
                        },
                        child: const Text(
                          'Немає акаунта? Зареєструватися',
                          style: TextStyle(fontSize: 14, color: kTextGray),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
