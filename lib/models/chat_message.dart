class ChatMessage {
  final int? id;
  final String userId;
  final String role; // 'user' | 'assistant' | 'system'
  final String content;
  final DateTime timestamp;
  final bool isError;

  const ChatMessage({
    this.id,
    required this.userId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isError = false,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as int?,
      userId: map['user_id'] as String,
      role: map['role'] as String,
      content: map['content'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isError: (map['is_error'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'is_error': isError ? 1 : 0,
    };
  }

  // For OpenAI API request body
  Map<String, String> toApiMessage() {
    return {
      'role': role == 'assistant' ? 'assistant' : 'user',
      'content': content,
    };
  }

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
}
