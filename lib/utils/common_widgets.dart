import 'package:cabinet_checker/utils/button_util.dart';
import 'package:cabinet_checker/utils/constants.dart';
import 'package:cabinet_checker/utils/decorations.dart';
import 'package:cabinet_checker/utils/dimens.dart';
import 'package:cabinet_checker/utils/extentions.dart';
import 'package:cabinet_checker/utils/spacers.dart';
import 'package:cabinet_checker/utils/text_util.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    this.message,
    this.height,
    this.hideIcon,
    this.icon,
  });

  final String? message;
  final double? height;
  final bool? hideIcon;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Get.width,
      height: height,
      padding: const EdgeInsets.all(Dimens.paddingMid),
      child: Column(
        children: [
          hideIcon == true
              ? vSpacer0()
              : Icon(
                  icon ?? Icons.subtitles_off,
                  size: Dimens.iconSizeLarge,
                  color: context.theme.primaryColorLight,
                ),
          TextRobotoAutoNormal(message ?? "No data available".tr, maxLines: 3),
        ],
      ),
    );
  }
}

Widget showEmptyView({String? message, double height = 20}) {
  message = message ?? "No data available".tr;
  return SizedBox(
    width: Get.width,
    height: height,
    child: Center(
      child: TextRobotoAutoNormal(message, textAlign: TextAlign.center),
    ),
  );
}

Widget showLoading() {
  return Padding(
    padding: const EdgeInsets.all(20),
    child: Center(
      child: CircularProgressIndicator(color: Get.theme.focusColor),
    ),
  );
}

Widget showLoadingSmall() {
  return Padding(
    padding: const EdgeInsets.all(5),
    child: Center(
      child: SizedBox(
        width: Dimens.btnHeightMin,
        height: Dimens.btnHeightMin,
        child: CircularProgressIndicator(color: Get.theme.focusColor),
      ),
    ),
  );
}

Widget dropDownListIndex(
  List<String> items,
  int selectedValue,
  String hint,
  Function(int index) onChange, {
  Color? bgColor,
  Color? borderColor,
  double? height,
  double? width,
  double? padding,
  double? radius,
  double? hintFontSize,
  double? fontSize,
  double hMargin = 10,
  double vMargin = 5,
  bool isBordered = true,
  bool isEditable = true,
  bool isExpanded = true,
}) {
  bgColor = bgColor ?? Colors.transparent;
  borderColor = borderColor ?? Get.theme.dividerColor;
  padding = padding ?? Dimens.paddingMid;
  height = height ?? Dimens.btnHeightMain;

  return Container(
    margin: EdgeInsets.only(
      left: hMargin,
      top: vMargin,
      right: hMargin,
      bottom: vMargin,
    ),
    padding: EdgeInsets.only(left: padding, top: 0, right: padding, bottom: 0),
    height: height,
    width: width,
    decoration: isBordered
        ? boxDecorationRoundBorder(
            color: bgColor,
            borderColor: borderColor,
            radius: radius ?? Dimens.radiusCorner,
            width: 1,
          )
        : null,
    alignment: Alignment.center,
    child: DropdownButton<String>(
      isExpanded: isExpanded,
      value: items.hasIndex(selectedValue) ? items[selectedValue] : null,
      hint: Text(
        hint,
        style: Get.textTheme.displaySmall?.copyWith(
          color: Get.theme.primaryColor,
        ),
      ),
      icon: Icon(
        Icons.keyboard_arrow_down_outlined,
        color: isEditable ? Get.theme.primaryColor : Colors.transparent,
      ),
      elevation: 10,
      dropdownColor: Get.theme.dialogBackgroundColor,
      borderRadius: BorderRadius.circular(Dimens.radiusCornerMid),
      underline: Container(height: 0, color: Colors.transparent),
      menuMaxHeight: Get.width,
      onChanged: isEditable ? (value) => onChange(items.indexOf(value!)) : null,
      items: items.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: TextRobotoAutoBold(value, maxLines: 2, fontSize: fontSize),
        );
      }).toList(),
    ),
  );
}

Widget handleNetworkViewWithLoading({double height = 50, String? message}) {
  message = message ?? "No internet".tr;
  return Container(
    height: height,
    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5)),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: Dimens.iconSizeMid36,
            height: Dimens.iconSizeMid36,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ),
          TextRobotoAutoNormal(
            message,
            color: Colors.white,
            fontSize: Dimens.regularFontSizeMid,
            maxLines: 3,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

Widget dropDownListStringBottomSheet(
  BuildContext context,
  List<String> items,
  String selectedValue,
  String hint,
  Function(String value) onChange, {
  double? height,
  double? width,
  double? radius,
}) {
  return InkWell(
    onTap: () async {
      final value = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      TextRobotoAutoBold(hint),
                      const Spacer(),
                      buttonOnlyIcon(
                        iconPath: AssetConstants.icCross,
                        size: Dimens.iconSizeMinExtra,
                        iconColor: context.theme.primaryColor,
                        onPress: () => Get.back(),
                      ),
                    ],
                  ),
                ),
                ...items.map(
                  (item) => ListTile(
                    title: TextRobotoAutoNormal(item),
                    selected: item == selectedValue,
                    onTap: () => Navigator.pop(ctx, item),
                  ),
                ),
              ],
            ),
          );
        },
      );
      if (value != null) onChange(value);
    },
    child: Container(
      height: height ?? Dimens.btnHeightMain,
      width: width,
      decoration: boxDecorationRoundBorder(
        color: Colors.transparent,
        borderColor: Get.theme.dividerColor,
        radius: radius ?? Dimens.radiusCorner,
        width: 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: Dimens.paddingMid),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            selectedValue.isNotEmpty ? selectedValue : hint,
            style: Get.textTheme.displaySmall?.copyWith(
              color: selectedValue.isNotEmpty
                  ? Get.theme.primaryColor
                  : Get.theme.hintColor,
            ),
          ),
          Icon(
            Icons.keyboard_arrow_down_outlined,
            color: Get.theme.primaryColor,
          ),
        ],
      ),
    ),
  );
}

class PopupMenuView extends StatelessWidget {
  const PopupMenuView(this.list, {super.key, this.child, this.onSelected});

  final List<String> list;
  final Widget? child;
  final Function(String)? onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      color: Get.theme.dialogBackgroundColor,
      itemBuilder: (BuildContext context) =>
          List.generate(list.length, (index) {
            return PopupMenuItem<String>(
              value: list[index],
              height: 35,
              child: Text(list[index], style: Get.theme.textTheme.labelMedium),
            );
          }),
      child: child,
    );
  }
}
