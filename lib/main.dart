import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Вхід',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFE3E7ED),
      ),
      home: const LoginScreen(),
    );
  }
}

// ---------- Neumorphic base colors ----------
const Color kBg = Color(0xFFE3E7ED);
const Color kShadowDark = Color(0xFFB9C1CE);
const Color kShadowLight = Color(0xFFFFFFFF);
const Color kTextDark = Color(0xFF3D4552);
const Color kTextGray = Color(0xFF8B94A3);
const Color kAccentBlue = Color(0xFF3B7DDD);

// Reusable neumorphic "raised" decoration
BoxDecoration neuRaised({double radius = 24, bool pressed = false}) {
  return BoxDecoration(
    color: kBg,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: pressed
        ? []
        : [
            BoxShadow(
              color: kShadowDark.withOpacity(0.7),
              offset: const Offset(6, 6),
              blurRadius: 14,
            ),
            BoxShadow(
              color: kShadowLight.withOpacity(0.9),
              offset: const Offset(-6, -6),
              blurRadius: 14,
            ),
          ],
  );
}

// Reusable neumorphic "inset" (pressed-in) decoration, used for text fields
BoxDecoration neuInset({double radius = 30}) {
  return BoxDecoration(
    color: kBg,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: kShadowDark.withOpacity(0.6),
        offset: const Offset(4, 4),
        blurRadius: 8,
        spreadRadius: -2,
      ),
      BoxShadow(
        color: kShadowLight.withOpacity(0.9),
        offset: const Offset(-4, -4),
        blurRadius: 8,
        spreadRadius: -2,
      ),
    ],
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    final login = _loginController.text.trim();
    final password = _passwordController.text;

    if (login.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заповніть логін і пароль')),
      );
      return;
    }

    // TODO: підключити реальну авторизацію (API-запит) тут.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Вхід як "$login"…')),
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
            child: Container(
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
              decoration: neuRaised(radius: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar circle
                  Container(
                    width: 96,
                    height: 96,
                    decoration: neuRaised(radius: 48),
                    child: const Icon(
                      Icons.person,
                      size: 48,
                      color: kAccentBlue,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  const Text(
                    'Вхід',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  const Text(
                    'Увійдіть щоб продовжити чат',
                    style: TextStyle(
                      fontSize: 15,
                      color: kTextGray,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Login field
                  _NeuTextField(
                    controller: _loginController,
                    hint: 'Логін',
                  ),
                  const SizedBox(height: 18),

                  // Password field
                  _NeuTextField(
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
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  const SizedBox(height: 26),

                  // Login button
                  GestureDetector(
                    onTap: _handleLogin,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: neuRaised(radius: 30),
                      alignment: Alignment.center,
                      child: const Text(
                        'Увійти  →',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: kAccentBlue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Register link
                  GestureDetector(
                    onTap: () {
                      // TODO: перехід на екран реєстрації
                    },
                    child: const Text(
                      'Немає акаунта? Зареєструватися',
                      style: TextStyle(
                        fontSize: 14,
                        color: kTextGray,
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

class _NeuTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final Widget? trailing;

  const _NeuTextField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: neuInset(),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              style: const TextStyle(fontSize: 16, color: kTextDark),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: kTextGray, fontSize: 16),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
