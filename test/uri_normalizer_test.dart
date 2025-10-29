import 'package:flutter_test/flutter_test.dart';
import 'package:uriel_mainapp/services/uri_normalizer.dart';

void main() {
  test('normalizeLatex aggressive fixes dot-before-caret and removes stray dollar markers', () {
    final input = r'Here: 1.. 2.^2 $1 1$1 3.$ and some $$a^2$$ math.';
    final out = normalizeLatex(input, aggressive: true);

    // Expect the '2.^2' -> '2^2' and no lone '$1' or '1$1' tokens
    expect(out.contains('2^2'), isTrue);
    expect(out.contains('\$1'), isFalse);
    expect(out.contains('1\$1'), isFalse);
    // $$ block should remain
    expect(out.contains(r'$$a^2$$'), isTrue);
  });

  test('splitIntoSegments separates inline and block math', () {
    final text = r'Intro $x^2+1$ middle $$y = 2$$ end';
    final segments = splitIntoSegments(text);
    // Expect 3 non-empty segments: intro, inline math, middle, block math, end -> total 5
    expect(segments.length, greaterThanOrEqualTo(3));
    // Find math segments
    final mathSegments = segments.where((s) => s.isMath).toList();
    expect(mathSegments.length, 2);
    expect(mathSegments[0].isBlock, isFalse);
    expect(mathSegments[1].isBlock, isTrue);
  });
}
