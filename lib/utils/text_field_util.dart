import 'package:cabinet_checker/utils/button_util.dart';
import 'package:cabinet_checker/utils/colors.dart';
import 'package:cabinet_checker/utils/constants.dart';
import 'package:cabinet_checker/utils/decorations.dart';
import 'package:cabinet_checker/utils/dimens.dart';
import 'package:cabinet_checker/utils/spacers.dart';
import 'package:cabinet_checker/utils/text_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:cabinet_checker/utils/extentions.dart';

Widget textFieldWithSuffixIcon({
  Widget? countryPick,
  TextEditingController? controller,
  bool readOnly = false,
  String? hint,
  String? text,
  String? labelText,
  TextInputType? type,
  String? iconPath,
  IconData? suffixIconData,
  Widget? suffixIcon,
  Color? suffixColor,
  double? suffixSize,
  Color? colorBorderError,

  VoidCallback? iconAction,
  bool isObscure = false,
  bool isEnable = true,
  bool isFocus = true,
  int maxLines = 1,
  double? width,
  double? height,
  double? borderRadius = 7,
  FocusNode? focusNode,
  EdgeInsets? contentPadding,
  Function(String)? onTextChange,
}) {
  if (controller != null && (controller.text.isEmpty)) {
    if (text != null && text.isNotEmpty) {
      controller.value = controller.value.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
        composing: TextRange.empty,
      );
    }
  }

  // ---- chọn suffix theo ưu tiên: Widget > IconData > iconPath ----
  final Widget? resolvedSuffix =
      suffixIcon ??
      (suffixIconData != null
          ? IconButton(
              padding: const EdgeInsets.all(0),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: Icon(
                suffixIconData,
                size: suffixSize ?? Dimens.iconSizeMid,
                color: suffixColor ?? Get.theme.primaryColorLight,
              ),
              onPressed: iconAction, // có thể null => icon “để nhìn”
            )
          : (iconPath != null
                ? _buildTextFieldIcon(
                    iconPath: iconPath,
                    action: iconAction,
                    color: suffixColor ?? Get.theme.primaryColorLight,
                    size: suffixSize ?? Dimens.iconSizeMid,
                  )
                : null));
  return Container(
    height: height,
    width: width,
    padding: const EdgeInsets.only(left: 0, right: 0, top: 0),
    child: TextField(
      readOnly: readOnly,
      controller: controller,
      focusNode: focusNode,
      keyboardType: type,
      maxLines: maxLines,
      cursorColor: Get.theme.primaryColor,
      obscureText: isObscure,
      enabled: isEnable,
      style: Get.theme.textTheme.bodyLarge,
      onChanged: (value) {
        if (onTextChange != null) onTextChange(value);
      },
      decoration: InputDecoration(
        alignLabelWithHint: true,
        prefixIcon: countryPick,
        labelText: labelText,
        labelStyle: Get.theme.textTheme.displayMedium?.copyWith(
          color: Get.theme.dividerColor,
          fontSize: Dimens.regularFontSizeExtraMid,
        ),
        filled: false,
        isDense: true,
        hintText: hint,
        contentPadding: contentPadding,
        hintStyle: Get.theme.textTheme.displaySmall,
        enabledBorder: _textFieldBorder(borderRadius: borderRadius!),
        disabledBorder: _textFieldBorder(borderRadius: borderRadius),
        focusedBorder: _textFieldBorder(
          isFocus: isFocus,
          borderRadius: borderRadius,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
          borderSide: BorderSide(
            width: 1,
            color: colorBorderError ?? Colors.red,
          ),
        ),
        suffixIcon: resolvedSuffix,
      ),
    ),
  );
}

