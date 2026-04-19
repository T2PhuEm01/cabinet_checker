import 'package:auto_size_text/auto_size_text.dart';
import 'package:cabinet_checker/utils/common_utils.dart';
import 'package:cabinet_checker/utils/dimens.dart';
import 'package:cabinet_checker/utils/extentions.dart';
import 'package:cabinet_checker/utils/text_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

Widget buttonRoundedMain({
  String? text,
  VoidCallback? onPress,
  Color? textColor,
  Color? bgColor,
  double buttonHeight = Dimens.btnHeightMain,
  double? width,
  double? borderRadius = Dimens.radiusCornerLarge,
}) {
  width = width ?? Get.width;
  bgColor = bgColor ?? Get.theme.focusColor;
  textColor =
      textColor ?? (bgColor == Get.theme.focusColor ? Colors.white : null);
  return Container(
    margin: const EdgeInsets.only(left: 0, right: 0, bottom: 0),
    height: buttonHeight,
    width: width,
    child: ElevatedButton(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all<Color>(bgColor),
        backgroundColor: WidgetStateProperty.all<Color>(bgColor),
        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(borderRadius!)),
            side: BorderSide(color: bgColor),
          ),
        ),
      ),
      onPressed: onPress,
      child: AutoSizeText(
        text ?? "",
        style: Get.theme.textTheme.labelMedium!.copyWith(color: textColor),
        maxLines: 1,
      ),
    ),
  );
}

Widget buttonTextRoundedMain({
  String? text,
  VoidCallback? onPress,
  Color? textColor,
  Color? bgColor,
  Border? borderColor,
  double? borderRadius = Dimens.radiusCornerLarge,
  EdgeInsets? padding,
  double? fontSize,
  FontWeight? fontWeight,
  double? buttonHeight,
  double? buttonWidth,
}) {
  return GestureDetector(
    onTap: onPress,
    child: Container(
      // margin: const EdgeInsets.only(left: 0, right: 0, bottom: 0),
      height: buttonHeight,
      width: buttonWidth,
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.all(Radius.circular(borderRadius!)),
        border: borderColor,
      ),
      child: Center(
        child: TextRobotoAutoNormal(
          text ?? "",
          maxLines: 1,
          fontSize: fontSize,
          color: textColor,
          fontWeight: fontWeight,
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

Widget textRoundedMain({
  VoidCallback? onPress,
  String? text,
  Color? textColor,
  Color? bgColor,
  Border? borderColor,
  double? borderRadius = Dimens.radiusCornerLarge,
  EdgeInsets? padding,
  double? fontSize,
  FontWeight? fontWeight,
}) {
  return GestureDetector(
    onTap: onPress,
    child: Container(
      // margin: const EdgeInsets.only(left: 0, right: 0, bottom: 0),
      // height: buttonHeight,
      // width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.all(Radius.circular(borderRadius!)),
        border: borderColor,
      ),
      child: TextRobotoAutoNormal(
        text ?? "",
        maxLines: 1,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: textColor,
        textAlign: TextAlign.center,
      ),
    ),
  );
}

Widget buttonWithIcon({
  String? text,
  VoidCallback? onPress,
  IconData? iconData,
  String? iconPath,
  Color? textColor,
  double? fontSize,
  double iconSize = Dimens.iconSizeMin,
  Color? bgColor,
  Color? iconColor,
  FontWeight? fontWeight,
  double radius = Dimens.radiusCorner,
  bool? boldText = false,
  Color? borderColor,
  // VisualDensity? visualDensity,
  // double? borderRadius = Dimens.radiusCorner,
  EdgeInsets? padding,
  TextDirection textDirection = TextDirection.rtl,
}) {
  return Directionality(
    textDirection: textDirection,
    child: GestureDetector(
      onTap: onPress,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.all(Radius.circular(radius)),
          border: Border.all(color: borderColor ?? Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            boldText == true
                ? TextRobotoAutoBold(
                    text ?? "",
                    color: textColor,
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                  )
                : TextRobotoAutoNormal(
                    text ?? "",
                    color: textColor,
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                  ),
          ],
        ),
      ),

      // style: ButtonStyle(
      //   elevation: WidgetStateProperty.all<double>(0),
      //   visualDensity: visualDensity,
      //   padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
      //     padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      //   ),
      //   foregroundColor: WidgetStateProperty.all<Color>(bgColor),
      //   backgroundColor: WidgetStateProperty.all<Color>(bgColor),
      //   shape: WidgetStateProperty.all<RoundedRectangleBorder>(
      //     RoundedRectangleBorder(
      //       borderRadius: BorderRadius.all(Radius.circular(borderRadius!)),
      //       side: BorderSide(color: borderColor ?? bgColor),
      //     ),
      //   ),
      // ),
    ),
  );
}

Widget textWithContainer({
  String? text,
  VoidCallback? onPress,
  IconData? iconData,
  String? iconPath,
  Color? textColor,
  double? fontSize,
  double iconSize = Dimens.iconSizeMin,
  Color? bgColor,
  Color? iconColor,
  FontWeight? fontWeight,
  double radius = Dimens.radiusCorner,
  Color? borderColor,
  EdgeInsets? padding,
  TextAlign? textAlign,
  int? maxLines,
  bool nomalText = true,
}) {
  return Container(
    padding: padding,
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.all(Radius.circular(radius)),
      border: Border.all(color: borderColor ?? Colors.transparent),
    ),
    child: nomalText
        ? TextRobotoAutoNormal(
            text ?? "",
            color: textColor,
            fontSize: fontSize,
            fontWeight: fontWeight,
            textAlign: textAlign,
            maxLines: maxLines,
          )
        : TextRobotoAutoBold(
            text ?? "",
            color: textColor,
            fontSize: fontSize,
            textAlign: textAlign,
            maxLines: maxLines,
          ),
  );
}

