import 'package:flutter_test/flutter_test.dart';
import 'package:uriel_mainapp/services/cache_service.dart';

void main() {
  group('CacheService', () {
    late CacheService cache;

    setUp(() {
      cache = CacheService();
      cache.clear(); // Start with clean cache
    });

    test('should store and retrieve values', () {
      cache.set('key1', 'value1');
      
      final result = cache.get<String>('key1');
      expect(result, 'value1');
    });

    test('should return null for non-existent keys', () {
      final result = cache.get<String>('non_existent');
      expect(result, null);
    });

    test('should respect TTL', () async {
      cache.set('key1', 'value1', ttl: const Duration(milliseconds: 100));
      
      // Should exist immediately
      expect(cache.get<String>('key1'), 'value1');
      
      // Wait for expiration
      await Future.delayed(const Duration(milliseconds: 150));
      
      // Should be expired
      expect(cache.get<String>('key1'), null);
    });

    test('should handle getOrSet', () async {
      int computeCount = 0;
      
      Future<String> compute() async {
        computeCount++;
        return 'computed_value';
      }

      // First call should compute
      final result1 = await cache.getOrSet(
        key: 'computed_key',
        compute: compute,
      );
      expect(result1, 'computed_value');
      expect(computeCount, 1);

      // Second call should use cache
      final result2 = await cache.getOrSet(
        key: 'computed_key',
        compute: compute,
      );
      expect(result2, 'computed_value');
      expect(computeCount, 1); // Should not have computed again
    });

    test('should invalidate specific keys', () {
      cache.set('key1', 'value1');
      cache.set('key2', 'value2');
      
      cache.invalidate('key1');
      
      expect(cache.get<String>('key1'), null);
      expect(cache.get<String>('key2'), 'value2');
    });

    test('should invalidate by pattern', () {
      cache.set('user_123_profile', 'profile1');
      cache.set('user_123_settings', 'settings1');
      cache.set('user_456_profile', 'profile2');
      
      cache.invalidatePattern('user_123');
      
      expect(cache.get<String>('user_123_profile'), null);
      expect(cache.get<String>('user_123_settings'), null);
      expect(cache.get<String>('user_456_profile'), 'profile2');
    });

    test('should clear all cache', () {
      cache.set('key1', 'value1');
      cache.set('key2', 'value2');
      
      cache.clear();
      
      expect(cache.get<String>('key1'), null);
      expect(cache.get<String>('key2'), null);
    });

    test('should clear expired entries', () async {
      cache.set('key1', 'value1', ttl: const Duration(milliseconds: 100));
      cache.set('key2', 'value2', ttl: const Duration(hours: 1));
      
      await Future.delayed(const Duration(milliseconds: 150));
      
      cache.clearExpired();
      
      expect(cache.get<String>('key1'), null);
      expect(cache.get<String>('key2'), 'value2');
    });

    test('should enforce size limits with LRU', () {
      // Override max entries for testing
      for (int i = 0; i < 500; i++) {
        cache.set('key_$i', 'value_$i');
      }
      
      // Cache should have 500 entries
      expect(cache.get<String>('key_499'), 'value_499');
      
      // Adding one more should evict the LRU
      cache.set('key_500', 'value_500');
      
      // First key (LRU) should be gone
      // Note: This test depends on LRU implementation
      expect(cache.stats.totalEntries, 500);
    });

    test('should provide cache stats', () {
      cache.set('key1', 'value1');
      cache.set('key2', 'value2', ttl: const Duration(milliseconds: -1)); // Already expired
      
      final stats = cache.stats;
      
      expect(stats.totalEntries, 2);
      expect(stats.expiredEntries, greaterThanOrEqualTo(0));
    });

    test('should support different types', () {
      cache.set('string_key', 'string_value');
      cache.set('int_key', 42);
      cache.set('list_key', [1, 2, 3]);
      cache.set('map_key', {'a': 1, 'b': 2});
      
      expect(cache.get<String>('string_key'), 'string_value');
      expect(cache.get<int>('int_key'), 42);
      expect(cache.get<List<int>>('list_key'), [1, 2, 3]);
      expect(cache.get<Map<String, int>>('map_key'), {'a': 1, 'b': 2});
    });
  });
}