Widget textFormFieldWithSuffixIcon({
  Widget? countryPick,
  TextEditingController? controller,
  bool readOnly = false,
  String? hint,
  String? text,
  String? labelText,
  TextInputType? type,
  String? iconPath,
  VoidCallback? iconAction,
  bool isObscure = false,
  bool isEnable = true,
  bool isFocus = true,
  int maxLines = 1,
  double? width,
  double? height,
  double? borderRadius = 7,
  FocusNode? focusNode,
  bool filled = false,
  Color? fillColor,
  bool isDense = true,
  EdgeInsets? contentPadding,
  FormFieldValidator<String>? validator, // ✅ Thêm validator
  ValueChanged<String>? onTextChange,
  AutovalidateMode? autovalidateMode, // ✅ THÊM PARAMETER NÀY
}) {
  if (controller != null && (controller.text.isEmpty)) {
    if (text != null && text.isNotEmpty) {
      controller.value = controller.value.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
        composing: TextRange.empty,
      );
    }
  }
  return Container(
    height: height,
    width: width,
    padding: const EdgeInsets.only(left: 0, right: 0, top: 0),
    child: TextFormField(
      readOnly: readOnly,
      controller: controller,
      focusNode: focusNode,
      keyboardType: type,
      maxLines: maxLines,
      cursorColor: Get.theme.primaryColor,
      obscureText: isObscure,
      enabled: isEnable,
      style: Get.theme.textTheme.displaySmall?.copyWith(
        color: Get.theme.primaryColor,
      ),
      validator: validator,
      onChanged: (value) {
        if (onTextChange != null) onTextChange(value);
      },
      autovalidateMode: autovalidateMode ?? AutovalidateMode.disabled,
      decoration: InputDecoration(
        alignLabelWithHint: true,
        prefixIcon: countryPick,
        labelText: labelText,
        labelStyle: Get.theme.textTheme.displaySmall?.copyWith(
          color: Get.theme.primaryColor,
        ),
        filled: filled,
        isDense: isDense,
        hintText: hint,
        contentPadding: contentPadding,
        hintStyle: Get.theme.textTheme.displaySmall,
        enabledBorder: _textFieldBorder(borderRadius: borderRadius!),
        errorBorder: _textFieldBorder(
          borderRadius: borderRadius,
          isFocus: isFocus,
        ),
        disabledBorder: _textFieldBorder(borderRadius: borderRadius),
        focusedBorder: _textFieldBorder(
          isFocus: isFocus,
          borderRadius: borderRadius,
        ),
        focusedErrorBorder: _textFieldBorder(
          isFocus: isFocus,
          borderRadius: borderRadius,
        ),
        suffixIcon: iconPath == null
            ? null
            : _buildTextFieldIcon(
                iconPath: iconPath,
                action: iconAction,
                color: Get.theme.primaryColorLight,
                size: Dimens.iconSizeMid,
              ),
      ),
    ),
  );
}

Widget dropdownFormField<T>({
  required List<T> items,
  required String Function(T) itemLabel, // Hàm trả về text hiển thị
  T? value,
  required String hint,
  String? labelText,
  String? Function(T?)? validator,
  Function(T?)? onChanged,
  double? borderRadius = 7,
  EdgeInsets? contentPadding,
  bool isExpanded = true,
  double? width,
  double? height,
}) {
  return SizedBox(
    height: height,
    width: width,
    child: DropdownButtonFormField<T>(
      value: value,
      isExpanded: isExpanded,
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(
                itemLabel(item),
                style: Get.theme.textTheme.displaySmall?.copyWith(
                  color: Get.theme.primaryColor,
                  fontSize: Dimens.regularFontSizeExtraMid,
                ),
              ),
            ),
          )
          .toList(),
      style: Get.theme.textTheme.displaySmall?.copyWith(
        color: Get.theme.primaryColor,
        fontSize: Dimens.regularFontSizeExtraMid,
      ),
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: Get.theme.textTheme.displaySmall?.copyWith(
          color: Get.theme.primaryColor,
          fontSize: Dimens.regularFontSizeExtraMid,
        ),
        hintText: hint,
        hintStyle: Get.theme.textTheme.displaySmall,
        filled: false,
        isDense: true,
        contentPadding:
            contentPadding ??
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: _textFieldBorder(borderRadius: borderRadius!),
        errorBorder: _textFieldBorder(borderRadius: borderRadius),
        disabledBorder: _textFieldBorder(borderRadius: borderRadius),
        focusedBorder: _textFieldBorder(
          isFocus: true,
          borderRadius: borderRadius,
        ),
        focusedErrorBorder: _textFieldBorder(
          isFocus: true,
          borderRadius: borderRadius,
        ),
      ),
    ),
  );
}

