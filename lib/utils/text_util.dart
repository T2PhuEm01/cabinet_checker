import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'decorations.dart';

class TextRobotoAutoBold extends StatelessWidget {
  const TextRobotoAutoBold(
    this.text, {
    super.key,
    this.maxLines,
    this.color,
    this.fontSize,
    this.textAlign,
    this.minFontSize,
    this.decoration,
    this.decorationThickness,
    this.fontWeight,
  });

  final String text;
  final int? maxLines;
  final Color? color;
  final FontWeight? fontWeight;
  final double? fontSize;
  final TextAlign? textAlign;
  final double? minFontSize;
  final TextDecoration? decoration;
  final double? decorationThickness;

  @override
  Widget build(BuildContext context) {
    // ✅ Get theme safely with fallback
    final theme = Get.context != null ? Get.theme : Theme.of(context);
    final baseStyle = theme.textTheme.labelMedium ?? const TextStyle();

    return AutoSizeText(
      text,
      maxLines: maxLines ?? 2,
      minFontSize: minFontSize ?? 10,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign ?? TextAlign.start,
      style: baseStyle.copyWith(
        color: color,
        fontWeight: fontWeight ?? FontWeight.bold,
        fontSize: fontSize,
        decoration: decoration,
        decorationThickness: decorationThickness,
      ),
    );
  }
}

class RichTextRoboto extends StatelessWidget {
  const RichTextRoboto({
    super.key,
    required this.children,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.fontSize,
    this.color,
    this.fontWeight,
  });

  final List<InlineSpan> children;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  final double? fontSize;
  final Color? color;
  final FontWeight? fontWeight;

  @override
  Widget build(BuildContext context) {
    // ✅ Get theme safely with fallback
    final theme = Get.context != null ? Get.theme : Theme.of(context);
    final baseStyle = theme.textTheme.labelMedium ?? const TextStyle();

    return RichText(
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      text: TextSpan(
        style: baseStyle.copyWith(
          color: color,
          fontWeight: fontWeight ?? FontWeight.bold,
          fontSize: fontSize,
        ),
        children: children,
      ),
    );
  }
}

class TextRobotoAutoNormal extends StatelessWidget {
  const TextRobotoAutoNormal(
    this.text, {
    super.key,
    this.maxLines,
    this.color,
    this.fontWeight,
    this.fontSize,
    this.textAlign,
    this.decoration,
    this.height,
  });

  final String text;
  final int? maxLines;
  final Color? color;
  final FontWeight? fontWeight;
  final double? fontSize;
  final TextAlign? textAlign;
  final TextDecoration? decoration;
  final double? height;

  @override
  Widget build(BuildContext context) {
    // ✅ Get theme safely with fallback
    final theme = Get.context != null ? Get.theme : Theme.of(context);
    final baseStyle = theme.textTheme.displaySmall ?? const TextStyle();

    return AutoSizeText(
      text,
      maxLines: maxLines ?? 1,
      minFontSize: 10,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign ?? TextAlign.start,
      style: baseStyle.copyWith(
        color: color,
        fontWeight: fontWeight,
        fontSize: fontSize,
        decoration: decoration,
        height: height,
      ),
    );
  }
}

Widget textSpanWithAction(
  String main,
  String clickAble, {
  int maxLines = 1,
  double? fontSize,
  TextAlign textAlign = TextAlign.center,
  FontWeight fontWeight = FontWeight.bold,
  Color? mainColor,
  VoidCallback? onTap,
  Color? subColor,
}) {
  mainColor = mainColor ?? Get.theme.primaryColorLight;
  subColor = subColor ?? Get.theme.focusColor;
  final baseStyle = Get.theme.textTheme.displaySmall ?? const TextStyle();

  return AutoSizeText.rich(
    TextSpan(
      text: main,
      style: baseStyle.copyWith(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: mainColor,
      ),
      children: <TextSpan>[
        TextSpan(
          text: " $clickAble",
          style: baseStyle.copyWith(
            fontSize: fontSize,
            color: subColor,
            fontWeight: fontWeight,
          ),
          recognizer: TapGestureRecognizer()..onTap = onTap,
        ),
      ],
    ),
    maxLines: maxLines,
    textAlign: textAlign,
  );
}

Widget textWithCopyButton(String text) {
  return Container(
    padding: const EdgeInsets.all(5),
    decoration: boxDecorationRoundCorner(color: Get.theme.secondaryHeaderColor),
    height: 50,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.center,
            child: AutoSizeText(
              text,
              style: (Get.theme.textTheme.displaySmall ?? const TextStyle())
                  .copyWith(color: Get.theme.primaryColor),
              maxLines: 2,
            ),
          ),
        ),
        // buttonOnlyIcon(
        //   iconPath: AssetConstants.icCopy,
        //   iconColor: Get.theme.focusColor,
        //   onPress: () => copyToClipboard(text),
        // ),
      ],
    ),
  );
}

Widget textWithBackground(
  String text, {
  double? width,
  double? height,
  int maxLines = 4,
  Color bgColor = Colors.green,
  Color? textColor,
}) {
  return Container(
    padding: const EdgeInsets.all(10),
    width: width ?? Get.width,
    height: height,
    decoration: boxDecorationRoundCorner(color: bgColor),
    child: TextRobotoAutoBold(text, color: textColor, maxLines: maxLines),
  );
}

Size getTextSize(
  String text,
  TextStyle style, {
  int? maxLine,
  double? width,
  TextScaler? scale,
}) {
  final TextPainter textPainter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: maxLine ?? 100,
    textDirection: TextDirection.ltr,
    textScaler: scale ?? const TextScaler.linear(1),
  )..layout(minWidth: 0, maxWidth: width ?? Get.width);
  return textPainter.size;
}
