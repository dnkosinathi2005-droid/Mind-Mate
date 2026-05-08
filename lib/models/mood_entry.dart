class MoodEntry {
  final int? id;
  final String userId;
  final int moodScore; // 1–10
  final String moodLabel;
  final String note;
  final DateTime createdAt;
  final DateTime? syncedAt;

  const MoodEntry({
    this.id,
    required this.userId,
    required this.moodScore,
    required this.moodLabel,
    required this.note,
    required this.createdAt,
    this.syncedAt,
  });

  // ── SQLite ────────────────────────────────
  factory MoodEntry.fromMap(Map<String, dynamic> map) {
    return MoodEntry(
      id: map['id'] as int?,
      userId: map['user_id'] as String,
      moodScore: map['mood_score'] as int,
      moodLabel: map['mood_label'] as String,
      note: map['note'] as String? ?? '',
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
      'mood_score': moodScore,
      'mood_label': moodLabel,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'moodScore': moodScore,
      'moodLabel': moodLabel,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  MoodEntry copyWith({DateTime? syncedAt}) {
    return MoodEntry(
      id: id,
      userId: userId,
      moodScore: moodScore,
      moodLabel: moodLabel,
      note: note,
      createdAt: createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  // ── Helpers ───────────────────────────────
  static String labelForScore(int score) {
    const labels = {
      1: 'Terrible',
      2: 'Very bad',
      3: 'Bad',
      4: 'Low',
      5: 'Okay',
      6: 'Fine',
      7: 'Good',
      8: 'Great',
      9: 'Excellent',
      10: 'Amazing',
    };
    return labels[score] ?? 'Unknown';
  }

  static String emojiForScore(int score) {
    const emojis = {
      1: '😭',
      2: '😢',
      3: '😞',
      4: '😕',
      5: '😐',
      6: '🙂',
      7: '😊',
      8: '😁',
      9: '🤩',
      10: '🥳',
    };
    return emojis[score] ?? '😐';
  }
}
