import 'dart:async';
import 'package:flutter/foundation.dart';

/// Production-ready cache with TTL, size limits, and LRU eviction
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, CacheEntry> _cache = {};
  final Map<String, DateTime> _accessTimes = {};
  
  static const int maxEntries = 500;
  static const Duration defaultTTL = Duration(minutes: 5);

  /// Get cached value
  T? get<T>(String key) {
    final entry = _cache[key];
    
    if (entry == null) return null;
    
    // Check if expired
    if (entry.expiresAt.isBefore(DateTime.now())) {
      _cache.remove(key);
      _accessTimes.remove(key);
      return null;
    }
    
    // Update access time for LRU
    _accessTimes[key] = DateTime.now();
    
    return entry.value as T?;
  }

  /// Set cached value
  void set<T>(
    String key,
    T value, {
    Duration? ttl,
  }) {
    // Enforce size limit with LRU eviction
    if (_cache.length >= maxEntries && !_cache.containsKey(key)) {
      _evictLRU();
    }
    
    final expiresAt = DateTime.now().add(ttl ?? defaultTTL);
    _cache[key] = CacheEntry(value: value, expiresAt: expiresAt);
    _accessTimes[key] = DateTime.now();
  }

  /// Get or compute value
  Future<T> getOrSet<T>({
    required String key,
    required Future<T> Function() compute,
    Duration? ttl,
  }) async {
    final cached = get<T>(key);
    if (cached != null) return cached;
    
    final value = await compute();
    set(key, value, ttl: ttl);
    return value;
  }

  /// Invalidate specific key
  void invalidate(String key) {
    _cache.remove(key);
    _accessTimes.remove(key);
  }

  /// Invalidate keys matching pattern
  void invalidatePattern(Pattern pattern) {
    final keysToRemove = _cache.keys
        .where((key) => key.contains(pattern))
        .toList();
    
    for (final key in keysToRemove) {
      _cache.remove(key);
      _accessTimes.remove(key);
    }
  }

  /// Clear all cache
  void clear() {
    _cache.clear();
    _accessTimes.clear();
  }

  /// Clear expired entries
  void clearExpired() {
    final now = DateTime.now();
    final expiredKeys = _cache.entries
        .where((entry) => entry.value.expiresAt.isBefore(now))
        .map((entry) => entry.key)
        .toList();
    
    for (final key in expiredKeys) {
      _cache.remove(key);
      _accessTimes.remove(key);
    }
  }

  void _evictLRU() {
    if (_accessTimes.isEmpty) return;
    
    // Find least recently used
    final lruKey = _accessTimes.entries
        .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
        .key;
    
    _cache.remove(lruKey);
    _accessTimes.remove(lruKey);
    
    if (kDebugMode) {
      debugPrint('🗑️ Cache evicted LRU: $lruKey');
    }
  }

  /// Get cache stats
  CacheStats get stats {
    final now = DateTime.now();
    final expired = _cache.values
        .where((entry) => entry.expiresAt.isBefore(now))
        .length;
    
    return CacheStats(
      totalEntries: _cache.length,
      expiredEntries: expired,
      maxEntries: maxEntries,
      hitRate: _hitCount / (_hitCount + _missCount),
    );
  }

  int _hitCount = 0;
  int _missCount = 0;

  /// Start periodic cleanup
  Timer? _cleanupTimer;
  
  void startPeriodicCleanup({Duration interval = const Duration(minutes: 5)}) {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(interval, (_) => clearExpired());
  }

  void stopPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }
}

class CacheEntry {
  final dynamic value;
  final DateTime expiresAt;

  CacheEntry({
    required this.value,
    required this.expiresAt,
  });
}

class CacheStats {
  final int totalEntries;
  final int expiredEntries;
  final int maxEntries;
  final double hitRate;

  CacheStats({
    required this.totalEntries,
    required this.expiredEntries,
    required this.maxEntries,
    required this.hitRate,
  });

  @override
  String toString() {
    return 'CacheStats(entries: $totalEntries/$maxEntries, '
        'expired: $expiredEntries, hitRate: ${(hitRate * 100).toStringAsFixed(1)}%)';
  }
}
