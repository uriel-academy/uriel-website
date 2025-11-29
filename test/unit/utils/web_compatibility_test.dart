import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uriel_mainapp/utils/web_compatibility.dart';

void main() {
  group('safeTimestamp Tests', () {
    test('should handle null with current timestamp', () {
      final result = safeTimestamp(null);
      expect(result, isA<int>());
      expect(result, greaterThan(0));
    });

    test('should handle int values', () {
      expect(safeTimestamp(1609459200000), 1609459200000);
      expect(safeTimestamp(0), 0);
    });

    test('should convert double to int', () {
      expect(safeTimestamp(1609459200000.5), 1609459200000);
      expect(safeTimestamp(1234567890.99), 1234567890);
    });

    test('should parse string dates', () {
      final result = safeTimestamp('2021-01-01T00:00:00.000Z');
      expect(result, isA<int>());
      expect(result, greaterThan(1609459200000 - 1000)); // Allow 1s variance for timezone
    });

    test('should handle DateTime objects', () {
      final date = DateTime(2021, 1, 1);
      final result = safeTimestamp(date);
      expect(result, equals(date.millisecondsSinceEpoch));
    });

    test('should handle Timestamp objects', () {
      final timestamp = Timestamp.fromMillisecondsSinceEpoch(1609459200000);
      expect(safeTimestamp(timestamp), 1609459200000);
    });

    test('should fallback to current time for invalid input', () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final result = safeTimestamp('invalid');
      final after = DateTime.now().millisecondsSinceEpoch;
      
      expect(result, greaterThanOrEqualTo(before));
      expect(result, lessThanOrEqualTo(after + 1000)); // Allow 1s buffer
    });
  });

  group('safeDateTime Tests', () {
    test('should handle null with current DateTime', () {
      final result = safeDateTime(null);
      expect(result, isA<DateTime>());
      expect(result.year, DateTime.now().year);
    });

    test('should handle DateTime objects', () {
      final date = DateTime(2021, 6, 15, 10, 30);
      expect(safeDateTime(date), equals(date));
    });

    test('should convert Timestamp to DateTime', () {
      final timestamp = Timestamp.fromMillisecondsSinceEpoch(1609459200000);
      final result = safeDateTime(timestamp);
      expect(result.year, 2021);
      expect(result.month, 1);
    });

    test('should parse string dates', () {
      final result = safeDateTime('2021-06-15T10:30:00.000Z');
      expect(result.year, 2021);
      expect(result.month, 6);
      expect(result.day, 15);
    });

    test('should convert int milliseconds to DateTime', () {
      final result = safeDateTime(1609459200000);
      expect(result.year, 2021);
    });

    test('should convert double milliseconds to DateTime', () {
      final result = safeDateTime(1609459200000.0);
      expect(result.year, 2021);
    });

    test('should fallback to current time for invalid input', () {
      final result = safeDateTime('invalid date');
      expect(result, isA<DateTime>());
      expect(result.year, DateTime.now().year);
    });
  });

  group('safeInt Tests', () {
    test('should handle null with default value', () {
      expect(safeInt(null), 0);
      expect(safeInt(null, defaultValue: 42), 42);
    });

    test('should handle int values', () {
      expect(safeInt(42), 42);
      expect(safeInt(-10), -10);
      expect(safeInt(0), 0);
    });

    test('should convert double to int', () {
      expect(safeInt(42.7), 42);
      expect(safeInt(-10.9), -10);
      expect(safeInt(0.0), 0);
    });

    test('should parse string numbers', () {
      expect(safeInt('42'), 42);
      expect(safeInt('-10'), -10);
      expect(safeInt('0'), 0);
    });

    test('should handle invalid strings with default value', () {
      expect(safeInt('invalid'), 0);
      expect(safeInt('invalid', defaultValue: 99), 99);
      expect(safeInt('12.34'), 0); // Can't parse decimal string to int
    });
  });

  group('safeDouble Tests', () {
    test('should handle null with default value', () {
      expect(safeDouble(null), 0.0);
      expect(safeDouble(null, defaultValue: 42.5), 42.5);
    });

    test('should handle double values', () {
      expect(safeDouble(42.7), 42.7);
      expect(safeDouble(-10.9), -10.9);
      expect(safeDouble(0.0), 0.0);
    });

    test('should convert int to double', () {
      expect(safeDouble(42), 42.0);
      expect(safeDouble(-10), -10.0);
      expect(safeDouble(0), 0.0);
    });

    test('should parse string numbers', () {
      expect(safeDouble('42.7'), 42.7);
      expect(safeDouble('-10.9'), -10.9);
      expect(safeDouble('0'), 0.0);
    });

    test('should handle invalid strings with default value', () {
      expect(safeDouble('invalid'), 0.0);
      expect(safeDouble('invalid', defaultValue: 99.5), 99.5);
    });
  });

  group('safeDocumentData Tests', () {
    test('should handle empty map', () {
      expect(safeDocumentData({}), equals({}));
    });

    test('should preserve simple values', () {
      final input = {
        'name': 'John',
        'age': 30,
        'score': 95.5,
        'active': true,
      };
      final result = safeDocumentData(input);
      expect(result['name'], 'John');
      expect(result['age'], 30);
      expect(result['score'], 95.5);
      expect(result['active'], true);
    });

    test('should handle nested maps', () {
      final input = {
        'user': {
          'name': 'John',
          'age': 30,
        },
      };
      final result = safeDocumentData(input);
      expect(result['user'], isA<Map>());
      expect((result['user'] as Map)['name'], 'John');
      expect((result['user'] as Map)['age'], 30);
    });

    test('should handle lists', () {
      final input = {
        'scores': [90, 85, 95],
      };
      final result = safeDocumentData(input);
      expect(result['scores'], isA<List>());
      expect((result['scores'] as List).length, 3);
      expect((result['scores'] as List)[0], 90);
    });

    test('should convert Timestamp in nested data', () {
      final timestamp = Timestamp.fromMillisecondsSinceEpoch(1609459200000);
      final input = {
        'createdAt': timestamp,
      };
      final result = safeDocumentData(input);
      // Timestamp gets converted to ISO8601 string
      expect(result['createdAt'], isA<String>());
      expect(result['createdAt'], contains('2021'));
    });
  });
}
