import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'api_client.dart';
import 'session_store.dart';
import 'theme/tokens.dart';
import 'screens/app_shell.dart';
import 'update/app_update_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppUpdateService.instance.init();
  // Fire-and-forget: one version check, not a poll loop.
  AppUpdateService.instance.checkOnce();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Booblify',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: GoogleFonts.nunito().fontFamily,
        scaffoldBackgroundColor: kBg,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _api = ApiClient();
  bool _checking = true;
  bool _hasSession = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final token = await SessionStore.getToken();
    if (token == null) {
      setState(() {
        _checking = false;
        _hasSession = false;
      });
      return;
    }
    try {
      await _api.me();
      setState(() {
        _checking = false;
        _hasSession = true;
      });
    } catch (_) {
      await SessionStore.clear();
      setState(() {
        _checking = false;
        _hasSession = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return AppShell(
      initialView: _hasSession ? AppView.account : AppView.random,
      hasSession: _hasSession,
    );
  }
}
