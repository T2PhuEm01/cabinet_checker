import 'package:flutter/material.dart';

const Color darkBG = Color(0xff0F0F0F);
const Color darkBGLight = Color(0xff1A1A1A);
const Color darkSecondaryBG = Colors.black;
const Color darkTextPrimary = Color(0xffF0F0F0);
const Color darkTextSecondary = Color(0xff9D9D9D);
const Color darkDivider = Color(0xff444444);
const Color buttonColor = Color(0xffF65905);
const Color buttonColor1 = Color(0xFF058EF6);
const Color buttonColor2 = Color(0xFF1c92d2);
const Color buttonColor3 = Color(0xFFf2fcfe);
const Color buttonColor4 = Color(0xFF2F80ED);
const Color buttonColor5 = Color(0xFF56CCF2);
const Color colorViettel = Color(0xFFe8002e);

const Color lightBG = Color(0xffF7F7F7);
const Color lightBGDark = Color(0xffF0F0F0);
const Color lightSecondaryBG = Color(0xffFFFFFF);
const Color lightTextPrimary = Color(0xff161616);
const Color lightTextSecondary = Color(0xff515151);
const Color lightDivider = Color(0xffBFBFBF);

// const Color focus = Color(0xffFFC107);
const Color focus = Color(0xfffdc312);
const Color error = Color(0xffF23B44);

int getColorFromHex(String hexColor) {
  hexColor = hexColor.toUpperCase().replaceAll('#', '');
  if (hexColor.length == 6) {
    hexColor = 'FF$hexColor';
  }
  return int.parse(hexColor, radix: 16);
}

const List<Color> bsColorFresh = <Color>[Color(0xFF32d777), Color(0xFFd63031)];
const List<Color> bsColorTradition = <Color>[
  Color(0xFF3498db),
  Color(0xFF9b59b6),
];
const List<Color> bsColorVisionD = <Color>[
  Color(0xFFf39c12),
  Color(0xFFd35400),
];
const List<List<Color>> bsColorList = [
  bsColorFresh,
  bsColorTradition,
  bsColorVisionD,
];
