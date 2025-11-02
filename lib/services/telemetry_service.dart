import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Lightweight telemetry writer for simple event recording.
///
/// This intentionally keeps dependencies minimal and writes small documents
/// to `telemetry/events` in Firestore. Events include: uid (if available),
/// eventName, timestamp, optional properties map, and optional durationMs.
class TelemetryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // In-memory map for short-lived start timestamps (ms since epoch).
  final Map<String, int> _startTimestamps = {};

  static final TelemetryService _instance = TelemetryService._internal();
  factory TelemetryService() => _instance;
  TelemetryService._internal();

  Future<void> recordEvent(String eventName, {Map<String, dynamic>? properties, int? durationMs}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final doc = {
        'eventName': eventName,
        'uid': user?.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'properties': properties ?? {},
      };
      if (durationMs != null) doc['durationMs'] = durationMs;

      await _db.collection('telemetry').doc('events').collection('items').add(doc);
    } catch (e) {
      // Telemetry should not break user experience; log locally.
      // ignore: avoid_print
      debugPrint('Telemetry recordEvent error: $e');
    }
  }

  /// Mark the start of a timed event. Use [key] to correlate start/stop.
  void markStart(String key) {
    _startTimestamps[key] = DateTime.now().millisecondsSinceEpoch;
  }

  /// Mark the end of a previously started timed event and send it.
  Future<void> markEnd(String key, String eventName, {Map<String, dynamic>? properties}) async {
    final start = _startTimestamps.remove(key);
    final end = DateTime.now().millisecondsSinceEpoch;
    if (start != null) {
      final duration = end - start;
      await recordEvent(eventName, properties: properties, durationMs: duration);
    } else {
      // If no start found, still record event without duration
      await recordEvent(eventName, properties: properties);
    }
  }
}
