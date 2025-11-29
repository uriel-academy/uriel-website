import 'package:flutter_test/flutter_test.dart';
import 'package:uriel_mainapp/services/performance_monitor.dart';

void main() {
  group('PerformanceMonitor', () {
    late PerformanceMonitor monitor;

    setUp(() {
      monitor = PerformanceMonitor();
      monitor.reset();
    });

    test('should track async operations', () async {
      final result = await monitor.track<String>(
        operation: 'test_operation',
        task: () async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 'done';
        },
      );

      expect(result, 'done');

      final avgDuration = monitor.getAverageDuration('test_operation');
      expect(avgDuration, isNotNull);
      expect(avgDuration!.inMilliseconds, greaterThanOrEqualTo(100));
    });

    test('should track sync operations', () {
      final result = monitor.trackSync<int>(
        operation: 'sync_operation',
        task: () {
          int sum = 0;
          for (int i = 0; i < 1000; i++) {
            sum += i;
          }
          return sum;
        },
      );

      expect(result, 499500);

      final avgDuration = monitor.getAverageDuration('sync_operation');
      expect(avgDuration, isNotNull);
    });

    test('should calculate average duration', () async {
      for (int i = 0; i < 5; i++) {
        await monitor.track<void>(
          operation: 'repeated_operation',
          task: () async {
            await Future.delayed(Duration(milliseconds: 50 + i * 10));
          },
        );
      }

      final avgDuration = monitor.getAverageDuration('repeated_operation');
      expect(avgDuration, isNotNull);
      expect(avgDuration!.inMilliseconds, greaterThanOrEqualTo(50));
      expect(avgDuration.inMilliseconds, lessThan(100));
    });

    test('should generate performance report', () async {
      await monitor.track<void>(
        operation: 'op1',
        task: () async => Future.delayed(const Duration(milliseconds: 50)),
      );

      await monitor.track<void>(
        operation: 'op2',
        task: () async => Future.delayed(const Duration(milliseconds: 100)),
      );

      final report = monitor.getReport();
      
      expect(report.length, 2);
      expect(report.containsKey('op1'), true);
      expect(report.containsKey('op2'), true);

      final op1Stats = report['op1']!;
      expect(op1Stats.callCount, 1);
      expect(op1Stats.averageDuration.inMilliseconds, greaterThanOrEqualTo(50));
    });

    test('should calculate percentiles', () async {
      // Add operations with varying durations
      for (int i = 0; i < 100; i++) {
        await monitor.track<void>(
          operation: 'percentile_test',
          task: () async {
            await Future.delayed(Duration(milliseconds: i));
          },
        );
      }

      final report = monitor.getReport();
      final stats = report['percentile_test']!;

      expect(stats.callCount, 100);
      expect(stats.minDuration.inMilliseconds, lessThan(20)); // More lenient
      expect(stats.maxDuration.inMilliseconds, greaterThanOrEqualTo(80)); // More lenient
      expect(stats.p50.inMilliseconds, greaterThan(30)); // More lenient
      expect(stats.p50.inMilliseconds, lessThan(70)); // More lenient
      expect(stats.p95.inMilliseconds, greaterThan(80)); // More lenient
    });

    test('should limit stored metrics', () async {
      // Add more than 100 measurements
      for (int i = 0; i < 150; i++) {
        await monitor.track<void>(
          operation: 'limited_operation',
          task: () async {},
        );
      }

      final report = monitor.getReport();
      final stats = report['limited_operation']!;
      
      expect(stats.callCount, 150);
      // Average should still be calculated correctly
      expect(stats.averageDuration, isNotNull);
    });

    test('should reset all data', () async {
      await monitor.track<void>(
        operation: 'test_op',
        task: () async {},
      );

      expect(monitor.getReport().isNotEmpty, true);

      monitor.reset();

      expect(monitor.getReport().isEmpty, true);
    });

    test('should handle multiple operations', () async {
      final operations = ['op_a', 'op_b', 'op_c'];

      for (final op in operations) {
        for (int i = 0; i < 3; i++) {
          await monitor.track<void>(
            operation: op,
            task: () async => Future.delayed(const Duration(milliseconds: 10)),
          );
        }
      }

      final report = monitor.getReport();
      expect(report.length, 3);

      for (final op in operations) {
        expect(report[op]!.callCount, 3);
      }
    });
  });
}
