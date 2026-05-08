class JournalEntry {
  final int? id;
  final String userId;
  final String content;
  final String emoji;
  final DateTime createdAt;
  final DateTime? syncedAt;

  const JournalEntry({
    this.id,
    required this.userId,
    required this.content,
    required this.emoji,
    required this.createdAt,
    this.syncedAt,
  });

  // ── SQLite ────────────────────────────────
  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    return JournalEntry(
      id: map['id'] as int?,
      userId: map['user_id'] as String,
      content: map['content'] as String,
      emoji: map['emoji'] as String? ?? '📝',
      createdAt: DateTime.parse(map['created_at'] as String),
      syncedAt: map['synced_at'] != null
          ? DateTime.parse(map['synced_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'content': content,
      'emoji': emoji,
      'created_at': createdAt.toIso8601String(),
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  // ── Firestore ─────────────────────────────
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'content': content,
      'emoji': emoji,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  JournalEntry copyWith({
    int? id,
    String? content,
    String? emoji,
    DateTime? syncedAt,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      userId: userId,
      content: content ?? this.content,
      emoji: emoji ?? this.emoji,
      createdAt: createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}
