import 'dart:async';
import 'package:flutter/foundation.dart';

/// Production-ready error handler with logging, retry logic, and circuit breaker
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  final _errorLog = <ErrorRecord>[];
  final _circuitBreakers = <String, CircuitBreaker>{};
  
  /// Handle errors with proper logging and user feedback
  Future<T?> handle<T>({
    required Future<T> Function() operation,
    required String context,
    T? fallback,
    bool silent = false,
    int maxRetries = 2,
  }) async {
    final breaker = _getCircuitBreaker(context);
    
    if (!breaker.canAttempt()) {
      debugPrint('⚠️ Circuit breaker open for $context');
      return fallback;
    }

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final result = await operation();
        breaker.recordSuccess();
        return result;
      } catch (e, stackTrace) {
        final isLastAttempt = attempt == maxRetries;
        
        _logError(ErrorRecord(
          error: e,
          stackTrace: stackTrace,
          context: context,
          timestamp: DateTime.now(),
          attempt: attempt + 1,
        ));

        if (isLastAttempt) {
          breaker.recordFailure();
          if (!silent) {
            debugPrint('❌ Error in $context (attempt ${attempt + 1}/$maxRetries): $e');
          }
          return fallback;
        }
        
        // Exponential backoff
        await Future.delayed(Duration(milliseconds: 100 * (1 << attempt)));
      }
    }
    
    return fallback;
  }

  /// Timeout wrapper with proper error handling
  Future<T?> withTimeout<T>({
    required Future<T> Function() operation,
    required Duration timeout,
    required String context,
    T? fallback,
  }) async {
    try {
      return await operation().timeout(
        timeout,
        onTimeout: () {
          debugPrint('⏱️ Timeout in $context after ${timeout.inSeconds}s');
          throw TimeoutException('Operation timed out', timeout);
        },
      );
    } catch (e) {
      return handle(
        operation: () async => throw e,
        context: context,
        fallback: fallback,
        silent: true,
      );
    }
  }

  CircuitBreaker _getCircuitBreaker(String context) {
    return _circuitBreakers.putIfAbsent(
      context,
      () => CircuitBreaker(context: context),
    );
  }

  void _logError(ErrorRecord record) {
    _errorLog.add(record);
    if (_errorLog.length > 100) {
      _errorLog.removeAt(0);
    }
  }

  List<ErrorRecord> get recentErrors => List.unmodifiable(_errorLog);
}

/// Circuit breaker pattern for failing services
class CircuitBreaker {
  final String context;
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  bool _isOpen = false;
  
  static const int failureThreshold = 5;
  static const Duration resetTimeout = Duration(minutes: 1);

  CircuitBreaker({required this.context});

  bool canAttempt() {
    if (!_isOpen) return true;
    
    if (_lastFailureTime != null &&
        DateTime.now().difference(_lastFailureTime!) > resetTimeout) {
      _reset();
      return true;
    }
    
    return false;
  }

  void recordSuccess() {
    _failureCount = 0;
    _isOpen = false;
  }

  void recordFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();
    
    if (_failureCount >= failureThreshold) {
      _isOpen = true;
      debugPrint('🔴 Circuit breaker opened for $context');
    }
  }

  void _reset() {
    _failureCount = 0;
    _isOpen = false;
    debugPrint('🟢 Circuit breaker reset for $context');
  }
}

class ErrorRecord {
  final dynamic error;
  final StackTrace stackTrace;
  final String context;
  final DateTime timestamp;
  final int attempt;

  ErrorRecord({
    required this.error,
    required this.stackTrace,
    required this.context,
    required this.timestamp,
    required this.attempt,
  });
}
