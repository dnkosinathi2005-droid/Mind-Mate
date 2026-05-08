import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/connectivity_service.dart';

/// Wraps any screen with an animated offline notice at the top.
/// Drops in transparently — just wrap your Scaffold body with it.
///
/// Usage:
/// ```dart
/// body: OfflineBanner(child: YourWidget()),
/// ```
class OfflineBanner extends StatefulWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _heightAnim;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heightAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _isOnline = ConnectivityService.instance.isOnline;
    if (!_isOnline) _controller.value = 1.0;

    ConnectivityService.instance.onlineStream.listen((online) {
      if (!mounted) return;
      setState(() => _isOnline = online);
      if (online) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Offline banner — animates in/out
        SizeTransition(
          sizeFactor: _heightAnim,
          child: Container(
            width: double.infinity,
            color: AppColors.warning,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.wifi_off_rounded,
                    size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You are offline. Data is saved locally and will sync when you reconnect.',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}

/// A small sync status indicator — place in AppBar actions or
/// at the bottom of a screen to show real-time sync progress.
class SyncIndicator extends StatelessWidget {
  final bool isSyncing;
  final bool hasError;
  final int pendingCount;

  const SyncIndicator({
    super.key,
    this.isSyncing = false,
    this.hasError = false,
    this.pendingCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (isSyncing) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (hasError) {
      return const Icon(Icons.sync_problem_outlined,
          size: 20, color: AppColors.error);
    }

    if (pendingCount > 0) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          const Icon(Icons.cloud_upload_outlined,
              size: 20, color: AppColors.textSecondary),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.warning,
              shape: BoxShape.circle,
            ),
          ),
        ],
      );
    }

    return const Icon(Icons.cloud_done_outlined,
        size: 20, color: AppColors.success);
  }
}
