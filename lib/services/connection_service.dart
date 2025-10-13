import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/foundation.dart';
class ConnectionService {
  static final ConnectionService _instance = ConnectionService._internal();
  factory ConnectionService() => _instance;
  ConnectionService._internal();

  Timer? _connectionCheckTimer;
  Timer? _disconnectDebounceTimer;
  bool _isConnected = true;
  int _consecutiveFailures = 0;
  final _connectionController = StreamController<bool>.broadcast();

  Stream<bool> get connectionStatus => _connectionController.stream;
  bool get isConnected => _isConnected;

  // Start monitoring connection status
  void startMonitoring() {
    // Check connection every 60 seconds (increased from 30 to reduce false positives)
    _connectionCheckTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _checkConnection(),
    );

    // Initial check after a delay to allow Firebase to connect after app load/refresh
    Future.delayed(const Duration(seconds: 3), () {
      _checkConnection();
    });
  }

  // Check if Firebase connection is active
  Future<void> _checkConnection() async {
    try {
      // Try a lightweight Firestore operation to test connection
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        _updateConnectionStatus(false);
        return;
      }

      // Test Firestore connection with increased timeout (10 seconds instead of 5)
      await FirebaseFirestore.instance
          .collection('_connection_test')
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Connection check timeout'),
          );

      // Verify auth token is still valid
      await user.getIdToken(false).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Token check timeout'),
      );

      _updateConnectionStatus(true);
    } catch (e) {
      debugPrint('Connection check failed (attempt 1): $e');
      
      // Retry once before marking as disconnected to avoid false positives
      await Future.delayed(const Duration(seconds: 2));
      
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await user.getIdToken(false).timeout(const Duration(seconds: 10));
          _updateConnectionStatus(true);
          debugPrint('Connection check succeeded on retry');
          return;
        }
      } catch (retryError) {
        debugPrint('Connection check failed (attempt 2): $retryError');
      }
      
      _updateConnectionStatus(false);
      
      // Try to recover connection
      await _attemptReconnection();
    }
  }

  // Update connection status and notify listeners
  void _updateConnectionStatus(bool connected) {
    if (connected) {
      // Reset failure count on successful connection
      _consecutiveFailures = 0;
      _disconnectDebounceTimer?.cancel();
      
      if (_isConnected != connected) {
        _isConnected = connected;
        _connectionController.add(connected);
        debugPrint('Connection status changed: CONNECTED');
      }
    } else {
      // Only show disconnected after 2 consecutive failures to avoid false positives
      _consecutiveFailures++;
      debugPrint('Connection check failed (failure count: $_consecutiveFailures)');
      
      if (_consecutiveFailures >= 2 && _isConnected) {
        // Wait 3 more seconds before showing disconnection banner
        _disconnectDebounceTimer?.cancel();
        _disconnectDebounceTimer = Timer(const Duration(seconds: 3), () {
          if (_consecutiveFailures >= 2) {
            _isConnected = false;
            _connectionController.add(false);
            debugPrint('Connection status changed: DISCONNECTED');
          }
        });
      }
    }
  }

  // Attempt to reconnect by refreshing auth token
  Future<void> _attemptReconnection() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        debugPrint('Attempting to refresh auth token...');
        await user.getIdToken(true); // Force refresh
        debugPrint('Auth token refreshed successfully');
        
        // Recheck connection
        await Future.delayed(const Duration(seconds: 2));
        await _checkConnection();
      }
    } catch (e) {
      debugPrint('Reconnection attempt failed: $e');
    }
  }

  // Manually trigger connection check
  Future<bool> checkConnectionNow() async {
    await _checkConnection();
    return _isConnected;
  }

  // Stop monitoring
  void stopMonitoring() {
    _connectionCheckTimer?.cancel();
    _disconnectDebounceTimer?.cancel();
    _connectionController.close();
  }

  // Force reconnection
  Future<void> forceReconnect() async {
    debugPrint('Force reconnection initiated...');
    await _attemptReconnection();
  }
}
