
String normalizeLatex(String s) {
  // First apply comprehensive text normalization
  s = _normalizeMd(s);

  // Conservative normalization for common escaped delimiters
  s = s.replaceAll(r'\\(', r'\\(').replaceAll(r'\\)', r'\\)');
  s = s.replaceAll(r'\\[', r'\\[').replaceAll(r'\\]', r'\\]');

  // Replace any remaining single-escaped delimiters with dollar markers
  s = s.replaceAll(r'\\(', r'\$').replaceAll(r'\\)', r'\$');
  s = s.replaceAll(r'\\[', r'\$\$').replaceAll(r'\\]', r'\$\$');
  return s;
}

String _normalizeMd(String s) {
  // Print snippet for debugging
  final prefix = s.length > 300 ? '${s.substring(0, 300)}...' : s;
  print('--- Normalization run ---');
  print('Raw input (snippet):');
  print(prefix);

  // 1) Collapse repeated punctuation like "1.." or "..." -> "."
  s = s.replaceAll(RegExp(r'\.{2,}'), '.');

  // 2) Fix numbered-list artifacts where AI emits extra dots: "1.." -> "1."
  s = s.replaceAllMapped(RegExp(r'(\d+)\.{1,}'), (m) => '${m.group(1)}.');

  // 3) Common known bad splits and typos
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

  // 8) Contract spaced letters that are obviously artifacts: e.g. 'do ing' -> 'doing'
  s = s.replaceAll('do ing', 'doing');

  final out = s.trim();
  final outPrefix = out.length > 300 ? '${out.substring(0, 300)}...' : out;
  print('\nNormalized (snippet):');
  print(outPrefix);
  print('--- End normalization ---\n');
  return out;
}

void main() {
  // The malformed AI output (as the user pasted in the conversation)
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

  print('\n=== RAW AI OUTPUT ===\n');
  print(raw);

  final normalized = normalizeLatex(raw);

  print('\n=== NORMALIZED OUTPUT ===\n');
  print(normalized);
}