Widget textFieldWithWidget({
  TextEditingController? controller,
  String? hint,
  String? text,
  String? labelText,
  Widget? suffixWidget,
  Widget? prefixWidget,
  TextInputType? type,
  bool isObscure = false,
  bool isEnable = true,
  bool readOnly = false,
  int maxLines = 1,
  double? width,
  double? height,
  double? borderRadius = 10,
  Decoration? decoration,
  EdgeInsets? padding,
  FocusNode? focusNode,
  EdgeInsets? contentPadding,
  TextAlign textAlign = TextAlign.start,
  Function(String)? onTextChange,
}) {
  if (controller != null && text != null && text.isNotEmpty) {
    controller.text = text;
  }
  return Container(
    height: height,
    width: width,
    decoration: decoration,
    child: TextField(
      controller: controller,
      keyboardType: type,
      minLines: 1,
      maxLines: maxLines,
      focusNode: focusNode,
      cursorColor: Get.theme.primaryColor,
      obscureText: isObscure,
      enabled: isEnable,
      readOnly: readOnly,
      textAlign: textAlign,
      style: Get.theme.textTheme.labelLarge,
      onChanged: (value) {
        if (onTextChange != null) onTextChange(value);
      },
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: Get.theme.textTheme.displaySmall?.copyWith(
          color: Get.theme.primaryColor,
          fontSize: Dimens.regularFontSizeExtraMid,
        ),
        hintStyle: Get.theme.textTheme.bodyMedium,
        filled: false,
        isDense: true,
        hintText: hint,
        contentPadding: contentPadding,
        enabledBorder: _textFieldBorder(borderRadius: borderRadius!),
        disabledBorder: _textFieldBorder(borderRadius: borderRadius),
        focusedBorder: _textFieldBorder(
          isFocus: true,
          borderRadius: borderRadius,
        ),
        prefixIcon: prefixWidget,
        suffixIcon: suffixWidget,
      ),
    ),
  );
}

Widget textFieldSearch({
  TextEditingController? controller,
  double? borderRadius = 7,
  Function()? onSearch,
  Function(String)? onTextChange,
  double? height,
  double? width,
  double? margin,
}) {
  height = height ?? 50;
  return Container(
    margin: EdgeInsets.all(margin ?? 10),
    height: height,
    width: width,
    child: TextField(
      controller: controller,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.search,
      cursorColor: Get.theme.primaryColor,
      style: Get.theme.textTheme.displaySmall?.copyWith(
        color: Get.theme.primaryColor,
      ),
      decoration: InputDecoration(
        filled: false,
        isDense: true,
        hintText: "Search".tr,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        enabledBorder: _textFieldBorder(borderRadius: borderRadius!),
        disabledBorder: _textFieldBorder(borderRadius: borderRadius),
        focusedBorder: _textFieldBorder(
          isFocus: true,
          borderRadius: borderRadius,
        ),
        suffixIcon: _buildTextFieldIcon(
          iconPath: AssetConstants.icSearch,
          color: Get.theme.primaryColorLight,
          size: height - 20,
          action: () {
            if (onSearch != null) onSearch();
          },
        ),
      ),
      onSubmitted: (value) {
        if (onSearch != null) onSearch();
      },
      onChanged: (value) {
        if (onTextChange != null) onTextChange(value);
      },
    ),
  );
}

Widget textFieldSearchTackButton({
  TextEditingController? controller,
  double? borderRadius = 7,
  Function()? onSearch,
  Function(String)? onTextChange,
  VoidCallback? onClear,
  bool showClear = false,
  bool showSuffixSearchIcon = true,
  bool submitTriggersSearch = true,
  // NEW
  bool showButton = true,
  IconData? buttonIcon = Icons.search,
  EdgeInsets? buttonPadding,
  double? height,
  double? width,
  double? margin,
}) {
  height = height ?? 50;
  final Radius leftRadius = Radius.circular(borderRadius ?? 7);
  final Radius rightRadius = Radius.circular(borderRadius ?? 7);

  return Container(
    margin: EdgeInsets.all(margin ?? 10),
    height: height,
    width: width,
    child: Row(
      children: [
        // Field bên trái
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.search,
            cursorColor: Get.theme.primaryColor,
            style: Get.theme.textTheme.displaySmall?.copyWith(
              color: Get.theme.primaryColor,
            ),
            decoration: InputDecoration(
              filled: false,
              isDense: true,
              hintText: "Search".tr,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.only(
                  topLeft: leftRadius,
                  bottomLeft: leftRadius,
                  topRight: showButton ? Radius.zero : rightRadius,
                  bottomRight: showButton ? Radius.zero : rightRadius,
                ),
                borderSide: BorderSide(width: 1, color: Get.theme.dividerColor),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.only(
                  topLeft: leftRadius,
                  bottomLeft: leftRadius,
                  topRight: showButton ? Radius.zero : rightRadius,
                  bottomRight: showButton ? Radius.zero : rightRadius,
                ),
                borderSide: BorderSide(width: 1, color: Get.theme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.only(
                  topLeft: leftRadius,
                  bottomLeft: leftRadius,
                  topRight: showButton ? Radius.zero : rightRadius,
                  bottomRight: showButton ? Radius.zero : rightRadius,
                ),
                borderSide: BorderSide(width: 1, color: Get.theme.focusColor),
              ),
              // ONLY show close when có nhập; khi rỗng có thể hiện icon search trong field (tùy showSuffixSearchIcon)
              suffixIcon: showClear && controller != null
                  ? ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        final hasText = value.text.trim().isNotEmpty;
                        if (hasText) {
                          return IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            color: Get.theme.primaryColorLight,
                            onPressed: () {
                              controller.clear();
                              onTextChange?.call('');
                              onClear?.call();
                            },
                          );
                        }
                        return showSuffixSearchIcon
                            ? _buildTextFieldIcon(
                                iconPath: AssetConstants.icSearch,
                                color: Get.theme.primaryColorLight,
                                size: height! - 20,
                                action: () {
                                  if (onSearch != null) onSearch();
                                },
                              )
                            : const SizedBox.shrink();
                      },
                    )
                  : (showSuffixSearchIcon
                        ? _buildTextFieldIcon(
                            iconPath: AssetConstants.icSearch,
                            color: Get.theme.primaryColorLight,
                            size: height - 20,
                            action: () {
                              if (onSearch != null) onSearch();
                            },
                          )
                        : null),
            ),
            onSubmitted: (value) {
              if (submitTriggersSearch && onSearch != null) onSearch();
            },
            onChanged: (value) {
              if (onTextChange != null) onTextChange(value);
            },
          ),
        ),
        // Button bên phải (dính liền)
        if (showButton) ...[
          iconRoundedMain(
            onPress: () {
              if (onSearch != null) onSearch();
            },
            height: height,
            padding:
                buttonPadding ?? const EdgeInsets.symmetric(horizontal: 16),
            bgColor: buttonColor,
            radiusCustom: true,
            borderRadius: borderRadius ?? 7,
            iconData: buttonIcon ?? Icons.search,
            iconColor: Colors.white,
            size: 18,
          ),
        ],
      ],
    ),
  );
}

