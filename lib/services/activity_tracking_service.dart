import 'dart:async';
import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

class ActivityTrackingService {
  ActivityTrackingService._();
  static final ActivityTrackingService instance = ActivityTrackingService._();

  bool _isTracking = false;
  double _distanceMeters = 0;
  int _steps = 0;
  Position? _lastPosition;
  DateTime? _startTime;

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  // Step detection
  bool _stepPending = false;
  static const double _stepThreshold = 12.0;

  // Callbacks — plain function types, no Flutter import needed
  void Function(double)? onDistanceUpdate;
  void Function(int)?    onStepUpdate;
  void Function(String)? onError;

  bool   get isTracking      => _isTracking;
  double get distanceMeters  => _distanceMeters;
  int    get steps           => _steps;

  double get paceMinPerKm {
    if (_startTime == null || _distanceMeters < 10) return 0;
    final elapsedMinutes =
        DateTime.now().difference(_startTime!).inSeconds / 60.0;
    final km = _distanceMeters / 1000.0;
    return elapsedMinutes / km;
  }

  String get formattedDistance {
    if (_distanceMeters < 1000) {
      return '${_distanceMeters.toStringAsFixed(0)} m';
    }
    return '${(_distanceMeters / 1000).toStringAsFixed(2)} km';
  }

  String get formattedPace {
    final pace = paceMinPerKm;
    if (pace == 0) return "--'--\"";
    final min = pace.floor();
    final sec = ((pace - min) * 60).round();
    return "$min'${sec.toString().padLeft(2, '0')}\"/km";
  }

  // ── Permissions ───────────────────────────
  Future<bool> requestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      onError?.call(
          'Location services are disabled. Please enable GPS to track your activity.');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        onError?.call(
            'Location permission denied. Distance tracking will not be available.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      onError?.call(
          'Location permission permanently denied. Enable it in app settings.');
      return false;
    }

    return true;
  }

  // ── Start ──────────────────────────────────
  Future<void> start() async {
    if (_isTracking) return;
    _isTracking = true;
    _distanceMeters = 0;
    _steps = 0;
    _lastPosition = null;
    _startTime = DateTime.now();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    try {
      _positionSub = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _onPosition,
        onError: (e) => onError?.call('GPS error: $e'),
      );
    } catch (e) {
      onError?.call('Could not start GPS: $e');
    }

    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen(_onAccelerometer);
  }

  // ── Stop ───────────────────────────────────
  Future<void> stop() async {
    _isTracking = false;
    await _positionSub?.cancel();
    await _accelSub?.cancel();
    _positionSub = null;
    _accelSub = null;
  }

  void reset() {
    _distanceMeters = 0;
    _steps = 0;
    _lastPosition = null;
    _startTime = null;
  }

  // ── GPS handler ────────────────────────────
  void _onPosition(Position position) {
    if (_lastPosition != null) {
      final delta = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      if (delta > 2.0) {
        _distanceMeters += delta;
        onDistanceUpdate?.call(_distanceMeters);
      }
    }
    _lastPosition = position;
  }

  // ── Accelerometer step counter ─────────────
  void _onAccelerometer(AccelerometerEvent event) {
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    if (!_stepPending && magnitude > _stepThreshold) {
      _stepPending = true;
    } else if (_stepPending && magnitude < _stepThreshold - 2) {
      _steps++;
      _stepPending = false;
      onStepUpdate?.call(_steps);
    }
  }
}





/*import 'dart:async';
import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Tracks distance via GPS and steps via accelerometer.
/// Used by walking and running meditation modes.
class ActivityTrackingService {
  ActivityTrackingService._();
  static final ActivityTrackingService instance =
      ActivityTrackingService._();

  // ── State ─────────────────────────────────
  bool _isTracking = false;
  double _distanceMeters = 0;
  int _steps = 0;
  Position? _lastPosition;
  DateTime? _startTime;

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  // Step detection
  double _lastMagnitude = 0;
  bool _stepPending = false;
  static const double _stepThreshold = 12.0;

  // Callbacks for UI updates
  ValueChanged<double>? onDistanceUpdate;
  ValueChanged<int>? onStepUpdate;
  ValueChanged<String>? onError;

  // ── Getters ───────────────────────────────
  bool get isTracking => _isTracking;
  double get distanceMeters => _distanceMeters;
  int get steps => _steps;

  double get paceMinPerKm {
    if (_startTime == null || _distanceMeters < 10) return 0;
    final elapsedMinutes =
        DateTime.now().difference(_startTime!).inSeconds / 60.0;
    final km = _distanceMeters / 1000.0;
    return elapsedMinutes / km;
  }

  String get formattedDistance {
    if (_distanceMeters < 1000) {
      return '${_distanceMeters.toStringAsFixed(0)} m';
    }
    return '${(_distanceMeters / 1000).toStringAsFixed(2)} km';
  }

  String get formattedPace {
    final pace = paceMinPerKm;
    if (pace == 0) return "--'--\"";
    final min = pace.floor();
    final sec = ((pace - min) * 60).round();
    return "$min'${sec.toString().padLeft(2, '0')}\"/km";
  }

  // ── Permissions ───────────────────────────
  Future<bool> requestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      onError?.call('Location services are disabled. '
          'Please enable GPS to track your activity.');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        onError?.call('Location permission denied. '
            'Distance tracking will not be available.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      onError?.call('Location permission permanently denied. '
          'Enable it in app settings to track distance.');
      return false;
    }

    return true;
  }

  // ── Start tracking ─────────────────────────
  Future<void> start() async {
    if (_isTracking) return;

    _isTracking = true;
    _distanceMeters = 0;
    _steps = 0;
    _lastPosition = null;
    _startTime = DateTime.now();

    // GPS position stream — high accuracy, update every 3 seconds or 5 metres
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
      timeLimit: null,
    );

    try {
      _positionSub = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _onPosition,
        onError: (e) => onError?.call('GPS error: $e'),
      );
    } catch (e) {
      onError?.call('Could not start GPS: $e');
    }

    // Accelerometer for step counting
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen(_onAccelerometer);
  }

  // ── Stop tracking ─────────────────────────
  Future<void> stop() async {
    _isTracking = false;
    await _positionSub?.cancel();
    await _accelSub?.cancel();
    _positionSub = null;
    _accelSub = null;
  }

  void reset() {
    _distanceMeters = 0;
    _steps = 0;
    _lastPosition = null;
    _startTime = null;
  }

  // ── GPS handler ───────────────────────────
  void _onPosition(Position position) {
    if (_lastPosition != null) {
      final delta = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      // Filter out GPS noise — only add if moved more than 2 metres
      if (delta > 2.0) {
        _distanceMeters += delta;
        onDistanceUpdate?.call(_distanceMeters);
      }
    }
    _lastPosition = position;
  }

  // ── Accelerometer step counter ────────────
  void _onAccelerometer(AccelerometerEvent event) {
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    // Simple peak detection — step when magnitude crosses threshold
    if (!_stepPending && magnitude > _stepThreshold) {
      _stepPending = true;
    } else if (_stepPending && magnitude < _stepThreshold - 2) {
      _steps++;
      _stepPending = false;
      onStepUpdate?.call(_steps);
    }

    _lastMagnitude = magnitude;
  }
}*/
