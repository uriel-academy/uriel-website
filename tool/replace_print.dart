import 'dart:io';

void main() async {
  final libDir = Directory('lib');
  int filesProcessed = 0;
  int totalReplacements = 0;

  await for (final entity in libDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final content = await entity.readAsString();
      
      // Count occurrences
      final printMatches = RegExp(r'\bprint\(').allMatches(content);
      if (printMatches.isEmpty) continue;
      
      // Replace print( with debugPrint(
      final newContent = content.replaceAll(
        RegExp(r'\bprint\('),
        'debugPrint(',
      );
      
      if (newContent != content) {
        await entity.writeAsString(newContent);
        filesProcessed++;
        totalReplacements += printMatches.length;
        print('✓ ${entity.path.replaceAll('\\', '/')}: ${printMatches.length} replacements');
      }
    }
  }

  print('\n${'━' * 40}');
  print('✅ Complete!');
  print('Files processed: $filesProcessed');
  print('Total replacements: $totalReplacements');
  print('━' * 40);
}
