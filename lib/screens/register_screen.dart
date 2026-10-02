import 'package:flutter/material.dart';
import '../api_client.dart';
import '../widgets/neu.dart';
import 'home_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _api = ApiClient();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String _gender = 'male';
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;
  String? _error;

  static const int _minPasswordLen = 6;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final login = _loginController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (login.isEmpty || password.isEmpty) {
      setState(() => _error = 'Введіть логін і пароль');
      return;
    }
    if (password.runes.length < _minPasswordLen) {
      setState(() => _error = 'Пароль надто короткий (мінімум $_minPasswordLen символів)');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Паролі не співпадають');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _api.register(
        username: login,
        password: password,
        passwordConfirm: confirm,
        gender: _gender,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.userMessage);
    } catch (_) {
      setState(() => _error = 'Сталася невідома помилка');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _genderChip(String value, String label) {
    final selected = _gender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gender = value),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: selected
              ? BoxDecoration(
                  color: kBg,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: kShadowDark.withOpacity(0.6),
                      offset: const Offset(3, 3),
                      blurRadius: 6,
                      spreadRadius: -2,
                    ),
                    BoxShadow(
                      color: kShadowLight.withOpacity(0.9),
                      offset: const Offset(-3, -3),
                      blurRadius: 6,
                      spreadRadius: -2,
                    ),
                  ],
                )
              : neuRaised(radius: 20),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? kAccentBlue : kTextGray,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: NeuCard(
              radius: 32,
              padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Реєстрація',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Створіть акаунт, щоб почати чат',
                    style: TextStyle(fontSize: 15, color: kTextGray),
                  ),
                  const SizedBox(height: 28),
                  NeuTextField(controller: _loginController, hint: 'Логін'),
                  const SizedBox(height: 16),
                  NeuTextField(
                    controller: _passwordController,
                    hint: 'Пароль (мін. $_minPasswordLen символів)',
                    obscure: _obscure1,
                    trailing: IconButton(
                      icon: Icon(
                        _obscure1 ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: kTextGray,
                      ),
                      onPressed: () => setState(() => _obscure1 = !_obscure1),
                    ),
                  ),
                  const SizedBox(height: 16),
                  NeuTextField(
                    controller: _confirmController,
                    hint: 'Повторіть пароль',
                    obscure: _obscure2,
                    trailing: IconButton(
                      icon: Icon(
                        _obscure2 ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: kTextGray,
                      ),
                      onPressed: () => setState(() => _obscure2 = !_obscure2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _genderChip('male', 'Чоловіча'),
                      _genderChip('female', 'Жіноча'),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(color: kDangerRed, fontSize: 13.5),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 26),
                  NeuButton(
                    label: 'Зареєструватися',
                    onTap: _handleRegister,
                    loading: _loading,
                  ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Вже є акаунт? Увійти',
                      style: TextStyle(fontSize: 14, color: kTextGray),
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
