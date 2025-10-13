import 'dart:io';

void main() async {
  print('🧹 Starting batch cleanup...\n');

  // Find all Dart files in lib directory
  final libDir = Directory('lib');
  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();

  print('📁 Found ${dartFiles.length} Dart files\n');

  int filesModified = 0;
  int printReplacements = 0;

  for (var file in dartFiles) {
    try {
      String content = await file.readAsString();
      String originalContent = content;
      bool modified = false;

      // Replace print() with debugPrint()
      // Match print statements but avoid debugPrint, blueprints, etc.
      final printPattern = RegExp(r'\bprint\(');
      if (printPattern.hasMatch(content)) {
        int matches = printPattern.allMatches(content).length;
        content = content.replaceAll(printPattern, 'debugPrint(');
        printReplacements += matches;
        modified = true;
      }

      // Add flutter/foundation.dart import if debugPrint was added and import doesn't exist
      if (modified && content.contains('debugPrint(')) {
        final hasFoundationImport = content.contains("import 'package:flutter/foundation.dart'");
        if (!hasFoundationImport) {
          // Find the last import statement
          final importPattern = RegExp(r'^import\s+.*;\s*$', multiLine: true);
          final matches = importPattern.allMatches(content);
          if (matches.isNotEmpty) {
            final lastImport = matches.last;
            final insertPosition = lastImport.end;
            content = "${content.substring(0, insertPosition)}\nimport 'package:flutter/foundation.dart';${content.substring(insertPosition)}";
          } else {
            // No imports found, add at the beginning
            content = "import 'package:flutter/foundation.dart';\n$content";
          }
        }
      }

      if (content != originalContent) {
        await file.writeAsString(content);
        filesModified++;
        print('✅ ${file.path}');
      }
    } catch (e) {
      print('❌ Error processing ${file.path}: $e');
    }
  }

  print('\n${'=' * 60}');
  print('🎉 Cleanup complete!');
  print('=' * 60);
  print('Files modified: $filesModified');
  print('print() → debugPrint() replacements: $printReplacements');
  print('\n💡 Next steps:');
  print('1. Run: flutter analyze');
  print('2. For const constructors, run: dart fix --apply');
  print('   (This will auto-fix prefer_const_constructors)');
}
