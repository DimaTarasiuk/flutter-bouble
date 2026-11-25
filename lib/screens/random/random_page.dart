import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:package_info_plus/package_info_plus.dart';

import '../../api_client.dart';
import '../../random/random_api_client.dart';
import '../../random/random_models.dart';
import '../../random/random_session_store.dart';
import '../../random/random_ws_service.dart';
import '../../update/app_update_service.dart';
import '../../widgets/booblify_logo.dart';
import '../../widgets/emoji_panel.dart';
import '../../widgets/neu.dart';
import '../../widgets/update_button.dart';

enum _Phase { form, searching, chat, peerLeft }

class RandomPage extends StatefulWidget {
  final bool hasAccount;
  final VoidCallback onOpenAccount;

  const RandomPage({
    super.key,
    required this.hasAccount,
    required this.onOpenAccount,
  });

  @override
  State<RandomPage> createState() => _RandomPageState();
}

class _RandomPageState extends State<RandomPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _api = RandomApiClient();
  final _ws = RandomWsService();
  final _input = TextEditingController();
  final _seekMin = TextEditingController(text: '18');
  final _seekMax = TextEditingController(text: '35');
  final _scroll = ScrollController();
  final _inputFocus = FocusNode();

  StreamSubscription? _wsSub;
  StreamSubscription? _connSub;

  _Phase _phase = _Phase.form;
  String? _token;
  String? _error;
  bool _starting = false;
  bool _connected = false;
  bool _emojiOpen = false;
  bool _confirmNext = false;

  String _gender = '';
  String _ageBand = '';
  String _seekGender = '';

  RandomSession? _session;
  final List<RandomMessage> _messages = [];
  RandomReplyPreview? _replyTo;

  late final AnimationController _pulse;

  static Future<String> _appVersionLabel() {
    return PackageInfo.fromPlatform().then((info) {
      return 'v ${info.version}';
    }).catchError((_) => '');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    unawaited(AppUpdateService.instance.init());
    unawaited(AppUpdateService.instance.checkOnce());
    _bootstrap();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final token = _token;
    if (token == null || token.isEmpty) return;
    if (_phase != _Phase.searching &&
        _phase != _Phase.chat &&
        _phase != _Phase.peerLeft) {
      return;
    }
    // Android often kills the WS in background; reconnect before grace expires.
    unawaited(_ws.reconnectNow());
  }

  Future<void> _bootstrap() async {
    final saved = await RandomSessionStore.getToken();
    final prefs = await RandomSessionStore.getPrefs();
    if (!mounted) return;
    if (prefs != null) {
      setState(() {
        _gender = prefs.gender;
        final band = ageBandByRange(prefs.ageMin, prefs.ageMax);
        _ageBand = band?.value ?? '';
        _seekGender = prefs.seekGender;
        _seekMin.text = '${prefs.seekAgeMin}';
        _seekMax.text = '${prefs.seekAgeMax}';
      });
    }
    if (saved != null && saved.isNotEmpty) {
      setState(() {
        _token = saved;
        _phase = _Phase.searching;
      });
      await _attachWs(saved);
    }
  }

  Future<void> _attachWs(String token) async {
    await _wsSub?.cancel();
    await _connSub?.cancel();
    _wsSub = _ws.events.listen(_onWsEvent);
    _connSub = _ws.connectionChanges.listen((c) {
      if (!mounted) return;
      setState(() => _connected = c);
      if (c) _onConnected();
    });
    await _ws.connect(token);
  }

  Future<void> _onConnected() async {
    final token = _token;
    if (token == null) return;
    try {
      final hist = await _api.messages(token);
      if (!mounted) return;
      setState(() {
        _session = hist.session;
        _messages
          ..clear()
          ..addAll(hist.messages);
        _phase = _Phase.chat;
        _error = null;
      });
      _scrollToBottom();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _expire('Сесія завершилась, почніть пошук знову');
        return;
      }
      if (e.statusCode == 404) {
        if (_phase == _Phase.searching) {
          await _search();
        } else if (_phase == _Phase.chat && mounted) {
          setState(() => _phase = _Phase.peerLeft);
        }
      }
    } catch (_) {}
  }

  void _onWsEvent(Map<String, dynamic> ev) {
    final type = ev['type'] as String?;
    if (type == 'matched') {
      final raw = ev['session'];
      if (raw is Map<String, dynamic>) {
        setState(() {
          _session = RandomSession.fromJson(raw);
          _messages.clear();
          _replyTo = null;
          _input.clear();
          _phase = _Phase.chat;
          _error = null;
        });
      }
    } else if (type == 'message') {
      final raw = ev['message'];
      if (raw is Map<String, dynamic>) {
        final msg = RandomMessage.fromJson(raw);
        if (_messages.any((m) => m.id == msg.id)) return;
        setState(() => _messages.add(msg));
        _scrollToBottom();
      }
    } else if (type == 'peer_left') {
      final sid = (ev['session_id'] as num?)?.toInt();
      if (sid != null && sid == _session?.id) {
        setState(() {
          _replyTo = null;
          _phase = _Phase.peerLeft;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  /// Reset UI immediately; tear down WS/session in the background so Cancel never hangs.
  Future<void> _expire([String message = '']) async {
    final hadToken = _token;
    if (mounted) {
      setState(() {
        _token = null;
        _session = null;
        _messages.clear();
        _replyTo = null;
        _input.clear();
        _emojiOpen = false;
        _confirmNext = false;
        _starting = false;
        _phase = _Phase.form;
        _error = message.isEmpty ? null : message;
        _connected = false;
      });
    }
    // Local clear first so bootstrap won't restore a stuck session.
    await RandomSessionStore.clearGuestSession();
    // Don't await a hung socket — disconnect has its own short close timeout.
    unawaited(_ws.disconnect());
    if (hadToken != null) {
      // Best-effort server cleanup; ignore failures/timeouts.
      unawaited(() async {
        try {
          await _api.skip(hadToken).timeout(const Duration(seconds: 8));
        } catch (_) {}
      }());
    }
  }

  Future<void> _leave() async {
    await _expire();
  }

  String? _validate() {
    if (_gender.isEmpty) return 'Оберіть свою стать';
    final band = ageBandByValue(_ageBand);
    if (band == null) return 'Оберіть свій вік';
    if (_seekGender.isEmpty) return 'Оберіть кого шукаєте';
    final min = int.tryParse(_seekMin.text.trim());
    final max = int.tryParse(_seekMax.text.trim());
    if (min == null || max == null) return 'Вкажіть вік співрозмовника';
    if (min < kRandomMinAge || max > kRandomMaxAge || min > max) {
      return 'Перевірте вік співрозмовника';
    }
    return null;
  }

  RandomPrefs _buildPrefs() {
    final band = ageBandByValue(_ageBand)!;
    var min = clampSeekAge(int.parse(_seekMin.text.trim()));
    var max = clampSeekAge(int.parse(_seekMax.text.trim()));
    if (min > max) {
      final t = min;
      min = max;
      max = t;
    }
    return RandomPrefs(
      gender: _gender,
      ageMin: band.min,
      ageMax: band.max,
      seekGender: _seekGender,
      seekAgeMin: min,
      seekAgeMax: max,
    );
  }

  Future<void> _start() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    final prefs = _buildPrefs();
    setState(() {
      _starting = true;
      _error = null;
      _seekMin.text = '${prefs.seekAgeMin}';
      _seekMax.text = '${prefs.seekAgeMax}';
    });
    try {
      final anon = await RandomSessionStore.getOrCreateAnonId();
      final res = await _api.start(prefs, anon);
      await RandomSessionStore.saveAnonId(res.anonId);
      await RandomSessionStore.saveToken(res.token);
      await RandomSessionStore.savePrefs(res.prefs);
      if (!mounted) return;
      setState(() {
        _token = res.token;
        _phase = _Phase.searching;
        _starting = false;
      });
      await _attachWs(res.token);
    } on ApiException catch (e) {
      if (!mounted) return;
      String msg = 'Не вдалося почати, спробуйте ще раз';
      if (e.code == 'invalid prefs') msg = 'Перевірте введені дані';
      if (e.code == 'too many requests') msg = 'Забагато спроб, спробуйте пізніше';
      if (e.code == 'network_error') {
        msg = 'Немає звʼязку з сервером (перевір, що бекенд запущений)';
      }
      if (e.code == 'timeout') msg = e.userMessage;
      setState(() {
        _starting = false;
        _error = msg;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = 'Не вдалося почати, спробуйте ще раз';
      });
    }
  }

  Future<void> _search() async {
    final token = _token;
    if (token == null) return;
    setState(() {
      _session = null;
      _messages.clear();
      _replyTo = null;
      _input.clear();
      _emojiOpen = false;
      _phase = _Phase.searching;
      _error = null;
    });
    try {
      final res = await _api.search(token);
      if (!mounted) return;
      if (res.isMatched) {
        setState(() {
          _session = res.session;
          _phase = _Phase.chat;
        });
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _expire('Сесія завершилась, почніть пошук знову');
        return;
      }
      if (e.statusCode == 409) return;
      if (!mounted) return;
      setState(() => _error = 'Не вдалося почати пошук');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Не вдалося почати пошук');
    }
  }


  Future<void> _next() async {
    setState(() => _confirmNext = false);
    final token = _token;
    if (token != null) {
      try {
        await _api.skip(token).timeout(const Duration(seconds: 8));
      } catch (_) {}
    }
    await _search();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    final token = _token;
    if (text.isEmpty || token == null || _phase != _Phase.chat) return;
    final reply = _replyTo;
    setState(() {
      _input.clear();
      _replyTo = null;
      _emojiOpen = false;
    });
    try {
      final msg = await _api.send(token, text, replyTo: reply?.id);
      if (!mounted) return;
      if (!_messages.any((m) => m.id == msg.id)) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _input.text = text;
        _replyTo = reply;
      });
      if (e.statusCode == 401) {
        await _expire('Сесія завершилась, почніть пошук знову');
        return;
      }
      if (e.statusCode == 409) {
        setState(() => _phase = _Phase.peerLeft);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _input.text = text;
        _replyTo = reply;
      });
    }
  }

  void _startReply(RandomMessage msg) {
    if (msg.mine || _phase != _Phase.chat) return;
    setState(() {
      _replyTo = RandomReplyPreview(
        id: msg.id,
        from: genderLabel(msg.fromGender),
        text: msg.text,
      );
    });
    _inputFocus.requestFocus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wsSub?.cancel();
    _connSub?.cancel();
    _ws.dispose();
    _pulse.dispose();
    _input.dispose();
    _seekMin.dispose();
    _seekMax.dispose();
    _scroll.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                if (_phase == _Phase.form || _phase == _Phase.searching)
                  _buildBrandHeader(),
                Expanded(child: _buildBody()),
                if (_phase == _Phase.form || _phase == _Phase.searching)
                  _buildVersionFooter(),
              ],
            ),
            if (_confirmNext) _buildConfirmModal(),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BooblifyLogo(),
                SizedBox(height: 2),
                Text(
                  'Інкогніто',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextMuted,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: widget.onOpenAccount,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              minimumSize: const Size(10, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              widget.hasAccount ? 'Мої чати' : 'Увійти',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: kAccentPink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionFooter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const UpdateButton(compact: true),
          FutureBuilder<String>(
            future: _appVersionLabel(),
            builder: (context, snap) {
              final v = snap.data;
              if (v == null || v.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  v,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextMuted,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _Phase.form:
        return _buildForm();
      case _Phase.searching:
        return _buildSearching();
      case _Phase.chat:
      case _Phase.peerLeft:
        return _session == null ? _buildSearching() : _buildChat();
    }
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          const Text(
            'Вільний чат',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: kTextMain,
            ),
          ),
          const SizedBox(height: 16),
          _section(
            children: [
              _label('Я'),
              _chips(
                const [
                  ('male', 'Чоловік'),
                  ('female', 'Жінка'),
                ],
                _gender,
                (v) => setState(() => _gender = v),
              ),
              const SizedBox(height: 12),
              _label('Мій вік'),
              _chips(
                kRandomAgeBands.map((b) => (b.value, b.label)).toList(),
                _ageBand,
                (v) => setState(() => _ageBand = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _section(
            children: [
              _label('Шукаю'),
              _chips(
                const [
                  ('male', 'Чоловіка'),
                  ('female', 'Жінку'),
                  ('any', 'Будь-кого'),
                ],
                _seekGender,
                (v) => setState(() => _seekGender = v),
              ),
              const SizedBox(height: 12),
              _label('Вік співрозмовника'),
              Row(
                children: [
                  Expanded(
                    child: NeuTextField(
                      controller: _seekMin,
                      hint: 'від',
                      keyboardType: TextInputType.number,
                      radius: 18,
                      insetDepth: 3,
                      verticalPadding: 12,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '—',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: kTextMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: NeuTextField(
                      controller: _seekMax,
                      hint: 'до',
                      keyboardType: TextInputType.number,
                      radius: 18,
                      insetDepth: 3,
                      verticalPadding: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kAccentPink,
              ),
            ),
          ],
          const SizedBox(height: 16),
          NeuButton(
            label: _starting ? 'Починаємо...' : 'Знайти співрозмовника',
            onTap: _starting ? null : _start,
            loading: _starting,
            color: kAccentPink,
          ),
        ],
      ),
    );
  }

  Widget _section({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: neuBox(d: 5, b: 12, radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: kTextMuted,
        ),
      ),
    );
  }

  Widget _chips(
    List<(String, String)> options,
    String value,
    ValueChanged<String> onChange,
  ) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: NeuPress(
              onTap: () => onChange(options[i].$1),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                alignment: Alignment.center,
                decoration: value == options[i].$1
                    ? neuBox(inset: true, d: 3, b: 6, radius: 16)
                    : neuBox(d: 3, b: 6, radius: 16),
                child: Text(
                  options[i].$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: value == options[i].$1 ? kAccentBlue : kTextMuted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSearching() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeTransition(
            opacity: Tween(begin: 0.55, end: 1.0).animate(_pulse),
            child: ScaleTransition(
              scale: Tween(begin: 0.92, end: 1.05).animate(_pulse),
              child: Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: neuBox(d: 6, b: 12, radius: 42),
                child: const Text(
                  'B',
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    color: kNameAbbr,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _connected ? 'Шукаємо співрозмовника...' : 'Підключення...',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: kTextMain,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kAccentPink,
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: 160,
            child: NeuButton(
              label: 'Скасувати',
              onTap: _leave,
              color: kTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChat() {
    final session = _session!;
    final peerLeft = _phase == _Phase.peerLeft;
    return Column(
      children: [
        _buildChatHeader(session, peerLeft),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            itemCount: _messages.length + (_messages.isEmpty && !peerLeft ? 1 : 0),
            itemBuilder: (context, i) {
              if (_messages.isEmpty && !peerLeft) {
                return Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: neuBox(inset: true, d: 2, b: 5, radius: 50),
                    child: const Text(
                      'Привітайтесь першими 👋',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kTextMuted,
                      ),
                    ),
                  ),
                );
              }
              final m = _messages[i];
              return _RandomBubble(
                msg: m,
                onReply: peerLeft ? null : () => _startReply(m),
              );
            },
          ),
        ),
        if (peerLeft) _buildPeerLeftBar() else _buildComposer(),
      ],
    );
  }

  Widget _buildChatHeader(RandomSession session, bool peerLeft) {
    final onlineColor = onlineColorForGender(session.peerGender);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kDivider)),
      ),
      child: Row(
        children: [
          Avatar(
            username: genderSign(session.peerGender),
            size: 40,
            initialsColor: onlineColor,
            showDot: true,
            online: !peerLeft,
            gender: session.peerGender,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peerNick(session),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: kTextMain,
                  ),
                ),
                Text(
                  peerLeft
                      ? (session.peerGender == 'female'
                          ? 'Вийшла з чату'
                          : 'Вийшов з чату')
                      : '● онлайн',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: peerLeft ? kTextMuted : onlineColor,
                  ),
                ),
              ],
            ),
          ),
          if (!peerLeft)
            NeuPress(
              onTap: () => setState(() => _confirmNext = true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: neuBox(d: 3, b: 6, radius: 16),
                child: const Text(
                  'Далі →',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: kAccentPink,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
          NeuPress(
            onTap: _leave,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: neuBox(d: 3, b: 6, radius: 18),
              child: const Text(
                '✕',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: kTextMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeerLeftBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        children: [
          const Text(
            'Співрозмовник вийшов з чату',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kTextMuted,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: NeuButton(
                  label: 'Шукати далі →',
                  onTap: _search,
                  color: kAccentPink,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NeuButton(
                  label: 'Змінити',
                  onTap: _leave,
                  color: kTextMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        children: [
          if (_replyTo != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: neuBox(inset: true, d: 2, b: 5, radius: 16),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 28,
                    decoration: BoxDecoration(
                      color: kAccentPink,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Відповідь · ${_replyTo!.from}',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: kAccentPink,
                          ),
                        ),
                        Text(
                          _replyTo!.text.replaceAll(RegExp(r'\s+'), ' ').trim(),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _replyTo = null),
                    icon: const Icon(Icons.close, size: 16, color: kTextMuted),
                  ),
                ],
              ),
            ),
          if (_emojiOpen)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: EmojiPanel(
                onPick: (em) {
                  final next = (_input.text + em);
                  _input.text = next.length > kMaxMessageLen
                      ? next.substring(0, kMaxMessageLen)
                      : next;
                  _input.selection = TextSelection.collapsed(
                    offset: _input.text.length,
                  );
                  setState(() {});
                },
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: neuBox(inset: true, d: 4, b: 8, radius: 50),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          focusNode: _inputFocus,
                          maxLength: kMaxMessageLen,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(kMaxMessageLen),
                          ],
                          onSubmitted: (_) => _send(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: kTextMain,
                          ),
                          decoration: InputDecoration(
                            hintText: _replyTo != null
                                ? 'Написати відповідь...'
                                : 'Написати повідомлення...',
                            hintStyle: const TextStyle(
                              color: kTextMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            border: InputBorder.none,
                            counterText: '',
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            setState(() => _emojiOpen = !_emojiOpen),
                        icon: Text(
                          '😊',
                          style: TextStyle(
                            fontSize: 17,
                            color: _emojiOpen ? kAccentBlue : kTextMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              NeuPress(
                onTap: _send,
                child: Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: kSendGrey,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: kShadowDark.withOpacity(0.9),
                        offset: const Offset(4, 4),
                        blurRadius: 8,
                      ),
                      const BoxShadow(
                        color: kShadowLight,
                        offset: Offset(-4, -4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmModal() {
    return Positioned.fill(
      child: Container(
        color: const Color(0x404B5563),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          decoration: neuBox(d: 9, b: 18, radius: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Завершити цей чат?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kTextMain,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Поточну розмову буде завершено, і ми пошукаємо нового співрозмовника.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: NeuButton(
                      label: 'Скасувати',
                      onTap: () => setState(() => _confirmNext = false),
                      color: kTextMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: NeuButton(
                      label: 'Так, далі',
                      onTap: _next,
                      color: kAccentPink,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _RandomBubble extends StatelessWidget {
  final RandomMessage msg;
  final VoidCallback? onReply;

  const _RandomBubble({required this.msg, this.onReply});

  @override
  Widget build(BuildContext context) {
    final bg = randomBubbleBg(msg.fromGender);
    final align = msg.mine ? Alignment.centerRight : Alignment.centerLeft;
    return Align(
      alignment: align,
      child: GestureDetector(
        onLongPress: msg.mine || onReply == null ? null : onReply,
        onHorizontalDragEnd: msg.mine || onReply == null
            ? null
            : (d) {
                if ((d.primaryVelocity ?? 0) > 200) onReply!();
              },
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: randomBubbleShadow(msg.fromGender).withOpacity(0.55),
                offset: const Offset(3, 3),
                blurRadius: 6,
              ),
              const BoxShadow(
                color: kShadowLight,
                offset: Offset(-2, -2),
                blurRadius: 5,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (msg.replyTo != null) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg.replyTo!.from,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: kAccentPink,
                            ),
                          ),
                          Text(
                            msg.replyTo!.text.replaceAll(RegExp(r'\s+'), ' ').trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!msg.mine) ...[
                    Text(
                      genderSign(msg.fromGender),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: onlineColorForGender(msg.fromGender),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      msg.text,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kTextMain,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
