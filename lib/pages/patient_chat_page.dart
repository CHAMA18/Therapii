import 'package:flutter/material.dart';
import 'package:therapii/auth/firebase_auth_manager.dart';
import 'package:therapii/models/chat_message.dart';
import 'package:therapii/models/user.dart' as app_user;
import 'package:therapii/services/chat_service.dart';
import 'package:therapii/services/user_service.dart';

class PatientChatPage extends StatefulWidget {
  final app_user.User otherUser;
  const PatientChatPage({super.key, required this.otherUser});

  @override
  State<PatientChatPage> createState() => _PatientChatPageState();
}

class _PatientChatPageState extends State<PatientChatPage> {
  final FirebaseAuthManager _authManager = FirebaseAuthManager();
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  app_user.User? _viewer;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadViewer();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadViewer() async {
    final firebaseUser = _authManager.currentUser;
    if (firebaseUser == null) {
      setState(() {
        _error = 'You must be signed in to view messages.';
        _loading = false;
      });
      return;
    }

    try {
      final user = await _userService.getUser(firebaseUser.uid);
      if (!mounted) return;
      if (user == null) {
        setState(() {
          _error = 'Profile not found.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _viewer = user;
        _loading = false;
      });
      await _markConversationRead();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load your profile. Please try again.';
        _loading = false;
      });
    }
  }

  String? get _therapistId {
    if (_viewer == null) return null;
    if (_viewer!.isTherapist) return _viewer!.id;
    if (widget.otherUser.isTherapist) return widget.otherUser.id;
    return _viewer!.therapistId;
  }

  String? get _patientId {
    if (_viewer == null) return null;
    if (_viewer!.isTherapist) return widget.otherUser.id;
    return _viewer!.id;
  }

  bool get _viewerIsTherapist => _viewer?.isTherapist ?? false;

  String get _displayName => _fullNameOrEmail(widget.otherUser);

  String _fullNameOrEmail(app_user.User user) {
    final name = user.fullName.trim();
    if (name.isNotEmpty) return name;
    return user.email;
  }

  Future<void> _handleSend() async {
    final viewer = _viewer;
    final therapistId = _therapistId;
    final patientId = _patientId;

    if (viewer == null || therapistId == null || patientId == null) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    try {
      await _chatService.sendMessage(
        therapistId: therapistId,
        patientId: patientId,
        senderId: viewer.id,
        text: text,
        senderIsTherapist: viewer.isTherapist,
      );
      if (!mounted) return;
      _messageController.clear();
      await _markConversationRead();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _markConversationRead() async {
    final therapistId = _therapistId;
    final patientId = _patientId;
    final viewer = _viewer;
    if (therapistId == null || patientId == null || viewer == null) return;
    await _chatService.markConversationRead(
      therapistId: therapistId,
      patientId: patientId,
      viewerIsTherapist: viewer.isTherapist,
    );
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    const bubbleColor = Color(0xFF456BCB);
    final therapistId = _therapistId;
    final patientId = _patientId;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _displayName,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  )
                : (therapistId == null || patientId == null)
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Unable to determine conversation participants.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: StreamBuilder<List<ChatMessage>>(
                              stream: _chatService.streamMessages(
                                therapistId: therapistId,
                                patientId: patientId,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }

                                final messages = snapshot.data ?? [];
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  _markConversationRead();
                                  _scrollToBottom();
                                });

                                if (messages.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          SizedBox(height: 40),
                                          Text(
                                            'Start the conversation by sending a message.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(color: Colors.black54),
                                          ),
                                          SizedBox(height: 40),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                return ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                                  itemCount: messages.length,
                                  itemBuilder: (context, index) {
                                    final message = messages[index];
                                    final viewer = _viewer;
                                    final isMe = viewer != null && message.senderId == viewer.id;
                                    final previous = index > 0 ? messages[index - 1] : null;
                                    final showAvatar = !isMe && (previous == null || previous.senderId == viewer?.id);

                                    return Padding(
                                      padding: EdgeInsets.only(bottom: index == messages.length - 1 ? 0 : 16),
                                      child: _ChatBubble(
                                        text: message.text,
                                        isMe: isMe,
                                        color: bubbleColor,
                                        showAvatar: showAvatar,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          _ChatComposer(
                            controller: _messageController,
                            onSend: _handleSend,
                            sending: _sending,
                          ),
                        ],
                      ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final Color color;
  final bool showAvatar;
  const _ChatBubble({
    required this.text,
    required this.isMe,
    required this.color,
    this.showAvatar = false,
  });

  BorderRadius _bubbleRadius() {
    const radius = Radius.circular(18);
    const flat = Radius.circular(6);
    if (isMe) {
      return const BorderRadius.only(
        topLeft: radius,
        topRight: flat,
        bottomLeft: radius,
        bottomRight: radius,
      );
    }
    return const BorderRadius.only(
      topLeft: flat,
      topRight: radius,
      bottomLeft: radius,
      bottomRight: radius,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = const TextStyle(color: Colors.white, fontSize: 16);
    if (isMe) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: _bubbleRadius(),
              ),
              child: Text(text, style: textStyle),
            ),
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showAvatar) ...[
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFEEF2FC),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: _bubbleRadius(),
            ),
            child: Text(text, style: textStyle),
          ),
        ),
      ],
    );
  }
}

class _ChatComposer extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onSend;
  final bool sending;
  const _ChatComposer({
    required this.controller,
    required this.onSend,
    required this.sending,
  });

  @override
  State<_ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<_ChatComposer> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _hasText = widget.controller.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) {
                if (widget.onSend != null) widget.onSend!();
              },
              decoration: InputDecoration(
                hintText: 'Type your response',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFFE1E5EC)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFF456BCB)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: widget.sending || !_hasText ? null : widget.onSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF456BCB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                elevation: 0,
              ),
              child: widget.sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : const Text(
                      'Send',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}