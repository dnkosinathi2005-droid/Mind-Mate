import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Lightweight wrapper around connectivity_plus that exposes a simple
/// boolean stream. Used by the offline banner widget.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<void> init() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = _check(results);

    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final online = _check(results);
      if (online != _isOnline) {
        _isOnline = online;
        if (!_controller.isClosed) _controller.add(_isOnline);
      }
    });
  }

  Stream<bool> get onlineStream => _controller.stream;

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }

  bool _check(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
  }
}
