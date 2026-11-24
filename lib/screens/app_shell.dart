import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'home_shell.dart';
import 'login_screen.dart';
import 'random/random_page.dart';

enum AppView { random, account }

/// Root shell: Random ↔ account without tearing down presence on switch.
class AppShell extends StatefulWidget {
  final AppView initialView;
  final bool hasSession;

  const AppShell({
    super.key,
    required this.initialView,
    required this.hasSession,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late AppView _view;
  late bool _hasSession;
  String? _loginNotice;
  int _accountGeneration = 0;

  @override
  void initState() {
    super.initState();
    _view = widget.initialView;
    _hasSession = widget.hasSession;
  }

  void showRandom() {
    if (_view == AppView.random) return;
    setState(() {
      _view = AppView.random;
      _loginNotice = null;
    });
  }

  void showAccount() {
    if (_view == AppView.account) return;
    setState(() => _view = AppView.account);
  }

  void _handleLoggedIn() {
    setState(() {
      _hasSession = true;
      _view = AppView.account;
      _loginNotice = null;
      _accountGeneration++;
    });
  }

  void _handleLoggedOut({String? notice}) {
    setState(() {
      _hasSession = false;
      _view = notice != null && notice.isNotEmpty ? AppView.account : AppView.random;
      _loginNotice = notice;
      _accountGeneration++;
    });
  }

  Widget _layer({required bool visible, required Widget child}) {
    return TickerMode(
      enabled: visible,
      child: Offstage(
        offstage: !visible,
        child: IgnorePointer(
          ignoring: !visible,
          child: child,
        ),
      ),
    );
  }

  Widget _accountBody() {
    final accountVisible = _view == AppView.account;
    if (_hasSession) {
      return HomeShell(
        key: ValueKey('home-$_accountGeneration'),
        active: accountVisible,
        onOpenRandom: showRandom,
        onLoggedOut: (notice) => _handleLoggedOut(notice: notice),
      );
    }
    if (accountVisible) {
      return LoginScreen(
        key: ValueKey('login-$_accountGeneration'),
        notice: _loginNotice,
        fromRandom: true,
        onBackToRandom: showRandom,
        onLoggedIn: _handleLoggedIn,
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _layer(
            visible: _view == AppView.random,
            child: RandomPage(
              hasAccount: _hasSession,
              onOpenAccount: showAccount,
            ),
          ),
          _layer(
            visible: _view == AppView.account,
            child: _accountBody(),
          ),
        ],
      ),
    );
  }
}
