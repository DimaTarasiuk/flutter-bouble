import 'dart:async';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../api_client.dart';
import '../models.dart';
import '../theme/tokens.dart';
import '../widgets/neu.dart';
import '../widgets/message_bubble.dart';
import '../widgets/emoji_panel.dart';
import '../ws/chat_ws_service.dart';

class ChatScreen extends StatefulWidget {
  final AppState appState;
  final AppUser me;
  final Conversation conversation;

  const ChatScreen({
    super.key,
    required this.appState,
    required this.me,
    required this.conversation,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _api = ApiClient();
  final _ws = ChatWsService();
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode();

  final List<ChatMessage> _messages = [];
  final Map<dynamic, ChatMessage> _byId = {};

  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _sending = false;
  bool _showEmoji = false;

  ChatMessage? _replyTarget;
  ChatMessage? _editTarget;

  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    widget.appState.setActiveConversation(widget.conversation.id);
    _loadInitial();
    _connectWs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.appState.setActiveConversation(null);
    _wsSub?.cancel();
    _ws.dispose();
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _connectWs() async {
    await _ws.connect(widget.conversation.id);
    _wsSub = _ws.messages.listen(_onWsEvent);
  }

  void _onWsEvent(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null || type == 'message' || type == 'chat_message') {
      final payload = (data['message'] ?? data) as Map<String, dynamic>;
      final msg = ChatMessage.fromJson(payload, widget.conversation.id);
      final msgId = ChatMessage.normalizeId(msg.id);
      if (msgId != null && _byId.containsKey(msgId)) return;
      if (msg.from == widget.me.username) return;
      setState(() {
        _messages.add(msg);
        if (msgId != null) _byId[msgId] = msg;
      });
      _scrollToBottom();
      _markRead();
    } else if (type == 'message_edited' || type == 'edited') {
      final payload = (data['message'] ?? data) as Map<String, dynamic>;
      final id = payload['id'];
      final idx = _messages.indexWhere((m) => m.id == id);
      if (idx != -1) {
        setState(() {
          _messages[idx] = _messages[idx].copyWith(text: payload['text'] as String?, edited: true);
        });
      }
    }
  }

  Future<void> _loadInitial() async {
    setState(() => _loadingInitial = true);
    try {
      final list = await _api.messages(widget.conversation.id, limit: 50);
      setState(() {
        _messages.clear();
        _byId.clear();
        _messages.addAll(list);
        for (final m in list) {
          final id = ChatMessage.normalizeId(m.id);
          if (id != null) _byId[id] = m;
        }
        _hasMore = list.length >= 50;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animated: false));
      _markRead();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingInitial = false);
    }
  }

