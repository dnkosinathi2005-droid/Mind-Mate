import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/chat_message.dart';
import '../../models/mood_entry.dart';
import '../../services/local_db_service.dart';
import '../../services/openai_service.dart';
import 'chat_bubble.dart';
import 'emergency_bar.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _inputFocus = FocusNode();

  List<ChatMessage> _messages = [];
  MoodEntry? _todayMood;
  bool _isLoading = true;
  bool _isTyping = false;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _loadData();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_uid == null) return;
    final messages = await LocalDbService.instance.getAllChatMessages(_uid!);
    final todayMood = await LocalDbService.instance.getTodayMood(_uid!);

    if (mounted) {
      setState(() {
        _messages = messages;
        _todayMood = todayMood;
        _isLoading = false;
      });

      // Show greeting if this is a fresh conversation
      if (_messages.isEmpty) {
        _insertGreeting();
      } else {
        _scrollToBottom();
      }
    }
  }

  void _insertGreeting() {
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    String greeting;
    if (_todayMood != null) {
      greeting =
          '$timeGreeting! I can see you logged your mood as '
          '"${_todayMood!.moodLabel}" today. '
          'I\'m here to listen and support you. '
          'How are you feeling right now?';
    } else {
      greeting =
          '$timeGreeting! I\'m MindMate, your mental wellness companion. '
          'I\'m here to listen, support, and chat with you. '
          'How are you feeling today?';
    }

    _addMessage(ChatMessage(
      userId: _uid!,
      role: 'assistant',
      content: greeting,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _isTyping) return;

    _messageCtrl.clear();
    _inputFocus.requestFocus();

    // Add user message
    final userMsg = ChatMessage(
      userId: _uid!,
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );
    await LocalDbService.instance.insertChatMessage(userMsg);
    _addMessage(userMsg);

    setState(() => _isTyping = true);
    _scrollToBottom();

    try {
      // Fetch recent history for context window
      final history = await LocalDbService.instance
          .getChatHistory(_uid!, limit: 20);

      final reply = await OpenAIService.instance.sendMessage(
        userMessage: text,
        userId: _uid!,
        history: history,
        todayMood: _todayMood,
      );

      final assistantMsg = ChatMessage(
        userId: _uid!,
        role: 'assistant',
        content: reply,
        timestamp: DateTime.now(),
      );
      await LocalDbService.instance.insertChatMessage(assistantMsg);

      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(assistantMsg);
        });
        _scrollToBottom();
      }
    } catch (e) {
      final errMsg = ChatMessage(
        userId: _uid!,
        role: 'assistant',
        content: _friendlyError(e.toString()),
        timestamp: DateTime.now(),
        isError: true,
      );
      await LocalDbService.instance.insertChatMessage(errMsg);
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(errMsg);
        });
        _scrollToBottom();
      }
    }
  }

  void _addMessage(ChatMessage msg) {
    setState(() => _messages.add(msg));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear conversation'),
        content: const Text(
            'This will delete all messages in this conversation. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await LocalDbService.instance.clearChatHistory(_uid!);
    if (mounted) {
      setState(() => _messages.clear());
      _insertGreeting();
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('API key')) {
      return 'The AI service is not configured yet. Please add your OpenAI API key to the .env file.';
    }
    if (raw.contains('rate limit')) {
      return 'The AI is a bit busy right now. Please wait a moment and try again.';
    }
    if (raw.contains('network') || raw.contains('SocketException')) {
      return 'I could not reach the AI service. Please check your internet connection.';
    }
    return 'Something went wrong. Please try again in a moment.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.splashGradient,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🧠', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MindMate', style: AppTextStyles.titleMedium),
                Text(
                  'Your wellness companion',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Mood context chip
          if (_todayMood != null)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    MoodEntry.emojiForScore(_todayMood!.moodScore),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_todayMood!.moodScore}/10',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, size: 22),
            onPressed: _clearHistory,
            tooltip: 'Clear conversation',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Chat messages ──────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount:
                        _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isTyping && index == _messages.length) {
                        return const TypingIndicator();
                      }
                      return ChatBubble(message: _messages[index]);
                    },
                  ),
          ),

          // ── Message input ──────────────────
          _MessageInput(
            controller: _messageCtrl,
            focusNode: _inputFocus,
            isTyping: _isTyping,
            onSend: _sendMessage,
          ),

          // ── Emergency contacts bar ─────────
          const EmergencyBar(),
        ],
      ),
    );
  }
}

// ── Message input bar ─────────────────────────
class _MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isTyping;
  final VoidCallback onSend;

  const _MessageInput({
    required this.controller,
    required this.focusNode,
    required this.isTyping,
    required this.onSend,
  });

  @override
  State<_MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<_MessageInput> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(
        () => setState(() => _hasText = widget.controller.text.isNotEmpty));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.textHint.withValues(alpha: 0.15)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Suggestion chips
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                enabled: !widget.isTyping,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: widget.isTyping
                      ? 'MindMate is typing...'
                      : 'Type a message...',
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => widget.onSend(),
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: (_hasText && !widget.isTyping) ? widget.onSend : null,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: (_hasText && !widget.isTyping)
                        ? AppColors.splashGradient
                        : null,
                    color: (!_hasText || widget.isTyping)
                        ? AppColors.surfaceVariant
                        : null,
                    shape: BoxShape.circle,
                  ),
                  child: widget.isTyping
                      ? const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          size: 20,
                          color: _hasText ? Colors.white : AppColors.textHint,
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
