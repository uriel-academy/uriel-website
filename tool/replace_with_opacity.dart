import 'dart:io';

void main() {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    stderr.writeln('lib directory not found');
    exit(1);
  }

  final files = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));

  for (final file in files) {
    final original = file.readAsStringSync();
    final updated = original.replaceAllMapped(
      RegExp(r'\.withOpacity\(([^)]+)\)'),
      (match) => '.withValues(alpha: ${match[1]})',
    );

    if (updated != original) {
      file.writeAsStringSync(updated);
    }
  }
}