Widget textFakeFieldSearch({
  double? borderRadius = 7,
  double? height,
  double? width,
  double? margin,
  Color colorBg = Colors.transparent,
  Color? borderColor,
  EdgeInsets? padding,
}) {
  height = height ?? 50;
  return Container(
    height: height,
    width: width,
    padding: padding,
    decoration: boxDecorationRoundBorder(
      color: colorBg,
      radius: borderRadius!,
      borderColor: borderColor,
    ),
    child: Row(
      children: [
        Icon(
          Icons.search,
          color: Get.theme.primaryColorLight,
          size: Dimens.iconSizeMinExtra18,
        ),
        hSpacer3(),
        Expanded(
          child: Text(
            "Search".tr,
            style: Get.theme.textTheme.displaySmall?.copyWith(
              color: Get.theme.primaryColorLight,
            ),
          ),
        ),
        hSpacer10(),
        Icon(
          Icons.camera_alt_outlined,
          color: Get.theme.primaryColorLight,
          size: Dimens.iconSizeMinExtra18,
        ),
      ],
    ),
  );
}

Widget textFieldWithPrefixSuffixText({
  TextEditingController? controller,
  String? text,
  String? hint,
  String? prefixText,
  String? suffixText,
  Color? suffixColor,
  bool isEnable = true,
  TextAlign textAlign = TextAlign.end,
  double? width,
  Function(String)? onTextChange,
}) {
  if (controller != null && text != null) controller.text = text;
  return SizedBox(
    height: 50,
    width: width,
    child: TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      cursorColor: Get.theme.primaryColor,
      enabled: isEnable,
      style: Get.theme.textTheme.displaySmall?.copyWith(
        color: Get.theme.primaryColor,
      ),
      textAlign: textAlign,
      textAlignVertical: TextAlignVertical.center,
      onChanged: (value) {
        if (onTextChange != null) onTextChange(value);
      },
      decoration: InputDecoration(
        prefixIcon: prefixText.isValid
            ? textFieldTextWidget(prefixText!)
            : hSpacer10(),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 10,
          minHeight: 50,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 10,
          minHeight: 50,
        ),
        filled: false,
        isDense: true,
        hintText: hint,
        contentPadding: EdgeInsets.zero,
        enabledBorder: _textFieldBorder(borderRadius: 7),
        disabledBorder: _textFieldBorder(borderRadius: 7),
        focusedBorder: _textFieldBorder(isFocus: true, borderRadius: 7),
        suffixIcon: suffixText.isValid
            ? textFieldTextWidget(
                suffixText!,
                color: suffixColor ?? Get.theme.focusColor,
              )
            : hSpacer10(),
      ),
    ),
  );
}

