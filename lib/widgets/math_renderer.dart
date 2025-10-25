import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// A cross-platform math rendering widget that uses flutter_math_fork for math rendering
/// MathJax is loaded in web/index.html for potential future use
class MathRenderer extends StatelessWidget {
  final String texExpression;
  final TextStyle? textStyle;
  final bool isDisplayMode;

  const MathRenderer({
    Key? key,
    required this.texExpression,
    this.textStyle,
    this.isDisplayMode = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fontSize = textStyle?.fontSize ?? (isDisplayMode ? 16.0 : 14.0);
    return Math.tex(
      texExpression,
      textStyle: textStyle ?? TextStyle(fontSize: fontSize),
    );
  }
}