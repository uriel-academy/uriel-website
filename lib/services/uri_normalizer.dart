import 'dart:core';

/// Small utility to normalize AI assistant text before rendering.
/// Exposes conservative normalization plus an optional aggressive pass.

class Segment {
  final String text;
  final bool isMath;
  final bool isBlock;
  Segment(this.text, {this.isMath = false, this.isBlock = false});
}

String normalizeMd(String s) {
  if (s.isEmpty) return s;

  // Conservative, safer normalization approach.
  
  // 1) Common curated split-word fixes (do this early)
  const fixes = {
    'in to': 'into',
    'origin al': 'original',
    'polynom ial': 'polynomial',
    'integr ation': 'integration',
    'theoret ical': 'theoretical',
    'pract ical': 'practical',
    'understand ing': 'understanding',
    'discover ing': 'discovering',
    'develop ing': 'developing',
  };
  fixes.forEach((k, v) => s = s.replaceAll(k, v));

  // 2) Remove stray standalone dots on their own lines (common AI artifact)
  s = s.replaceAll(RegExp(r'^\s*\.\s*$', multiLine: true), '');
  
  // 3) Remove dots before bold headings (artifact like ". **Heading**:")
  s = s.replaceAll(RegExp(r'\.\s*\n\s*\*\*'), '\n**');
  s = s.replaceAll(RegExp(r'^\s*\.\s*\*\*', multiLine: true), '**');
  
  // 4) Remove leading bullets from sub-items under numbered lists
  // Pattern: "1. **Title**:\n - text" → "1. **Title**:\n text"
  s = s.replaceAllMapped(
    RegExp(r'(\d+\.\s+\*\*[^*]+\*\*:[^\n]*\n)\s*-\s+', multiLine: true),
    (m) => '${m.group(1)}   ' // Replace bullet with indent
  );
  
  // 5) Remove bullets from continuation lines after colons (e.g., "can have:\n - item")
  // This catches cases where text after a colon lists items with bullets
  s = s.replaceAllMapped(
    RegExp(r':\s*\n\s+-\s+', multiLine: true),
    (m) => ':\n   - ' // Normalize to consistent format
  );
  
  // 6) Fix inconsistent list formatting - ensure all list items under the same parent have bullets
  // If a paragraph ends with ":" and next lines are mixed bullets, add bullets to all
  s = s.replaceAllMapped(
    RegExp(r':\s*\n\s+([A-Z][^\n]+,)\s*\n\s+-\s+', multiLine: true),
    (m) => ':\n   - ${m.group(1)}\n   - '
  );
  
  // 7) Collapse multiple dots (but not ellipsis intentionally used)
  s = s.replaceAll(RegExp(r'\.{3,}'), '...');
  s = s.replaceAll(RegExp(r'\.{2}(?!\.)'), '.');

  // 8) Contract obvious artifacts
  s = s.replaceAll('do ing', 'doing');

  // 9) Remove extra spaces (but preserve newlines)
  s = s.replaceAll(RegExp(r'[ \t\f\v]+'), ' ');
  
  // 10) Fix spacing around punctuation (but not between numbers/letters and dashes for lists)
  s = s.replaceAllMapped(RegExp(r'\s+([,.;:?!%])'), (m) => m.group(1)!);
  s = s.replaceAllMapped(RegExp(r'([.!?])([A-Za-z0-9])'), (m) => '${m.group(1)} ${m.group(2)}');

  return s.trim();
}

String _aggressiveNormalize(String s) {
  if (s.isEmpty) return s;

  // This is rarely needed - only enable if markdown rendering has major issues
  // Most normalization should happen in normalizeMd() instead
  
  // Remove stray whitespace
  s = s.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
  return s;
}

String normalizeLatex(String s, {bool aggressive = false}) {
  s = normalizeMd(s);

  // Normalize some LaTeX delimiter variants conservatively
  // First, handle escaped backslashes
  s = s.replaceAll(r'\\(', r'\(').replaceAll(r'\\)', r'\)');
  s = s.replaceAll(r'\\[', r'\[').replaceAll(r'\\]', r'\]');

  // Replace \(...\) with $...$ (inline math) - dotAll allows matching across newlines
  s = s.replaceAllMapped(RegExp(r'\\\(([\s\S]*?)\\\)', multiLine: true), (m) {
    final content = m.group(1)!.replaceAll('\n', ' ').trim();
    return '\$$content\$';
  });
  
  // Replace \[...\] with $$...$$ (display math)
  s = s.replaceAllMapped(RegExp(r'\\\[([\s\S]*?)\\\]', multiLine: true), (m) {
    final content = m.group(1)!.trim();
    return '\$\$$content\$\$';
  });

  // If aggressive, apply extra cleanups
  if (aggressive) {
    s = _aggressiveNormalize(s);
  }

  return s;
}

/// Split into math/non-math segments. Returns a list preserving order.
List<Segment> splitIntoSegments(String text) {
  final regex = RegExp(r'(\$\$[\s\S]*?\$\$)|(\$[^\$\n]+\$)');
  final segments = <Segment>[];
  int lastIndex = 0;
  for (final match in regex.allMatches(text)) {
    if (match.start > lastIndex) {
      segments.add(Segment(text.substring(lastIndex, match.start), isMath: false));
    }
    final matched = text.substring(match.start, match.end);
    if (matched.startsWith('\$\$') && matched.endsWith('\$\$')) {
      final inner = matched.substring(2, matched.length - 2).trim();
      segments.add(Segment(inner, isMath: true, isBlock: true));
    } else {
      final inner = matched.substring(1, matched.length - 1).trim();
      segments.add(Segment(inner, isMath: true, isBlock: false));
    }
    lastIndex = match.end;
  }
  if (lastIndex < text.length) {
    segments.add(Segment(text.substring(lastIndex), isMath: false));
  }
  return segments;
}
