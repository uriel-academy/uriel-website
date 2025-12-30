import 'package:flutter/material.dart';
import '../services/performance_service.dart';

/// Wrapper widget that tracks screen view analytics and performance
class TrackedRoute extends StatefulWidget {
  final Widget child;
  final String screenName;

  const TrackedRoute({
    Key? key,
    required this.child,
    required this.screenName,
  }) : super(key: key);

  @override
  State<TrackedRoute> createState() => _TrackedRouteState();
}

class _TrackedRouteState extends State<TrackedRoute> {
  final PerformanceService _performance = PerformanceService();
  late final DateTime _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    
    // Track screen view
    _performance.trackScreen(widget.screenName);
    
    // Start timer for screen load time
    _performance.startTimer('screen_load_${widget.screenName}');
  }

  @override
  void dispose() {
    // Track how long user spent on this screen
    final duration = DateTime.now().difference(_startTime);
    _performance.trackAction('screen_duration', parameters: {
      'screen_name': widget.screenName,
      'duration_seconds': duration.inSeconds,
    });
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // End the screen load timer after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performance.endTimer('screen_load_${widget.screenName}');
    });

    return widget.child;
  }
}

/// Extension to easily wrap routes with tracking
extension TrackedRouteExtension on Widget {
  Widget tracked(String screenName) {
    return TrackedRoute(
      screenName: screenName,
      child: this,
    );
  }
}
