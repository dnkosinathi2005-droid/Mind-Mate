class MeditationSession {
  final int? id;
  final String userId;
  final int durationSeconds;
  final String type; // 'breathing' | 'walking' | 'running'
  final bool completed;
  final DateTime completedAt;
  final double distanceMeters;   // walking / running only
  final int steps;               // walking / running only
  final double avgPaceMinPerKm;  // running only

  const MeditationSession({
    this.id,
    required this.userId,
    required this.durationSeconds,
    required this.type,
    required this.completed,
    required this.completedAt,
    this.distanceMeters = 0,
    this.steps = 0,
    this.avgPaceMinPerKm = 0,
  });

  factory MeditationSession.fromMap(Map<String, dynamic> map) {
    return MeditationSession(
      id: map['id'] as int?,
      userId: map['user_id'] as String,
      durationSeconds: map['duration_seconds'] as int,
      type: map['type'] as String? ?? 'breathing',
      completed: (map['completed'] as int? ?? 0) == 1,
      completedAt: DateTime.parse(map['completed_at'] as String),
      distanceMeters: (map['distance_meters'] as num?)?.toDouble() ?? 0,
      steps: map['steps'] as int? ?? 0,
      avgPaceMinPerKm:
          (map['avg_pace_min_per_km'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'duration_seconds': durationSeconds,
      'type': type,
      'completed': completed ? 1 : 0,
      'completed_at': completedAt.toIso8601String(),
      'distance_meters': distanceMeters,
      'steps': steps,
      'avg_pace_min_per_km': avgPaceMinPerKm,
    };
  }

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    if (m == 0) return '${s}s';
    if (s == 0) return '${m}m';
    return '${m}m ${s}s';
  }

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.toStringAsFixed(0)}m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(2)}km';
  }

  String get formattedPace {
    if (avgPaceMinPerKm == 0) return '--';
    final min = avgPaceMinPerKm.floor();
    final sec = ((avgPaceMinPerKm - min) * 60).round();
    return "$min'${sec.toString().padLeft(2, '0')}\"/km";
  }

  String get typeEmoji {
    switch (type) {
      case 'walking': return '🚶';
      case 'running': return '🏃';
      default:        return '🧘';
    }
  }

  String get typeLabel {
    switch (type) {
      case 'walking': return 'Walking meditation';
      case 'running': return 'Running meditation';
      default:        return 'Breathing meditation';
    }
  }
}






/*class MeditationSession {
  final int? id;
  final String userId;
  final int durationSeconds;
  final String type; // 'breathing' | 'timed' | 'guided'
  final bool completed;
  final DateTime completedAt;

  const MeditationSession({
    this.id,
    required this.userId,
    required this.durationSeconds,
    required this.type,
    required this.completed,
    required this.completedAt,
  });

  factory MeditationSession.fromMap(Map<String, dynamic> map) {
    return MeditationSession(
      id: map['id'] as int?,
      userId: map['user_id'] as String,
      durationSeconds: map['duration_seconds'] as int,
      type: map['type'] as String? ?? 'breathing',
      completed: (map['completed'] as int? ?? 0) == 1,
      completedAt: DateTime.parse(map['completed_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'duration_seconds': durationSeconds,
      'type': type,
      'completed': completed ? 1 : 0,
      'completed_at': completedAt.toIso8601String(),
    };
  }

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    if (m == 0) return '${s}s';
    if (s == 0) return '${m}m';
    return '${m}m ${s}s';
  }
}
*/