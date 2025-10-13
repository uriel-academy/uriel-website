import 'dart:io';

void main() {
  final libDir = Directory('lib');
  
  if (!libDir.existsSync()) {
    print('Error: lib directory not found');
    exit(1);
  }

  int filesProcessed = 0;
  int totalReplacements = 0;

  // Recursively process all .dart files in lib/
  libDir
      .listSync(recursive: true)
      .where((entity) => entity is File && entity.path.endsWith('.dart'))
      .forEach((file) {
    final dartFile = file as File;
    final content = dartFile.readAsStringSync();
    
    // Count occurrences before replacement
    final occurrences = '.withOpacity('.allMatches(content).length;
    
    if (occurrences > 0) {
      // Replace .withOpacity(value) with .withValues(alpha: value)
      final newContent = content.replaceAllMapped(
        RegExp(r'\.withOpacity\(([^)]+)\)'),
        (match) => '.withValues(alpha: ${match.group(1)})',
      );
      
      dartFile.writeAsStringSync(newContent);
      filesProcessed++;
      totalReplacements += occurrences;
      
      print('✓ ${dartFile.path.replaceAll('\\', '/')}: $occurrences replacements');
    }
  });

  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('✅ Complete!');
  print('Files processed: $filesProcessed');
  print('Total replacements: $totalReplacements');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
}