  Future<void> _markRead() async {
    try {
      await _api.markRead(widget.conversation.id);
    } catch (_) {}
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 80 && !_loadingMore && _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_messages.isEmpty) return;
    setState(() => _loadingMore = true);
    final oldest = _messages.first;
    final prevExtent = _scrollController.position.maxScrollExtent;
    try {
      final older = await _api.messages(widget.conversation.id, limit: 50, before: oldest.id);
      if (older.isEmpty) {
        setState(() => _hasMore = false);
      } else {
        setState(() {
          _messages.insertAll(0, older);
          for (final m in older) {
            final id = ChatMessage.normalizeId(m.id);
            if (id != null) _byId[id] = m;
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final newExtent = _scrollController.position.maxScrollExtent;
          _scrollController.jumpTo(_scrollController.position.pixels + (newExtent - prevExtent));
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || text.length > 1000) return;

    if (_editTarget != null) {
      final target = _editTarget!;
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == target.id);
        if (idx != -1) _messages[idx] = _messages[idx].copyWith(text: text, edited: true);
        _editTarget = null;
        _inputController.clear();
      });
      try {
        await _api.editMessage(widget.conversation.id, target.id as int, text);
      } catch (_) {}
      return;
    }

    final tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
    final replyTarget = _replyTarget;
    final replyTo = replyTarget?.id;
    final temp = ChatMessage(
      id: tempId,
      conversationId: widget.conversation.id,
      from: widget.me.username,
      text: text,
      replyTo: replyTo,
      replyPreviewFrom: replyTarget?.from,
      replyPreviewText: replyTarget?.text,
      createdAt: DateTime.now(),
      isTemp: true,
    );

    setState(() {
      _messages.add(temp);
      _inputController.clear();
      _replyTarget = null;
      _sending = true;
    });
    _scrollToBottom();

    try {
      final real = await _api.sendMessage(widget.conversation.id, text, replyTo: replyTo);
      var merged = real.replyTo == null && replyTo != null
          ? real.copyWith(replyTo: replyTo)
          : real;
      if ((merged.replyPreviewText == null || merged.replyPreviewText!.isEmpty) &&
          replyTarget != null) {
        merged = merged.copyWith(
          replyTo: replyTo,
          replyPreviewFrom: replyTarget.from,
          replyPreviewText: replyTarget.text,
        );
      }
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == tempId);
        if (idx != -1) {
          _messages[idx] = merged;
          final mid = ChatMessage.normalizeId(merged.id);
          if (mid != null) _byId[mid] = merged;
        }
      });
    } catch (_) {
      setState(() => _messages.removeWhere((m) => m.id == tempId));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showMessageActions(ChatMessage msg, bool isMine, bool canEdit) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: neuBox(d: 6, b: 14, radius: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply, color: kAccentBlue),
              title: const Text('Відповісти', style: TextStyle(color: kTextMain, fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(ctx);
                _startReply(msg);
              },
            ),
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.edit, color: kAccentBlue),
                title: const Text('Редагувати', style: TextStyle(color: kTextMain, fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(ctx);
                  _startEdit(msg);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _startReply(ChatMessage msg) {
    setState(() {
      _replyTarget = msg;
      _editTarget = null;
    });
    _inputFocus.requestFocus();
  }

  void _startEdit(ChatMessage msg) {
    if (!msg.isNumericId) return;
    if (DateTime.now().difference(msg.createdAt).inMinutes >= 10) return;
    setState(() {
      _editTarget = msg;
      _replyTarget = null;
      _inputController.text = msg.text;
    });
    _inputFocus.requestFocus();
  }

  void _cancelComposerState() {
    setState(() {
      _replyTarget = null;
      _editTarget = null;
      _inputController.clear();
      _showEmoji = false;
    });
  }

  void _insertEmoji(String emoji) {
    final sel = _inputController.selection;
    final text = _inputController.text;
    if (sel.start < 0) {
      _inputController.text = text + emoji;
    } else {
      final newText = text.replaceRange(sel.start, sel.end, emoji);
      _inputController.text = newText;
      _inputController.selection = TextSelection.collapsed(offset: sel.start + emoji.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final peerOnline =
            widget.appState.online.contains(widget.conversation.peer);

        return Scaffold(
          backgroundColor: kBg,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(peerOnline),
                Expanded(
                  child: _loadingInitial
                      ? const Center(child: CircularProgressIndicator())
                      : _buildMessageList(),
                ),
                if (_replyTarget != null) _buildReplyBanner(),
                if (_editTarget != null) _buildEditBanner(),
                if (_showEmoji)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: EmojiPanel(onPick: _insertEmoji),
                  ),
                _buildInputBar(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool peerOnline) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: kTextMain),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Avatar(
            username: widget.conversation.peer,
            size: 38,
            bg: const Color(0xFFF5F7FA),
            initialsColor: kAccentPink,
            showDot: true,
            online: peerOnline,
            gender: widget.conversation.peerGender,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.conversation.peer,
                    style: const TextStyle(fontWeight: FontWeight.w800, color: kTextMain)),
                Text(
                  peerOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: peerOnline
                        ? onlineColorForGender(widget.conversation.peerGender)
                        : kTextMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemCount: _messages.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: neuBox(inset: true, d: 3, b: 6, radius: 12),
                child: const Text('Сьогодні', style: TextStyle(fontSize: 11, color: kTextMuted)),
              ),
            ),
          );
        }
        final msg = _messages[index - 1];
        final isMine = msg.from == widget.me.username;
        final canEdit = isMine && msg.isNumericId && DateTime.now().difference(msg.createdAt).inMinutes < 10;

        final replyPreview = _resolveReplyPreview(msg);

        final canInteract = !msg.isTemp;

        return MessageBubble(
          msg: msg,
          isMine: isMine,
          replyPreviewFrom: replyPreview.$1,
          replyPreviewText: replyPreview.$2,
          onSwipeReply: (!isMine && canInteract) ? () => _startReply(msg) : null,
          onLongPress: canInteract ? () => _showMessageActions(msg, isMine, canEdit) : null,
        );
      },
    );
  }

  /// Повертає (from, text) для превʼю реплаю.
  (String?, String?) _resolveReplyPreview(ChatMessage msg) {
    if (msg.replyPreviewText != null || msg.replyPreviewFrom != null) {
      return (msg.replyPreviewFrom, msg.replyPreviewText);
    }
    if (msg.replyTo == null) return (null, null);

    final direct = _byId[msg.replyTo] ?? _byId[ChatMessage.normalizeId(msg.replyTo)];
    if (direct != null) return (direct.from, direct.text);

    for (final m in _messages) {
      if (ChatMessage.idsEqual(m.id, msg.replyTo)) {
        return (m.from, m.text);
      }
    }
    return (null, null);
  }

  Widget _buildReplyBanner() {
    final target = _replyTarget!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: neuBox(inset: true, d: 3, b: 6, radius: 14),
      child: Row(
        children: [
          Container(width: 3, height: 32, color: kAccentPink),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Відповідь · ${target.from}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: kAccentPink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  target.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: kTextMuted),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _cancelComposerState,
            child: const Icon(Icons.close, size: 16, color: kTextMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildEditBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: neuBox(inset: true, d: 3, b: 6, radius: 14),
      child: Row(
        children: [
          const Expanded(
            child: Text('Редагування',
                style: TextStyle(fontSize: 12.5, color: kAccentBlue, fontWeight: FontWeight.w700)),
          ),
          GestureDetector(
            onTap: _cancelComposerState,
            child: const Text('Скасувати', style: TextStyle(fontSize: 12.5, color: kTextMuted)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: NeuTextField(
              controller: _inputController,
              hint: 'Повідомлення...',
              minLines: 1,
              maxLines: 4,
              maxLength: 1000,
              focusNode: _inputFocus,
              onSubmitted: (_) => _send(),
              radius: 22,
              insetDepth: 3,
              verticalPadding: 8,
              trailing: GestureDetector(
                onTap: () => setState(() => _showEmoji = !_showEmoji),
                child: Icon(
                  Icons.emoji_emotions_outlined,
                  color: _showEmoji ? kAccentBlue : kTextMuted,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          NeuPress(
            pressedScale: 0.93,
            onTap: _sending ? null : _send,
            child: Container(
              width: 44,
              height: 44,
              decoration: neuBox(d: 4, b: 8, radius: 22, color: kSendGrey),
              child: const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