Widget textWithIconNormal({
  String? text,
  VoidCallback? onPress,
  IconData? iconData,
  String? iconPath,
  Color? textColor,
  double? fontSize,
  double iconSize = Dimens.iconSizeMin,
  Color? bgColor,
  Color? iconColor,
  FontWeight? fontWeight,
  int? maxLines,
  TextAlign? textAlign,
  double radius = Dimens.radiusCorner,
  EdgeInsets? padding,
  TextDirection textDirection = TextDirection.rtl,
  bool expandText = true, // ✅ Thêm parameter này
}) {
  return Directionality(
    textDirection: textDirection,
    child: Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.all(Radius.circular(radius)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ✅ Conditional Expanded
          if (expandText)
            Expanded(
              child: TextRobotoAutoNormal(
                text ?? "",
                color: textColor,
                fontSize: fontSize,
                fontWeight: fontWeight,
                maxLines: maxLines,
                textAlign: textAlign ?? TextAlign.left,
              ),
            )
          else
            TextRobotoAutoNormal(
              text ?? "",
              color: textColor,
              fontSize: fontSize,
              fontWeight: fontWeight,
              maxLines: maxLines,
              textAlign: textAlign ?? TextAlign.left,
            ),
        ],
      ),
    ),
  );
}

Widget buttonText(
  String text, {
  VoidCallback? onPress,
  Color? textColor,
  Color? bgColor,
  Color? borderColor,
  VisualDensity? visualDensity,
  double? fontSize,
  double? radius,
  BorderRadius? radius1,
}) {
  bgColor = bgColor ?? Get.theme.focusColor;
  fontSize =
      fontSize ??
      (visualDensity == minimumVisualDensity
          ? Dimens.regularFontSizeExtraMid
          : null);
  textColor =
      textColor ?? (bgColor == Get.theme.focusColor ? Colors.white : null);
  return ElevatedButton(
    style: ButtonStyle(
      visualDensity: visualDensity,
      elevation: WidgetStateProperty.all<double>(0),
      padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
        const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      ),
      foregroundColor: WidgetStateProperty.all<Color>(bgColor),
      backgroundColor: WidgetStateProperty.all<Color>(bgColor),
      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(
          borderRadius:
              radius1 ??
              BorderRadius.all(
                Radius.circular(radius ?? Dimens.radiusCornerLarge),
              ),
          side: BorderSide(color: borderColor ?? bgColor),
        ),
      ),
    ),
    onPressed: onPress,
    child: AutoSizeText(
      text,
      style: Get.theme.textTheme.labelMedium!.copyWith(
        fontSize: fontSize,
        color: textColor,
      ),
      minFontSize: 8,
      maxLines: 1,
    ),
  );
}

