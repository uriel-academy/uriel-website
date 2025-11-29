import 'package:flutter/material.dart';

/// Data model for subject progress visualization.
/// 
/// Used in the student dashboard to display progress metrics
/// for each subject with visual color coding.
class SubjectProgress {
  final String name;
  final double progress;
  final Color color;

  SubjectProgress(this.name, this.progress, this.color);

  /// Creates a SubjectProgress from JSON data.
  factory SubjectProgress.fromJson(Map<String, dynamic> json) {
    return SubjectProgress(
      json['name'] as String,
      (json['progress'] as num).toDouble(),
      Color(json['color'] as int),
    );
  }

  /// Converts this SubjectProgress to JSON data.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'progress': progress,
      'color': color.value,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SubjectProgress &&
        other.name == name &&
        other.progress == progress &&
        other.color == color;
  }

  @override
  int get hashCode => Object.hash(name, progress, color);

  @override
  String toString() => 'SubjectProgress(name: $name, progress: $progress, color: $color)';
}
