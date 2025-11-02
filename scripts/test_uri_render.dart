import 'dart:io';

// This script simulates the markdown+LaTeX split used in the app and
// prints a terminal-friendly preview. It uses simple regex-based
// splitting and prints math segments as [MATH:inline] or [MATH:block].

String normalizeLatex(String s) {
  return _normalizeMd(s);
}

String _normalizeMd(String s) {
  s = s.replaceAll(RegExp(r'\.{2,}'), '.');
  s = s.replaceAllMapped(RegExp(r'(\d+)\.{1,}'), (m) => '${m.group(1)}.');
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
  s = s.replaceAllMapped(RegExp(r'\$\s*(\d+)'), (m) => '${m.group(1)}.');
  s = s.replaceAllMapped(RegExp(r'\s+(\d+)\.\s'), (m) => '\n${m.group(1)}. ');
  s = s.replaceAllMapped(RegExp(r'\s+(-\s+)'), (m) => '\n${m.group(1)}');
  s = s.replaceAll(RegExp(r'[ \t\f\v]+'), ' ');
  s = s.replaceAllMapped(RegExp(r'\s+([,.;:?!%])'), (m) => m.group(1)!);
  s = s.replaceAllMapped(RegExp(r'([.!?])([A-Za-z0-9])'), (m) => '${m.group(1)} ${m.group(2)}');
  s = s.replaceAll('do ing', 'doing');
  return s.trim();
}

void printRenderedPreview(String raw) {
  final normalized = normalizeLatex(raw);
  print('\n--- NORMALIZED TEXT ---\n');
  print(normalized);

  final regex = RegExp(r'(\$\$[\s\S]*?\$\$)|(\$[^\$\n]+\$)');
  int last = 0;
  print('\n--- RENDERED PREVIEW ---\n');
  for (final m in regex.allMatches(normalized)) {
    if (m.start > last) {
      final md = normalized.substring(last, m.start);
      // Very simple markdown rendering: headings -> uppercase, bold **x** -> X
      var snippet = md.replaceAllMapped(RegExp(r'###\s*(.*)'), (mm) => '\n${mm.group(1)!.toUpperCase()}\n');
      snippet = snippet.replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (mm) => mm.group(1)!.toUpperCase());
      snippet = snippet.replaceAllMapped(RegExp(r'\*(.*?)\*'), (mm) => mm.group(1)!);
      // Lists: ensure bullets line by line
      snippet = snippet.replaceAll(RegExp(r'\n?\s*-\s*'), '\n• ');
      snippet = snippet.replaceAll(RegExp(r'\n?\s*(\d+)\.\s*'), '\n1. ');
      print(snippet);
    }

    final matched = normalized.substring(m.start, m.end);
    if (matched.startsWith(r'$$') && matched.endsWith(r'$$')) {
      final inner = matched.substring(2, matched.length - 2).trim();
      print('\n[MATH block]');
      print(inner);
      print('\n');
    } else if (matched.startsWith(r'$') && matched.endsWith(r'$')) {
      final inner = matched.substring(1, matched.length - 1).trim();
      stdout.write('[MATH inline: ');
      stdout.write(inner);
      stdout.writeln(']');
    } else {
      print(matched);
    }

    last = m.end;
  }
  if (last < normalized.length) {
    final rest = normalized.substring(last);
    var snippet = rest.replaceAllMapped(RegExp(r'###\s*(.*)'), (mm) => '\n${mm.group(1)!.toUpperCase()}\n');
    snippet = snippet.replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (mm) => mm.group(1)!.toUpperCase());
    snippet = snippet.replaceAll(RegExp(r'\n?\s*-\s*'), '\n• ');
    print(snippet);
  }
}

void main() {
  const raw = r'''Factorization is the process of breaking down a number or a polynomial in to its components, known as factors, which, when multiplied together, yield the origin al number or polynomial. This technique is commonly used in mathematics to simplify expressions, solve equations, and understand the properties of numbers.

### Types of Factorization
1.. **Number Factorization**: This involves expressing a number as a product of its factors. For example, the number 12 can be factored in to 3 × 4 or 2 ×
1.. 
1.. **Prime Factorization**: This is a specific type of number factorization where a number is expressed as a product of prime numbers. For instance, the prime factorization of 12 is 2 × 2 × 3, or in exponential form, it can be written as 2.^2 \times 3^1$.
1.. **Polynomial Factorization**: This involves expressing a polynomial as a product of simpler polynomials. For example, the polynomial $x^2
1$1 $2 x + 6$ can be factored in to $(x
1$1 $2)(x
1$1 $2)$.

### Importance of Factorization
1.**Simplification**: It helps in simplifying complex expressions.
1.**Solving Equations**: Factorization is often used to solve quadratic equations and higher-degree polynomials.
1.**Finding Roots**: It allows us to find the roots of polynomials by setting each factor equal to zero.

If you have a specific example or type of factorization you want to explore further, feel free to ask!
''';

  printRenderedPreview(raw);
}
