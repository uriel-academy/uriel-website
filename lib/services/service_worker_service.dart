import 'package:flutter/foundation.dart';

/// Service to register and manage the PWA service worker
class ServiceWorkerService {
  static final ServiceWorkerService _instance = ServiceWorkerService._internal();
  factory ServiceWorkerService() => _instance;
  ServiceWorkerService._internal();

  bool _isRegistered = false;

  /// Register the service worker for PWA functionality
  Future<void> registerServiceWorker() async {
    if (!kIsWeb) {
      debugPrint('[SW] Service worker not supported on non-web platforms');
      return;
    }

    try {
      // The service worker registration is handled by the browser
      // This method is just for tracking
      _isRegistered = true;
      debugPrint('[SW] Service worker registration initiated');
    } catch (e) {
      debugPrint('[SW] Error registering service worker: $e');
    }
  }

  /// Clear all service worker caches
  Future<void> clearCache() async {
    if (!kIsWeb || !_isRegistered) return;

    try {
      debugPrint('[SW] Requesting cache clear...');
      // This would send a message to the service worker to clear caches
      // Implementation would use js interop
    } catch (e) {
      debugPrint('[SW] Error clearing cache: $e');
    }
  }

  /// Check if service worker is registered
  bool get isRegistered => _isRegistered;
}
