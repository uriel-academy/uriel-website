import 'dart:async';
import 'package:flutter/foundation.dart';

/// Performance monitoring for production optimization
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final Map<String, List<Duration>> _metrics = {};
  final Map<String, int> _callCounts = {};
  
  /// Track operation performance
  Future<T> track<T>({
    required String operation,
    required Future<T> Function() task,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await task();
      return result;
    } finally {
      stopwatch.stop();
      _recordMetric(operation, stopwatch.elapsed);
    }
  }

  /// Track synchronous operation
  T trackSync<T>({
    required String operation,
    required T Function() task,
  }) {
    final stopwatch = Stopwatch()..start();
    
    try {
      return task();
    } finally {
      stopwatch.stop();
      _recordMetric(operation, stopwatch.elapsed);
    }
  }

  void _recordMetric(String operation, Duration duration) {
    _metrics.putIfAbsent(operation, () => []);
    _metrics[operation]!.add(duration);
    
    // Keep only last 100 measurements
    if (_metrics[operation]!.length > 100) {
      _metrics[operation]!.removeAt(0);
    }
    
    _callCounts[operation] = (_callCounts[operation] ?? 0) + 1;
    
    // Log slow operations in debug mode
    if (kDebugMode && duration.inMilliseconds > 1000) {
      debugPrint('🐌 Slow operation: $operation took ${duration.inMilliseconds}ms');
    }
  }

  /// Get average duration for an operation
  Duration? getAverageDuration(String operation) {
    final durations = _metrics[operation];
    if (durations == null || durations.isEmpty) return null;
    
    final totalMs = durations.fold<int>(
      0,
      (sum, d) => sum + d.inMilliseconds,
    );
    return Duration(milliseconds: totalMs ~/ durations.length);
  }

  /// Get performance report
  Map<String, OperationStats> getReport() {
    final report = <String, OperationStats>{};
    
    for (final entry in _metrics.entries) {
      final operation = entry.key;
      final durations = entry.value;
      
      if (durations.isEmpty) continue;
      
      final sortedDurations = List<Duration>.from(durations)
        ..sort((a, b) => a.compareTo(b));
      
      report[operation] = OperationStats(
        operation: operation,
        callCount: _callCounts[operation] ?? 0,
        averageDuration: getAverageDuration(operation)!,
        minDuration: sortedDurations.first,
        maxDuration: sortedDurations.last,
        p50: sortedDurations[sortedDurations.length ~/ 2],
        p95: sortedDurations[(sortedDurations.length * 0.95).toInt()],
      );
    }
    
    return report;
  }

  /// Print performance report
  void printReport() {
    final report = getReport();
    if (report.isEmpty) {
      debugPrint('📊 No performance data collected');
      return;
    }
    
    debugPrint('📊 PERFORMANCE REPORT');
    debugPrint('=' * 80);
    
    final sorted = report.entries.toList()
      ..sort((a, b) => b.value.averageDuration.compareTo(a.value.averageDuration));
    
    for (final entry in sorted) {
      final stats = entry.value;
      debugPrint('${stats.operation}:');
      debugPrint('  Calls: ${stats.callCount}');
      debugPrint('  Avg: ${stats.averageDuration.inMilliseconds}ms');
      debugPrint('  Min: ${stats.minDuration.inMilliseconds}ms');
      debugPrint('  Max: ${stats.maxDuration.inMilliseconds}ms');
      debugPrint('  P50: ${stats.p50.inMilliseconds}ms');
      debugPrint('  P95: ${stats.p95.inMilliseconds}ms');
      debugPrint('');
    }
  }

  void reset() {
    _metrics.clear();
    _callCounts.clear();
  }
}

class OperationStats {
  final String operation;
  final int callCount;
  final Duration averageDuration;
  final Duration minDuration;
  final Duration maxDuration;
  final Duration p50;
  final Duration p95;

  OperationStats({
    required this.operation,
    required this.callCount,
    required this.averageDuration,
    required this.minDuration,
    required this.maxDuration,
    required this.p50,
    required this.p95,
  });
}
