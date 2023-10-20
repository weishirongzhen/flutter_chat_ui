import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

typedef AtTextCallback = Function(String showText, String actualText);

class AtSpecialTextSpanBuilder extends SpecialTextSpanBuilder {
  AtSpecialTextSpanBuilder({
    this.atCallback,
    this.atStyle,
    this.allAtMap = const <String, String>{},
  });

  static const regexAt = r'(@\{\d+\}\s)';

  static const regexAtAll = r'@atEveryone ';

  final AtTextCallback? atCallback;

  final Map<String, String> allAtMap;
  final TextStyle? atStyle;

  @override
  TextSpan build(
    String data, {
    TextStyle? textStyle,
    SpecialTextGestureTapCallback? onTap,
  }) {
    final buffer = StringBuffer();
    if (kIsWeb) {
      return TextSpan(text: data, style: textStyle);
    }

    final children = <InlineSpan>[];

    final list = [regexAt, regexAtAll];
    final pattern = '(${list.toList().join('|')})';
    final atReg = RegExp(regexAt);
    final atAllReg = RegExp(regexAtAll);

    data.splitMapJoin(
      RegExp(pattern),
      onMatch: (Match m) {
        late InlineSpan inlineSpan;
        final value = m.group(0)!;
        try {
          if (atReg.hasMatch(value)) {
            final id = value.replaceFirst('@', '').trim();
            if (allAtMap.containsKey(id)) {
              final name = allAtMap[id]!;

              inlineSpan = SpecialTextSpan(
                text: '@$name ',
                actualText: value,
                start: m.start,
                style: atStyle,
                recognizer: (TapGestureRecognizer()
                  ..onTap = () {
                    if (onTap != null) {
                      onTap(id);
                    }
                  }),
              );
              buffer.write('@$name ');
            } else {
              inlineSpan = TextSpan(text: value, style: textStyle);
              buffer.write(value);
            }
          } else if (atAllReg.hasMatch(value)) {
            inlineSpan = SpecialTextSpan(
              text: '@所有人 ',
              actualText: value,
              start: m.start,
              style: atStyle,
            );
            buffer.write('@所有人 ');
          } else {
            inlineSpan = TextSpan(text: value, style: textStyle);
            buffer.write(value);
          }
        } catch (_) {}
        children.add(inlineSpan);
        return '';
      },
      onNonMatch: (text) {
        children.add(TextSpan(text: text, style: textStyle));
        buffer.write(text);
        return '';
      },
    );
    if (null != atCallback) atCallback!(buffer.toString(), data);
    return TextSpan(children: children, style: textStyle);
  }

  @override
  SpecialText? createSpecialText(
    String flag, {
    TextStyle? textStyle,
    SpecialTextGestureTapCallback? onTap,
    required int index,
  }) =>
      null;
}
