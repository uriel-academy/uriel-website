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
  // 1) Collapse repeated punctuation like "1.." or "..." -> "."
  s = s.replaceAll(RegExp(r'\.{2,}'), '.');

  // 2) Fix numbered-list artifacts where AI emits extra dots: "1.." -> "1."
  s = s.replaceAllMapped(RegExp(r'(\d+)\.{1,}'), (m) => '${m.group(1)}.');

  // 3) Common curated split-word fixes
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

  // 4) Remove stray dollar-digit patterns like "$1" -> "1." (common AI artifact)
  s = s.replaceAllMapped(RegExp(r'\$\s*(\d+)'), (m) => '${m.group(1)}.');

  // 5) Ensure numbered lists start on a new line: " ... 1. text" -> "\n1. text"
  s = s.replaceAllMapped(RegExp(r'\s+(\d+)\.\s'), (m) => '\n${m.group(1)}. ');

  // 6) Bulleted lists: ensure newline before '- ' if it got stuck
  s = s.replaceAllMapped(RegExp(r'\s+(-\s+)'), (m) => '\n${m.group(1)}');

  // 7) Remove extra spaces and fix spacing around punctuation
  s = s.replaceAll(RegExp(r'[ \t\f\v]+'), ' ');
  s = s.replaceAllMapped(RegExp(r'\s+([,.;:?!%])'), (m) => m.group(1)!);
  s = s.replaceAllMapped(RegExp(r'([.!?])([A-Za-z0-9])'), (m) => '${m.group(1)} ${m.group(2)}');

  // 8) Contract a few obvious artifacts
  s = s.replaceAll('do ing', 'doing');

  return s.trim();
}

String _aggressiveNormalize(String s) {
  if (s.isEmpty) return s;

  // Remove common junk tokens like repeated '1$1' patterns or lone '$1' fragments
  s = s.replaceAll(RegExp(r'\b1\$1\b'), '1.');
  s = s.replaceAll(RegExp(r'\$(?:1|\s*1)\b'), '');

  // Patterns like '2.^2' -> '2^2' (dot before caret)
  s = s.replaceAllMapped(RegExp(r'(\d+)\.\^(\d+)'), (m) => '${m.group(1)}^${m.group(2)}');

  // Patterns like 'x^2 1$1 $2 x' — try to remove stray numeric-dollar clusters
  s = s.replaceAll(RegExp(r'\b\d+\$1\b'), '');

  // Remove unmatched single '$' characters while preserving $$...$$ blocks.
  // Replace all $$...$$ with a placeholder, strip remaining single $, then restore blocks.
  final blockMatches = <String>[];
  s = s.replaceAllMapped(RegExp(r'\$\$[\s\S]*?\$\$'), (m) {
    blockMatches.add(m.group(0)!);
    return '<<MATHBLOCK${blockMatches.length - 1}>>';
  });

  // Remove any remaining single $ characters
  s = s.replaceAll('\u0000', '');
  s = s.replaceAll(r'$', '');

  // Restore math blocks
  for (var i = 0; i < blockMatches.length; i++) {
    s = s.replaceAll('<<MATHBLOCK$i>>', blockMatches[i]);
  }

  // Collapse duplicated numbered fragments like '1. 1. 2.' -> keep first occurrence
  s = s.replaceAllMapped(RegExp(r'(\b\d+\.\s+)(\1)+'), (m) => m.group(1)!);

  // Trim stray whitespace again
  s = s.replaceAll(RegExp(r'[ \t\n\r]+'), ' ').trim();
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
