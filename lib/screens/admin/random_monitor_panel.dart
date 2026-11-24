import 'dart:async';

import 'package:flutter/material.dart';

import '../../admin_api_client.dart';
import '../../api_client.dart';
import '../../random/random_models.dart';
import '../../widgets/neu.dart';

class RandomMonitorPanel extends StatefulWidget {
  const RandomMonitorPanel({super.key});

  @override
  State<RandomMonitorPanel> createState() => _RandomMonitorPanelState();
}

class _RandomMonitorPanelState extends State<RandomMonitorPanel> {
  final _admin = AdminApiClient();
  final _scroll = ScrollController();

  String _status = 'active';
  List<RandomSessionAdmin> _sessions = [];
  bool _loading = true;
  String? _error;
  bool _deleting = false;

  int? _selectedId;
  RandomSessionAdminDetail? _detail;
  bool _detailLoading = false;

  Timer? _listPoll;
  Timer? _detailPoll;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _listPoll = Timer.periodic(const Duration(seconds: 6), (_) => _loadSessions(soft: true));
  }

  @override
  void dispose() {
    _listPoll?.cancel();
    _detailPoll?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadSessions({bool soft = false}) async {
    if (!soft) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await _admin.randomSessions(status: _status, limit: 50);
      if (!mounted) return;
      setState(() {
        _sessions = list;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.code == 'forbidden'
            ? 'Доступ лише для head'
            : (e.userMessage);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Не вдалося завантажити');
    } finally {
      if (mounted && !soft) setState(() => _loading = false);
    }
  }

  Future<void> _loadDetail(int id, {bool soft = false}) async {
    if (!soft) setState(() => _detailLoading = true);
    try {
      final detail = await _admin.randomSession(id);
      if (!mounted || _selectedId != id) return;
      setState(() {
        _detail = detail;
        _sessions = _sessions
            .map((s) => s.id == detail.session.id ? detail.session : s)
            .toList();
      });
      _scrollToBottom();
    } on ApiException catch (e) {
      if (!soft && mounted) {
        setState(() => _error = e.userMessage);
      }
    } catch (_) {
      if (!soft && mounted) {
        setState(() => _error = 'Не вдалося відкрити чат');
      }
    } finally {
      if (mounted && !soft) setState(() => _detailLoading = false);
    }
  }

  void _openSession(int id) {
    _detailPoll?.cancel();
    setState(() {
      _selectedId = id;
      _detail = null;
      _error = null;
    });
    _loadDetail(id);
    _detailPoll = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _loadDetail(id, soft: true),
    );
  }

  void _closeDetail() {
    _detailPoll?.cancel();
    setState(() {
      _selectedId = null;
      _detail = null;
    });
  }

  void _setStatus(String status) {
    if (_status == status) return;
    _closeDetail();
    setState(() {
      _status = status;
      _sessions = [];
    });
    _loadSessions();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _confirmDelete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBg,
        title: Text('Видалити завершений чат #$id?', style: const TextStyle(color: kTextMain)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Скасувати'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Видалити', style: TextStyle(color: kAccentPink)),
          ),
        ],
      ),
    );
    if (ok == true) await _deleteSession(id);
  }

  Future<void> _deleteSession(int id) async {
    if (_deleting) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await _admin.deleteRandomSession(id);
      if (!mounted) return;
      setState(() {
        _sessions = _sessions.where((s) => s.id != id).toList();
        if (_selectedId == id) {
          _selectedId = null;
          _detail = null;
          _detailPoll?.cancel();
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.code == 'session active'
            ? 'Активний чат не можна видалити'
            : e.userMessage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Не вдалося видалити');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _confirmDeleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBg,
        title: const Text(
          'Видалити всі завершені random-чати?',
          style: TextStyle(color: kTextMain),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Скасувати'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Очистити', style: TextStyle(color: kAccentPink)),
          ),
        ],
      ),
    );
    if (ok != true || _deleting) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await _admin.deleteAllEndedRandomSessions();
      if (!mounted) return;
      if (_detail?.session.status == 'ended' || _status == 'ended') {
        _closeDetail();
      }
      await _loadSessions();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.userMessage);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Не вдалося очистити');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  String _formatDt(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedId != null) return _buildDetail();
    return _buildList();
  }

  Widget _buildList() {
    final showClear = (_status == 'ended' || _status == 'all') &&
        _sessions.any((s) => s.status == 'ended');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              _filterChip('active', 'Активні'),
              const SizedBox(width: 6),
              _filterChip('ended', 'Завершені'),
              const SizedBox(width: 6),
              _filterChip('all', 'Усі'),
            ],
          ),
        ),
        if (showClear)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: NeuPress(
              onTap: _deleting ? null : _confirmDeleteAll,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: neuBox(d: 3, b: 6, radius: 50),
                child: Text(
                  _deleting ? 'Видалення...' : 'Очистити всі завершені',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: kAccentPink.withValues(alpha: _deleting ? 0.7 : 1),
                  ),
                ),
              ),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kAccentPink,
              ),
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _sessions.isEmpty
                  ? const Center(
                      child: Text(
                        'Немає чатів',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kTextMuted,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadSessions,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        itemCount: _sessions.length,
                        itemBuilder: (context, i) => _sessionRow(_sessions[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _filterChip(String id, String label) {
    final active = _status == id;
    return Expanded(
      child: NeuPress(
        onTap: () => _setStatus(id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: active
              ? neuBox(inset: true, d: 3, b: 6, radius: 50)
              : neuBox(d: 3, b: 6, radius: 50),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: active ? kAccentBlue : kTextMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sessionRow(RandomSessionAdmin s) {
    final live = s.isActive;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: NeuPress(
              onTap: () => _openSession(s.id),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: neuBox(d: 3, b: 6, radius: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '#${s.id} · ${s.guestA.title} × ${s.guestB.title}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: kTextMain,
                            ),
                          ),
                        ),
                        Text(
                          live ? '● live' : 'ended',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: live ? kOnlineMale : kTextMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDt(s.lastMessageAt ?? s.createdAt)} · ${s.messageCount} пов.',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: kTextMuted,
                      ),
                    ),
                    if (s.lastText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        s.lastText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (!live) ...[
            const SizedBox(width: 6),
            NeuPress(
              onTap: _deleting ? null : () => _confirmDelete(s.id),
              child: Container(
                width: 40,
                alignment: Alignment.center,
                decoration: neuBox(d: 3, b: 6, radius: 16),
                child: const Text(
                  '✕',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: kAccentPink,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetail() {
    final detail = _detail;
    if (_detailLoading && detail == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (detail == null) {
      return Center(
        child: TextButton(
          onPressed: _closeDetail,
          child: const Text('← Назад', style: TextStyle(color: kTextMuted)),
        ),
      );
    }

    final session = detail.session;
    final live = session.isActive;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              IconButton(
                onPressed: _closeDetail,
                icon: const Icon(Icons.arrow_back, color: kTextMuted, size: 20),
              ),
              Avatar(
                username: genderSign(session.guestA.gender),
                size: 36,
                initialsColor: onlineColorForGender(session.guestA.gender),
                showDot: true,
                online: live,
                gender: session.guestA.gender,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${session.id} · ${session.guestA.title} × ${session.guestB.title}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: kTextMain,
                      ),
                    ),
                    Text(
                      live
                          ? '● Активний чат · лише перегляд'
                          : 'Завершений · лише перегляд',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: live ? kOnlineMale : kTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (!live)
                NeuPress(
                  onTap: _deleting ? null : () => _confirmDelete(session.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: neuBox(d: 3, b: 6, radius: 50),
                    child: Text(
                      _deleting ? '...' : 'Видалити',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: kAccentPink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: kDivider),
        Expanded(
          child: detail.messages.isEmpty
              ? const Center(
                  child: Text(
                    'Повідомлень ще немає',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kTextMuted,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                  itemCount: detail.messages.length,
                  itemBuilder: (context, i) {
                    final m = detail.messages[i];
                    final alignLeft = m.fromGuest == session.guestA.id;
                    return _AdminBubble(msg: m, alignLeft: alignLeft);
                  },
                ),
        ),
      ],
    );
  }
}

class _AdminBubble extends StatelessWidget {
  final RandomMessage msg;
  final bool alignLeft;

  const _AdminBubble({required this.msg, required this.alignLeft});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: randomBubbleBg(msg.fromGender),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: randomBubbleShadow(msg.fromGender).withValues(alpha: 0.55),
              offset: const Offset(3, 3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.replyTo != null) ...[
              Text(
                msg.replyTo!.from,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: kAccentPink,
                ),
              ),
              Text(
                msg.replyTo!.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 6),
            ],
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  genderSign(msg.fromGender),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: onlineColorForGender(msg.fromGender),
                  ),
                ),
                const SizedBox(width: 6),
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
    );
  }
}
