import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';
import '../models/chat_message.dart';
import '../models/journal_entry.dart';
import '../models/meditation_session.dart';
import '../models/mood_entry.dart';

class LocalDbService {
  LocalDbService._();
  static final LocalDbService instance = LocalDbService._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = join(await getDatabasesPath(), AppConstants.dbName);
    return openDatabase(
      dbPath,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE journal_entries (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id     TEXT    NOT NULL,
        content     TEXT    NOT NULL,
        emoji       TEXT    NOT NULL DEFAULT '📝',
        created_at  TEXT    NOT NULL,
        synced_at   TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE mood_entries (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id     TEXT    NOT NULL,
        mood_score  INTEGER NOT NULL,
        mood_label  TEXT    NOT NULL,
        note        TEXT    NOT NULL DEFAULT '',
        created_at  TEXT    NOT NULL,
        synced_at   TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE chat_messages (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id     TEXT    NOT NULL,
        role        TEXT    NOT NULL,
        content     TEXT    NOT NULL,
        timestamp   TEXT    NOT NULL,
        is_error    INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE meditation_sessions (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id             TEXT    NOT NULL,
        duration_seconds    INTEGER NOT NULL,
        type                TEXT    NOT NULL DEFAULT 'breathing',
        completed           INTEGER NOT NULL DEFAULT 0,
        completed_at        TEXT    NOT NULL,
        distance_meters     REAL    NOT NULL DEFAULT 0,
        steps               INTEGER NOT NULL DEFAULT 0,
        avg_pace_min_per_km REAL    NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_journal_user   ON journal_entries(user_id)');
    await db.execute('CREATE INDEX idx_mood_user      ON mood_entries(user_id)');
    await db.execute('CREATE INDEX idx_chat_user      ON chat_messages(user_id, timestamp)');
    await db.execute('CREATE INDEX idx_meditation_user ON meditation_sessions(user_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS chat_messages (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id     TEXT    NOT NULL,
          role        TEXT    NOT NULL,
          content     TEXT    NOT NULL,
          timestamp   TEXT    NOT NULL,
          is_error    INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_chat_user ON chat_messages(user_id, timestamp)');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS meditation_sessions (
          id                  INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id             TEXT    NOT NULL,
          duration_seconds    INTEGER NOT NULL,
          type                TEXT    NOT NULL DEFAULT 'breathing',
          completed           INTEGER NOT NULL DEFAULT 0,
          completed_at        TEXT    NOT NULL,
          distance_meters     REAL    NOT NULL DEFAULT 0,
          steps               INTEGER NOT NULL DEFAULT 0,
          avg_pace_min_per_km REAL    NOT NULL DEFAULT 0
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_meditation_user ON meditation_sessions(user_id)');
    }
    if (oldVersion < 4) {
      // Add new columns to existing meditation_sessions table
      try {
        await db.execute(
            'ALTER TABLE meditation_sessions ADD COLUMN distance_meters REAL NOT NULL DEFAULT 0');
        await db.execute(
            'ALTER TABLE meditation_sessions ADD COLUMN steps INTEGER NOT NULL DEFAULT 0');
        await db.execute(
            'ALTER TABLE meditation_sessions ADD COLUMN avg_pace_min_per_km REAL NOT NULL DEFAULT 0');
      } catch (_) {
        // Columns may already exist if upgrading from a partial state
      }
    }
  }

  // ── Journal ───────────────────────────────
  Future<int> insertJournal(JournalEntry entry) async {
    final db = await database;
    return db.insert('journal_entries', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<JournalEntry>> getJournalEntries(String userId) async {
    final db = await database;
    final rows = await db.query('journal_entries',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'created_at DESC');
    return rows.map(JournalEntry.fromMap).toList();
  }

  Future<JournalEntry?> getJournalEntry(int id) async {
    final db = await database;
    final rows = await db.query('journal_entries',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return JournalEntry.fromMap(rows.first);
  }

  Future<int> updateJournal(JournalEntry entry) async {
    final db = await database;
    return db.update('journal_entries', entry.toMap(),
        where: 'id = ?', whereArgs: [entry.id]);
  }

  Future<int> deleteJournal(int id) async {
    final db = await database;
    return db.delete('journal_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<JournalEntry>> getUnsyncedJournals(String userId) async {
    final db = await database;
    final rows = await db.query('journal_entries',
        where: 'user_id = ? AND synced_at IS NULL', whereArgs: [userId]);
    return rows.map(JournalEntry.fromMap).toList();
  }

  Future<void> markJournalSynced(int id) async {
    final db = await database;
    await db.update('journal_entries',
        {'synced_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }

  // ── Mood ──────────────────────────────────
  Future<int> insertMood(MoodEntry entry) async {
    final db = await database;
    return db.insert('mood_entries', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<MoodEntry>> getMoodEntries(String userId) async {
    final db = await database;
    final rows = await db.query('mood_entries',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'created_at DESC');
    return rows.map(MoodEntry.fromMap).toList();
  }

  Future<List<MoodEntry>> getRecentMoodEntries(String userId,
      {int days = 7}) async {
    final db = await database;
    final since =
        DateTime.now().subtract(Duration(days: days)).toIso8601String();
    final rows = await db.query('mood_entries',
        where: 'user_id = ? AND created_at >= ?',
        whereArgs: [userId, since],
        orderBy: 'created_at ASC');
    return rows.map(MoodEntry.fromMap).toList();
  }

  Future<MoodEntry?> getTodayMood(String userId) async {
    final db = await database;
    final today = DateTime.now();
    final start =
        DateTime(today.year, today.month, today.day).toIso8601String();
    final end = DateTime(today.year, today.month, today.day, 23, 59, 59)
        .toIso8601String();
    final rows = await db.query('mood_entries',
        where: 'user_id = ? AND created_at >= ? AND created_at <= ?',
        whereArgs: [userId, start, end],
        orderBy: 'created_at DESC',
        limit: 1);
    if (rows.isEmpty) return null;
    return MoodEntry.fromMap(rows.first);
  }

  Future<int> deleteMood(int id) async {
    final db = await database;
    return db.delete('mood_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<MoodEntry>> getUnsyncedMoods(String userId) async {
    final db = await database;
    final rows = await db.query('mood_entries',
        where: 'user_id = ? AND synced_at IS NULL', whereArgs: [userId]);
    return rows.map(MoodEntry.fromMap).toList();
  }

  Future<void> markMoodSynced(int id) async {
    final db = await database;
    await db.update('mood_entries',
        {'synced_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }

  // ── Chat ──────────────────────────────────
  Future<int> insertChatMessage(ChatMessage msg) async {
    final db = await database;
    return db.insert('chat_messages', msg.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ChatMessage>> getChatHistory(String userId,
      {int limit = 20}) async {
    final db = await database;
    final rows = await db.query(
      'chat_messages',
      where: 'user_id = ? AND is_error = 0',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.reversed.map(ChatMessage.fromMap).toList();
  }

  Future<List<ChatMessage>> getAllChatMessages(String userId) async {
    final db = await database;
    final rows = await db.query('chat_messages',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'timestamp ASC');
    return rows.map(ChatMessage.fromMap).toList();
  }

  Future<void> clearChatHistory(String userId) async {
    final db = await database;
    await db.delete('chat_messages',
        where: 'user_id = ?', whereArgs: [userId]);
  }

  // ── Meditation ────────────────────────────
  Future<int> insertMeditationSession(MeditationSession session) async {
    final db = await database;
    return db.insert('meditation_sessions', session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<MeditationSession>> getMeditationSessions(
      String userId) async {
    final db = await database;
    final rows = await db.query('meditation_sessions',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'completed_at DESC');
    return rows.map(MeditationSession.fromMap).toList();
  }

  Future<int> getTotalMeditationSeconds(String userId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(duration_seconds) as total FROM meditation_sessions WHERE user_id = ? AND completed = 1',
      [userId],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> getMeditationStreakDays(String userId) async {
    final sessions = await getMeditationSessions(userId);
    if (sessions.isEmpty) return 0;

    int streak = 0;
    DateTime cursor = DateTime.now();

    for (final session in sessions) {
      if (!session.completed) continue;
      final sessionDate = DateTime(
        session.completedAt.year,
        session.completedAt.month,
        session.completedAt.day,
      );
      final cursorDate =
          DateTime(cursor.year, cursor.month, cursor.day);
      if (sessionDate == cursorDate ||
          sessionDate ==
              cursorDate.subtract(const Duration(days: 1))) {
        streak++;
        cursor = sessionDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  // ── Close ─────────────────────────────────
  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}




/*import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';
import '../models/chat_message.dart';
import '../models/journal_entry.dart';
import '../models/meditation_session.dart';
import '../models/mood_entry.dart';

class LocalDbService {
  LocalDbService._();
  static final LocalDbService instance = LocalDbService._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = join(await getDatabasesPath(), AppConstants.dbName);
    return openDatabase(
      dbPath,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE journal_entries (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id     TEXT    NOT NULL,
        content     TEXT    NOT NULL,
        emoji       TEXT    NOT NULL DEFAULT '📝',
        created_at  TEXT    NOT NULL,
        synced_at   TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE mood_entries (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id     TEXT    NOT NULL,
        mood_score  INTEGER NOT NULL,
        mood_label  TEXT    NOT NULL,
        note        TEXT    NOT NULL DEFAULT '',
        created_at  TEXT    NOT NULL,
        synced_at   TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE chat_messages (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id     TEXT    NOT NULL,
        role        TEXT    NOT NULL,
        content     TEXT    NOT NULL,
        timestamp   TEXT    NOT NULL,
        is_error    INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE meditation_sessions (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id          TEXT    NOT NULL,
        duration_seconds INTEGER NOT NULL,
        type             TEXT    NOT NULL DEFAULT 'breathing',
        completed        INTEGER NOT NULL DEFAULT 0,
        completed_at     TEXT    NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_journal_user   ON journal_entries(user_id)');
    await db.execute('CREATE INDEX idx_mood_user      ON mood_entries(user_id)');
    await db.execute('CREATE INDEX idx_chat_user      ON chat_messages(user_id, timestamp)');
    await db.execute('CREATE INDEX idx_meditation_user ON meditation_sessions(user_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS chat_messages (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id     TEXT    NOT NULL,
          role        TEXT    NOT NULL,
          content     TEXT    NOT NULL,
          timestamp   TEXT    NOT NULL,
          is_error    INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_chat_user ON chat_messages(user_id, timestamp)');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS meditation_sessions (
          id               INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id          TEXT    NOT NULL,
          duration_seconds INTEGER NOT NULL,
          type             TEXT    NOT NULL DEFAULT 'breathing',
          completed        INTEGER NOT NULL DEFAULT 0,
          completed_at     TEXT    NOT NULL
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_meditation_user ON meditation_sessions(user_id)');
    }
  }

  // ── Journal ───────────────────────────────
  Future<int> insertJournal(JournalEntry entry) async {
    final db = await database;
    return db.insert('journal_entries', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<JournalEntry>> getJournalEntries(String userId) async {
    final db = await database;
    final rows = await db.query('journal_entries',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'created_at DESC');
    return rows.map(JournalEntry.fromMap).toList();
  }

  Future<JournalEntry?> getJournalEntry(int id) async {
    final db = await database;
    final rows = await db.query('journal_entries',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return JournalEntry.fromMap(rows.first);
  }

  Future<int> updateJournal(JournalEntry entry) async {
    final db = await database;
    return db.update('journal_entries', entry.toMap(),
        where: 'id = ?', whereArgs: [entry.id]);
  }

  Future<int> deleteJournal(int id) async {
    final db = await database;
    return db.delete('journal_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<JournalEntry>> getUnsyncedJournals(String userId) async {
    final db = await database;
    final rows = await db.query('journal_entries',
        where: 'user_id = ? AND synced_at IS NULL', whereArgs: [userId]);
    return rows.map(JournalEntry.fromMap).toList();
  }

  Future<void> markJournalSynced(int id) async {
    final db = await database;
    await db.update('journal_entries',
        {'synced_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }

  // ── Mood ──────────────────────────────────
  Future<int> insertMood(MoodEntry entry) async {
    final db = await database;
    return db.insert('mood_entries', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<MoodEntry>> getMoodEntries(String userId) async {
    final db = await database;
    final rows = await db.query('mood_entries',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'created_at DESC');
    return rows.map(MoodEntry.fromMap).toList();
  }

  Future<List<MoodEntry>> getRecentMoodEntries(String userId,
      {int days = 7}) async {
    final db = await database;
    final since =
        DateTime.now().subtract(Duration(days: days)).toIso8601String();
    final rows = await db.query('mood_entries',
        where: 'user_id = ? AND created_at >= ?',
        whereArgs: [userId, since],
        orderBy: 'created_at ASC');
    return rows.map(MoodEntry.fromMap).toList();
  }

  Future<MoodEntry?> getTodayMood(String userId) async {
    final db = await database;
    final today = DateTime.now();
    final start =
        DateTime(today.year, today.month, today.day).toIso8601String();
    final end = DateTime(today.year, today.month, today.day, 23, 59, 59)
        .toIso8601String();
    final rows = await db.query('mood_entries',
        where: 'user_id = ? AND created_at >= ? AND created_at <= ?',
        whereArgs: [userId, start, end],
        orderBy: 'created_at DESC',
        limit: 1);
    if (rows.isEmpty) return null;
    return MoodEntry.fromMap(rows.first);
  }

  Future<int> deleteMood(int id) async {
    final db = await database;
    return db.delete('mood_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<MoodEntry>> getUnsyncedMoods(String userId) async {
    final db = await database;
    final rows = await db.query('mood_entries',
        where: 'user_id = ? AND synced_at IS NULL', whereArgs: [userId]);
    return rows.map(MoodEntry.fromMap).toList();
  }

  Future<void> markMoodSynced(int id) async {
    final db = await database;
    await db.update('mood_entries',
        {'synced_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }

  // ── Chat ──────────────────────────────────
  Future<int> insertChatMessage(ChatMessage msg) async {
    final db = await database;
    return db.insert('chat_messages', msg.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ChatMessage>> getChatHistory(String userId,
      {int limit = 20}) async {
    final db = await database;
    final rows = await db.query(
      'chat_messages',
      where: 'user_id = ? AND is_error = 0',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.reversed.map(ChatMessage.fromMap).toList();
  }

  Future<List<ChatMessage>> getAllChatMessages(String userId) async {
    final db = await database;
    final rows = await db.query('chat_messages',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'timestamp ASC');
    return rows.map(ChatMessage.fromMap).toList();
  }

  Future<void> clearChatHistory(String userId) async {
    final db = await database;
    await db.delete('chat_messages',
        where: 'user_id = ?', whereArgs: [userId]);
  }

  // ── Meditation ────────────────────────────
  Future<int> insertMeditationSession(MeditationSession session) async {
    final db = await database;
    return db.insert('meditation_sessions', session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<MeditationSession>> getMeditationSessions(
      String userId) async {
    final db = await database;
    final rows = await db.query('meditation_sessions',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'completed_at DESC');
    return rows.map(MeditationSession.fromMap).toList();
  }

  Future<int> getTotalMeditationSeconds(String userId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(duration_seconds) as total FROM meditation_sessions WHERE user_id = ? AND completed = 1',
      [userId],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> getMeditationStreakDays(String userId) async {
    final sessions = await getMeditationSessions(userId);
    if (sessions.isEmpty) return 0;

    int streak = 0;
    DateTime cursor = DateTime.now();

    for (final session in sessions) {
      if (!session.completed) continue;
      final sessionDate = DateTime(
        session.completedAt.year,
        session.completedAt.month,
        session.completedAt.day,
      );
      final cursorDate =
          DateTime(cursor.year, cursor.month, cursor.day);
      if (sessionDate == cursorDate ||
          sessionDate ==
              cursorDate.subtract(const Duration(days: 1))) {
        streak++;
        cursor = sessionDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  // ── Close ─────────────────────────────────
  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
*/