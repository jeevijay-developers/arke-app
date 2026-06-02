import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

// Renders a string that may contain inline LaTeX ($...$, $$...$$) and plain text.
// For full HTML, fall back to plain text (flutter_html beta API varies).
class MathHtmlWidget extends StatelessWidget {
  final String data;
  final TextStyle? textStyle;
  final double mathFontSize;

  const MathHtmlWidget(
    this.data, {
    super.key,
    this.textStyle,
    this.mathFontSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    final style = textStyle ??
        const TextStyle(color: Colors.white, fontSize: 15, height: 1.5);
    final segments = _parse(data);
    if (segments.isEmpty) return const SizedBox.shrink();

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      runSpacing: 4,
      children: segments.map((seg) {
        if (seg.isLatex) {
          return Math.tex(
            seg.content,
            textStyle: style.copyWith(fontSize: mathFontSize),
            onErrorFallback: (e) => Text(
              seg.content,
              style: style.copyWith(
                color: Colors.redAccent,
                fontFamily: 'monospace',
              ),
            ),
          );
        }
        // Strip basic HTML tags for plain text rendering
        final plain = _stripHtml(seg.content);
        if (plain.isEmpty) return const SizedBox.shrink();
        return Text(plain, style: style);
      }).toList(),
    );
  }

  static List<_Segment> _parse(String raw) {
    final segments = <_Segment>[];
    // Match $$...$$ first (block), then $...$ (inline)
    final pattern = RegExp(r'\$\$(.+?)\$\$|\$(.+?)\$', dotAll: true);
    int last = 0;
    for (final m in pattern.allMatches(raw)) {
      if (m.start > last) {
        segments.add(_Segment(raw.substring(last, m.start), false));
      }
      final latex = m.group(1) ?? m.group(2) ?? '';
      segments.add(_Segment(latex, true));
      last = m.end;
    }
    if (last < raw.length) {
      segments.add(_Segment(raw.substring(last), false));
    }
    return segments;
  }

  static String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]+>'), '').trim();
}

class _Segment {
  final String content;
  final bool isLatex;
  _Segment(this.content, this.isLatex);
}