buttonTextBordered(
  String text,
  bool selected, {
  VoidCallback? onPress,
  Color? color,
  VisualDensity? visualDensity,
  double? radius,
}) {
  color = color ?? Get.theme.focusColor;
  return buttonText(
    text,
    visualDensity: visualDensity,
    bgColor: Colors.transparent,
    radius: radius,
    textColor: selected ? color : Get.theme.primaryColor.withValues(alpha: 0.5),
    borderColor: selected
        ? color
        : Get.theme.primaryColor.withValues(alpha: 0.1),
    onPress: onPress,
  );
}

Widget buttonRoundedWithIcon({
  String? text,
  VoidCallback? onPress,
  IconData? iconData,
  String? iconPath,
  Color? textColor,
  Color? bgColor,
  Color? borderColor,
  VisualDensity? visualDensity,
  double? borderRadius = Dimens.radiusCorner,
  EdgeInsets? padding,
  TextDirection textDirection = TextDirection.rtl,
}) {
  bgColor = bgColor ?? Colors.grey;
  final iconColor = textColor ?? Get.theme.primaryColor;
  return Directionality(
    textDirection: textDirection,
    child: ElevatedButton.icon(
      icon: Icon(iconData ?? Icons.arrow_back, color: iconColor),
      style: ButtonStyle(
        elevation: WidgetStateProperty.all<double>(0),
        visualDensity: visualDensity,
        padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
          padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        ),
        foregroundColor: WidgetStateProperty.all<Color>(bgColor),
        backgroundColor: WidgetStateProperty.all<Color>(bgColor),
        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(borderRadius!)),
            side: BorderSide(color: borderColor ?? bgColor),
          ),
        ),
      ),
      onPressed: onPress,
      label: AutoSizeText(
        text ?? "",
        style: Get.theme.textTheme.labelMedium!.copyWith(color: textColor),
      ),
    ),
  );
}

Widget buttonOnlyIcon({
  VoidCallback? onPress,
  String? iconPath,
  IconData? iconData,
  double? size,
  Color? iconColor,
  double? padding,
  VisualDensity? visualDensity,
}) {
  size = size ?? Dimens.iconSizeMin;
  return IconButton(
    padding: padding == null ? EdgeInsets.zero : EdgeInsets.all(padding),
    visualDensity: visualDensity,
    onPressed: onPress,
    icon: iconPath.isValid
        ? iconPath!.contains(".svg")
              ? SvgPicture.asset(
                  iconPath,
                  width: size,
                  height: size,
                  colorFilter: iconColor == null
                      ? null
                      : ColorFilter.mode(iconColor, BlendMode.srcIn),
                )
              : Image.asset(
                  iconPath,
                  width: size,
                  height: size,
                  color: iconColor,
                )
        : iconData != null
        ? Icon(iconData, size: size, color: iconColor)
        : const SizedBox(),
  );
}

Widget iconRoundedMain({
  String? text,
  Color? textColor,
  Color? bgColor,
  Border? borderColor,
  double? borderRadius = Dimens.radiusCornerLarge,
  EdgeInsets? padding,
  double? fontSize,
  FontWeight? fontWeight,
  VoidCallback? onPress,
  String? iconPath,
  IconData? iconData,
  double? size,
  bool radiusCustom = false,
  double? height,
  Color? iconColor,
  VisualDensity? visualDensity,
}) {
  return GestureDetector(
    onTap: onPress,
    child: Container(
      // margin: const EdgeInsets.only(left: 0, right: 0, bottom: 0),
      height: height,
      // width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: radiusCustom
            ? BorderRadius.only(
                topRight: Radius.circular(borderRadius!),
                bottomRight: Radius.circular(borderRadius),
              )
            : BorderRadius.all(Radius.circular(borderRadius!)),
        border: borderColor,
      ),
      child: iconPath.isValid
          ? iconPath!.contains(".svg")
                ? SvgPicture.asset(
                    iconPath,
                    width: size,
                    height: size,
                    colorFilter: iconColor == null
                        ? null
                        : ColorFilter.mode(iconColor, BlendMode.srcIn),
                  )
                : Image.asset(
                    iconPath,
                    width: size,
                    height: size,
                    color: iconColor,
                  )
          : iconData != null
          ? Icon(iconData, size: size, color: iconColor)
          : const SizedBox(),
    ),
  );
}
