import 'package:flutter/material.dart';
import 'package:get/get.dart';

decorationBackgroundGradient() {
  return const BoxDecoration(
    gradient: LinearGradient(
      colors: [Colors.red, Colors.green],
      stops: [-0.5, -0.9, 0.25, 0.6, 1.5, 2],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ),
    borderRadius: BorderRadius.all(Radius.circular(5)),
  );
}

decorationPersentGradient() {
  return const BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFFFE3831), Color(0xFFEC7507)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(10),
      bottomRight: Radius.circular(9),
    ),
  );
}

decorationPersentGradientFix({required BorderRadius borderRadius}) {
  return BoxDecoration(
    gradient: const LinearGradient(
      colors: [Color(0xFF000046), Color(0xFF1CB5E0)],
    ),
    borderRadius: borderRadius,
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF667eea).withValues(alpha: 0.25),
        blurRadius: 15,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

boxDecorationRoundCorner({
  BuildContext? context,
  Color? color,
  double radius = 7,
}) {
  color =
      color ??
      context?.theme.secondaryHeaderColor ??
      Get.theme.secondaryHeaderColor;
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.all(Radius.circular(radius)),
    border: Border.all(color: Get.theme.primaryColor.withValues(alpha: 0.2)),
  );
}

boxDecorationRoundBorder({
  BuildContext? context,
  Color? color,
  Color? borderColor,
  double radius = 7,
  double? width,
}) {
  color =
      color ??
      context?.theme.secondaryHeaderColor ??
      Get.theme.scaffoldBackgroundColor;
  borderColor = borderColor ?? Get.theme.dividerColor;
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.all(Radius.circular(radius)),
    border: Border.all(color: borderColor, width: width ?? 0.5),
  );
}

boxDecorationTopRoundBorder({
  Color? color,
  Color? borderColor,
  double radius = 7,
}) {
  color = color ?? Get.theme.scaffoldBackgroundColor;
  borderColor = borderColor ?? Get.theme.dividerColor;
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(radius),
      topRight: Radius.circular(radius),
    ),
    border: Border.all(color: borderColor, width: 0.5),
  );
}

boxDecorationWithShadow({Color? color, double radius = 7}) {
  color = color ?? Get.theme.scaffoldBackgroundColor;
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.all(Radius.circular(radius)),

    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.2),
        blurRadius: 4,
        offset: const Offset(0, 1), // Shadow position
      ),
    ],
  );
}

boxDecorationWithShadowCustomRadius({
  Color? color,
  Border? border,
  BorderRadius? borderRadius,
}) {
  color = color ?? Get.theme.scaffoldBackgroundColor;
  return BoxDecoration(
    color: color,
    borderRadius: borderRadius,
    border: border,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.2),
        blurRadius: 4,
        offset: const Offset(0, 1), // Shadow position
      ),
    ],
  );
}

boxDecorationTopRound({
  Color? color,
  bool isGradient = false,
  double radius = 7,
}) {
  color = color ?? Get.theme.scaffoldBackgroundColor;
  return BoxDecoration(
    color: isGradient ? null : color,
    gradient: isGradient ? linearGradient(color) : null,
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(radius),
      topRight: Radius.circular(radius),
    ),
  );
}

boxDecorationRightRound({
  Color? color,
  bool isGradient = false,
  double radius = 7,
}) {
  color = color ?? Get.theme.scaffoldBackgroundColor;
  return BoxDecoration(
    color: isGradient ? null : color,
    gradient: isGradient ? linearGradient(color) : null,
    borderRadius: BorderRadius.only(
      bottomRight: Radius.circular(radius),
      topRight: Radius.circular(radius),
    ),
  );
}

boxDecorationImage({required String imagePath, Color? color}) {
  ColorFilter? colorFilter;
  if (color != null) colorFilter = ColorFilter.mode(color, BlendMode.dstATop);

  return BoxDecoration(
    image: DecorationImage(
      image: AssetImage(imagePath),
      fit: BoxFit.cover,
      colorFilter: colorFilter,
    ),
  );
}

getRoundCornerWithShadow(BoxShape shape, {Color color = Colors.white}) {
  return BoxDecoration(
    color: color,
    shape: shape,
    borderRadius: shape == BoxShape.circle
        ? null
        : const BorderRadius.all(Radius.circular(7)),
    boxShadow: [
      BoxShadow(
        color: Colors.grey.withValues(alpha: 0.2),
        spreadRadius: 0,
        blurRadius: 1,
        offset: const Offset(1, 1),
      ),
    ],
  );
}

getRoundCornerBorderOnlyTop({Color bgColor = Colors.white}) {
  return BoxDecoration(
    color: bgColor,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
  );
}

decorationRoundCornerBox({Color color = Colors.white}) {
  return BoxDecoration(
    color: color,
    borderRadius: const BorderRadius.all(Radius.circular(7)),
  );
}

getRoundCornerBorderOnlyBottom() {
  return const BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.vertical(bottom: Radius.circular(7)),
  );
}

getRoundSoftTransparentBox() {
  return BoxDecoration(
    color: Get.theme.primaryColor.withValues(alpha: 0.03),
    borderRadius: const BorderRadius.all(Radius.circular(7)),
  );
}

linearGradient(Color color) {
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [color.withValues(alpha: 0.9), color],
  );
}

decorationBottomBorder({
  Color? color,
  // bool isGradient = false,
  // double radius = 7,
}) {
  return BoxDecoration(
    border: Border(bottom: BorderSide(color: color ?? Colors.grey, width: 1)),
  );
}

decorationTopBorder({
  Color? color,
  // bool isGradient = false,
  // double radius = 7,
}) {
  return BoxDecoration(
    border: Border(top: BorderSide(color: color ?? Colors.grey, width: 1)),
  );
}
