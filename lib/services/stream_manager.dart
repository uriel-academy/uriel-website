import 'dart:async';
import 'package:flutter/widgets.dart';

/// Manages all stream subscriptions to prevent memory leaks
class StreamManager {
  final List<StreamSubscription> _subscriptions = [];
  bool _disposed = false;

  /// Add a subscription to be managed
  void add(StreamSubscription subscription) {
    if (_disposed) {
      // Don't await - just fire and forget for disposed manager
      subscription.cancel().catchError((e) {
        debugPrint('Error cancelling disposed subscription: $e');
      });
      debugPrint('⚠️ Attempted to add subscription to disposed StreamManager');
      return;
    }
    _subscriptions.add(subscription);
  }

  /// Add multiple subscriptions
  void addAll(List<StreamSubscription> subscriptions) {
    for (final sub in subscriptions) {
      add(sub);
    }
  }

  /// Cancel a specific subscription
  Future<void> cancel(StreamSubscription subscription) async {
    await subscription.cancel();
    _subscriptions.remove(subscription);
  }

  /// Cancel all subscriptions
  Future<void> cancelAll() async {
    if (_disposed) return;
    
    final futures = _subscriptions.map((sub) => sub.cancel()).toList();
    await Future.wait(futures, eagerError: false);
    _subscriptions.clear();
  }

  /// Dispose and prevent further additions
  Future<void> dispose() async {
    if (_disposed) return;
    
    _disposed = true;
    await cancelAll();
  }

  int get activeCount => _subscriptions.length;
  bool get isDisposed => _disposed;
}

/// Mixin to automatically manage streams in StatefulWidgets
mixin StreamManagerMixin<T extends StatefulWidget> on State<T> {
  final StreamManager _streamManager = StreamManager();

  /// Add a subscription to auto-cancel on dispose
  void addSubscription(StreamSubscription subscription) {
    _streamManager.add(subscription);
  }

  /// Add multiple subscriptions
  void addSubscriptions(List<StreamSubscription> subscriptions) {
    _streamManager.addAll(subscriptions);
  }

  /// Override dispose in your widget to call this
  Future<void> disposeStreams() async {
    await _streamManager.dispose();
  }

  /// Access to stream manager for manual control if needed
  StreamManager get streamManager => _streamManager;
}
