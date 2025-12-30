import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Service to track performance bottlenecks and user behavior analytics
class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final Map<String, DateTime> _timers = {};
  final Map<String, int> _counters = {};

  /// Track screen views for navigation analytics
  Future<void> trackScreen(String screenName) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenName,
      );
      debugPrint('[Analytics] Screen view: $screenName');
    } catch (e) {
      debugPrint('[Analytics] Error tracking screen: $e');
    }
  }

  /// Start a timer for performance measurement
  void startTimer(String timerName) {
    _timers[timerName] = DateTime.now();
    debugPrint('[Performance] Timer started: $timerName');
  }

  /// End a timer and log the duration
  Future<void> endTimer(String timerName, {Map<String, dynamic>? metadata}) async {
    if (!_timers.containsKey(timerName)) {
      debugPrint('[Performance] Timer $timerName not found');
      return;
    }

    final startTime = _timers[timerName]!;
    final duration = DateTime.now().difference(startTime);
    _timers.remove(timerName);

    try {
      // Log custom event with timing data
      await _analytics.logEvent(
        name: 'performance_timing',
        parameters: {
          'timer_name': timerName,
          'duration_ms': duration.inMilliseconds,
          'duration_seconds': duration.inSeconds,
          ...?metadata,
        },
      );

      debugPrint('[Performance] $timerName completed in ${duration.inMilliseconds}ms');

      // Alert if operation is slow (>3 seconds)
      if (duration.inSeconds > 3) {
        debugPrint('[Performance WARNING] Slow operation: $timerName took ${duration.inSeconds}s');
        await trackBottleneck(timerName, duration.inMilliseconds);
      }
    } catch (e) {
      debugPrint('[Performance] Error logging timer: $e');
    }
  }

  /// Track a bottleneck for investigation
  Future<void> trackBottleneck(String operationName, int durationMs) async {
    try {
      await _analytics.logEvent(
        name: 'bottleneck_detected',
        parameters: {
          'operation': operationName,
          'duration_ms': durationMs,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('[Performance] Error tracking bottleneck: $e');
    }
  }

  /// Track user actions for behavior analysis
  Future<void> trackAction(String actionName, {Map<String, dynamic>? parameters}) async {
    try {
      await _analytics.logEvent(
        name: actionName,
        parameters: parameters?.cast<String, Object>(),
      );
      debugPrint('[Analytics] Action: $actionName');
    } catch (e) {
      debugPrint('[Analytics] Error tracking action: $e');
    }
  }

  /// Track errors and exceptions
  Future<void> trackError(String errorType, String errorMessage, {StackTrace? stackTrace}) async {
    try {
      await _analytics.logEvent(
        name: 'app_error',
        parameters: {
          'error_type': errorType,
          'error_message': errorMessage.length > 100 
              ? errorMessage.substring(0, 100) 
              : errorMessage,
          'has_stack_trace': stackTrace != null,
        },
      );
      debugPrint('[Analytics] Error tracked: $errorType - $errorMessage');
    } catch (e) {
      debugPrint('[Analytics] Error tracking error: $e');
    }
  }

  /// Increment a counter for frequency tracking
  void incrementCounter(String counterName) {
    _counters[counterName] = (_counters[counterName] ?? 0) + 1;
    
    // Log to analytics every 10 increments to avoid spam
    if (_counters[counterName]! % 10 == 0) {
      _analytics.logEvent(
        name: 'counter_milestone',
        parameters: {
          'counter_name': counterName,
          'count': _counters[counterName]!,
        },
      );
    }
  }

  /// Track Firestore query performance
  Future<void> trackFirestoreQuery(String collectionName, int documentCount, int durationMs) async {
    try {
      await _analytics.logEvent(
        name: 'firestore_query',
        parameters: {
          'collection': collectionName,
          'document_count': documentCount,
          'duration_ms': durationMs,
          'is_slow': durationMs > 1000,
        },
      );

      if (durationMs > 2000) {
        debugPrint('[Firestore WARNING] Slow query on $collectionName: ${durationMs}ms for $documentCount docs');
      }
    } catch (e) {
      debugPrint('[Performance] Error tracking Firestore query: $e');
    }
  }

  /// Track memory usage spikes
  Future<void> trackMemoryWarning(String context, String severity) async {
    try {
      await _analytics.logEvent(
        name: 'memory_warning',
        parameters: {
          'context': context,
          'severity': severity,
        },
      );
    } catch (e) {
      debugPrint('[Performance] Error tracking memory: $e');
    }
  }

  /// Track network request performance
  Future<void> trackNetworkRequest(String endpoint, int statusCode, int durationMs) async {
    try {
      await _analytics.logEvent(
        name: 'network_request',
        parameters: {
          'endpoint': endpoint,
          'status_code': statusCode,
          'duration_ms': durationMs,
          'is_slow': durationMs > 3000,
          'is_error': statusCode >= 400,
        },
      );

      if (durationMs > 5000) {
        debugPrint('[Network WARNING] Slow request to $endpoint: ${durationMs}ms');
      }
    } catch (e) {
      debugPrint('[Performance] Error tracking network request: $e');
    }
  }

  /// Track app startup time
  Future<void> trackAppStartup(int durationMs) async {
    try {
      await _analytics.logEvent(
        name: 'app_startup',
        parameters: {
          'duration_ms': durationMs,
          'is_slow': durationMs > 3000,
        },
      );
      debugPrint('[Performance] App startup: ${durationMs}ms');
    } catch (e) {
      debugPrint('[Performance] Error tracking startup: $e');
    }
  }

  /// Get current counter value
  int getCounter(String counterName) {
    return _counters[counterName] ?? 0;
  }

  /// Reset a counter
  void resetCounter(String counterName) {
    _counters.remove(counterName);
  }

  /// Clear all timers and counters
  void clearAll() {
    _timers.clear();
    _counters.clear();
    debugPrint('[Performance] All timers and counters cleared');
  }
}
