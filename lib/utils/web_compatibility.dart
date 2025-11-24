/// Web compatibility utilities for handling data types that may cause issues in dart2js
library web_compatibility;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/foundation.dart';
/// Safely converts any timestamp value to a web-compatible int
int safeTimestamp(dynamic timestamp) {
  try {
    if (timestamp == null) return DateTime.now().millisecondsSinceEpoch;
    
    if (timestamp is int) return timestamp;
    if (timestamp is double) return timestamp.toInt();
    if (timestamp is String) {
      final parsed = DateTime.tryParse(timestamp);
      return parsed?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
    }
    if (timestamp is Timestamp) {
      return timestamp.millisecondsSinceEpoch;
    }
    if (timestamp is DateTime) {
      return timestamp.millisecondsSinceEpoch;
    }
    
    // Fallback for any unknown type
    return DateTime.now().millisecondsSinceEpoch;
  } catch (e) {
    debugPrint('Warning: Failed to convert timestamp: $e');
    return DateTime.now().millisecondsSinceEpoch;
  }
}

/// Safely converts any date value to DateTime
DateTime safeDateTime(dynamic dateValue) {
  try {
    if (dateValue == null) return DateTime.now();
    
    if (dateValue is DateTime) return dateValue;
    if (dateValue is Timestamp) return dateValue.toDate();
    if (dateValue is String) {
      final parsed = DateTime.tryParse(dateValue);
      return parsed ?? DateTime.now();
    }
    if (dateValue is int) {
      return DateTime.fromMillisecondsSinceEpoch(dateValue);
    }
    if (dateValue is double) {
      return DateTime.fromMillisecondsSinceEpoch(dateValue.toInt());
    }
    
    // Fallback for any unknown type
    return DateTime.now();
  } catch (e) {
    debugPrint('Warning: Failed to convert date: $e');
    return DateTime.now();
  }
}

/// Safely converts any numeric value to int (avoiding Int64 issues)
int safeInt(dynamic value, {int defaultValue = 0}) {
  try {
    if (value == null) return defaultValue;
    
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? defaultValue;
    }
    
    // Handle potential Int64 by converting to string first then int
    final stringValue = value.toString();
    final parsed = int.tryParse(stringValue);
    return parsed ?? defaultValue;
  } catch (e) {
    debugPrint('Warning: Failed to convert to int: $e');
    return defaultValue;
  }
}

/// Safely converts any numeric value to double (avoiding Int64 issues)
double safeDouble(dynamic value, {double defaultValue = 0.0}) {
  try {
    if (value == null) return defaultValue;
    
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? defaultValue;
    }
    
    // Handle potential Int64 by converting to string first then double
    final stringValue = value.toString();
    final parsed = double.tryParse(stringValue);
    return parsed ?? defaultValue;
  } catch (e) {
    debugPrint('Warning: Failed to convert to double: $e');
    return defaultValue;
  }
}

/// Safely handles Firestore document data that might contain Int64 values
Map<String, dynamic> safeDocumentData(Map<String, dynamic> data) {
  final result = <String, dynamic>{};
  
  for (final entry in data.entries) {
    try {
      final key = entry.key;
      final value = entry.value;
      
      // Handle different data types that might be problematic in web
      if (value is List) {
        result[key] = value.map((item) => _safeSingleValue(item)).toList();
      } else if (value is Map) {
        result[key] = safeDocumentData(Map<String, dynamic>.from(value));
      } else {
        result[key] = _safeSingleValue(value);
      }
    } catch (e) {
      debugPrint('Warning: Failed to process field ${entry.key}: $e');
      result[entry.key] = entry.value; // Keep original if conversion fails
    }
  }
  
  return result;
}

/// Helper to safely convert individual values
dynamic _safeSingleValue(dynamic value) {
  if (value == null) return null;
  
  // Handle potential Int64 values
  final valueType = value.runtimeType.toString();
  if (valueType.contains('Int64')) {
    try {
      return safeInt(value);
    } catch (e) {
      debugPrint('Warning: Int64 conversion failed: $e');
      return value.toString();
    }
  }
  
  // Handle Timestamps
  if (value is Timestamp) {
    try {
      return value.toDate().toIso8601String();
    } catch (e) {
      debugPrint('Warning: Timestamp conversion failed: $e');
      return DateTime.now().toIso8601String();
    }
  }
  
  return value;
}