class TextFieldNoBorder extends StatelessWidget {
  const TextFieldNoBorder({
    super.key,
    this.controller,
    this.hint,
    this.inputType,
    this.onTextChange,
  });

  final TextEditingController? controller;
  final String? hint;
  final bool enabled = true;
  final TextInputType? inputType;
  final Function(String)? onTextChange;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: inputType,
      style: Get.theme.textTheme.displaySmall?.copyWith(
        color: Get.theme.primaryColor,
      ),
      maxLines: 1,
      cursorColor: Get.theme.primaryColor,
      onChanged: onTextChange,
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        filled: false,
        hintText: hint,
        hintStyle: Get.theme.textTheme.displaySmall?.copyWith(
          fontSize: Dimens.regularFontSizeSmall,
        ),
      ),
    );
  }
}

_textFieldBorder({bool isFocus = false, double borderRadius = 5}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
    borderSide: BorderSide(
      width: 1,
      color: isFocus ? Get.theme.focusColor : Get.theme.dividerColor,
    ),
  );
}

Widget _buildTextFieldIcon({
  String? iconPath,
  VoidCallback? action,
  Color? color,
  double? size,
}) {
  return InkWell(
    onTap: action,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: SvgPicture.asset(
        iconPath!,
        colorFilter: color == null
            ? null
            : ColorFilter.mode(color, BlendMode.srcIn),
        height: size,
        width: size,
      ),
    ),
  );
}

textFieldBorder({bool isFocus = false, double borderRadius = 5}) =>
    _textFieldBorder(isFocus: isFocus, borderRadius: borderRadius);

textFieldTextWidget(String text, {Color? color, double? hMargin}) => FittedBox(
  fit: BoxFit.scaleDown,
  alignment: Alignment.centerLeft,
  child: Row(
    children: [
      hMargin == null ? hSpacer10() : SizedBox(width: hMargin),
      Text(
        text,
        style: Get.textTheme.labelMedium?.copyWith(
          color: color ?? Get.theme.primaryColor,
        ),
      ),
      hMargin == null ? hSpacer10() : SizedBox(width: hMargin),
    ],
  ),
);

Widget labeledFieldWithValidation({
  String? label,
  required TextEditingController controller,
  required RxString errorObservable, // ✅ Phải là RxString
  required RxBool showValidation, // ✅ Phải là RxBool
  String? hint,
  bool readOnly = false,
  TextInputType? keyboardType,
  ValueChanged<String>? onChanged,
  Widget? suffixIcon,
  Widget? prefixIcon,
  IconData? suffixIconData,
  VoidCallback? suffixAction,
  Color? suffixColor,
  double? suffixSize,
  bool isObscure = false,
  bool isEnable = true,
  int maxLines = 1,
  double? width,
  double? height,
  double? borderRadius = 7,
  FocusNode? focusNode,
  EdgeInsets? contentPadding,
  EdgeInsets? labelPadding,
  double? labelFontSize,
  Color? labelColor,
  double? errorFontSize,
  Color? errorColor,
}) {
  return Container(
    width: width,
    padding: labelPadding ?? const EdgeInsets.only(bottom: Dimens.paddingMid),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ Label
        if (label != null) ...[
          TextRobotoAutoBold(
            label,
            color: labelColor ?? Colors.black87,
            fontSize: labelFontSize ?? Dimens.regularFontSizeSmall,
          ),
          vSpacer5(),
        ],

        // ✅ Text field with error styling
        Obx(
          () => textFieldWithSuffixIcon(
            controller: controller,
            type: keyboardType,
            hint: hint,
            readOnly: readOnly,
            isObscure: isObscure,
            isEnable: isEnable,
            maxLines: maxLines,
            height: height,
            borderRadius: borderRadius,
            focusNode: focusNode,
            contentPadding: contentPadding,
            countryPick: prefixIcon,
            suffixIcon: suffixIcon,
            suffixIconData: suffixIconData,
            iconAction: suffixAction,
            suffixColor: suffixColor,
            suffixSize: suffixSize,
            onTextChange: onChanged,
            // ✅ Error border styling
            colorBorderError:
                showValidation.value && errorObservable.value.isNotEmpty
                ? (errorColor ?? Colors.red)
                : null,
          ),
        ),

        // ✅ Error message
        Obx(
          () => showValidation.value && errorObservable.value.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: errorColor ?? Colors.red,
                        size: 14,
                      ),
                      hSpacer5(),
                      Expanded(
                        child: TextRobotoAutoNormal(
                          errorObservable.value,
                          color: errorColor ?? Colors.red,
                          fontSize:
                              errorFontSize ?? Dimens.regularFontSizeSmall,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    ),
  );
}
