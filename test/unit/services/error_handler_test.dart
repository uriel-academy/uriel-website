import 'package:flutter_test/flutter_test.dart';
import 'package:uriel_mainapp/services/error_handler.dart';

void main() {
  group('ErrorHandler', () {
    late ErrorHandler errorHandler;

    setUp(() {
      errorHandler = ErrorHandler();
    });

    test('should handle successful operation', () async {
      final result = await errorHandler.handle<String>(
        operation: () async => 'success',
        context: 'test_operation',
      );

      expect(result, 'success');
    });

    test('should return fallback on error', () async {
      final result = await errorHandler.handle<String>(
        operation: () async => throw Exception('Test error'),
        context: 'test_operation',
        fallback: 'fallback_value',
        silent: true,
      );

      expect(result, 'fallback_value');
    });

    test('should retry on failure', () async {
      int attemptCount = 0;

      final result = await errorHandler.handle<int>(
        operation: () async {
          attemptCount++;
          if (attemptCount < 2) {
            throw Exception('Temporary failure');
          }
          return 42;
        },
        context: 'retry_test',
        maxRetries: 2,
      );

      expect(result, 42);
      expect(attemptCount, 2);
    });

    test('should handle timeout', () async {
      final result = await errorHandler.withTimeout<String>(
        operation: () async {
          await Future.delayed(const Duration(seconds: 2));
          return 'too_slow';
        },
        timeout: const Duration(milliseconds: 100),
        context: 'timeout_test',
        fallback: 'timeout_fallback',
      );

      expect(result, 'timeout_fallback');
    });

    test('circuit breaker should open after failures', () async {
      // Trigger multiple failures
      for (int i = 0; i < 6; i++) {
        await errorHandler.handle<void>(
          operation: () async => throw Exception('Failure $i'),
          context: 'circuit_breaker_test',
          silent: true,
        );
      }

      // Circuit should be open now, operation shouldn't execute
      bool operationExecuted = false;
      await errorHandler.handle<void>(
        operation: () async {
          operationExecuted = true;
        },
        context: 'circuit_breaker_test',
        silent: true,
      );

      expect(operationExecuted, false);
    });
  });

  group('CircuitBreaker', () {
    late CircuitBreaker breaker;

    setUp(() {
      breaker = CircuitBreaker(context: 'test_breaker');
    });

    test('should allow attempts when closed', () {
      expect(breaker.canAttempt(), true);
    });

    test('should open after threshold failures', () {
      expect(breaker.canAttempt(), true);

      // Record 5 failures (threshold)
      for (int i = 0; i < 5; i++) {
        breaker.recordFailure();
      }

      expect(breaker.canAttempt(), false);
    });

    test('should reset after success', () {
      breaker.recordFailure();
      breaker.recordFailure();
      breaker.recordSuccess();

      expect(breaker.canAttempt(), true);
    });
  });
}
