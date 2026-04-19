import 'package:flutter/material.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';

bool gIsDarkMode = false;
bool gIsLandingScreenShowed = false;
String gUserAgent = "";
Color gBuyColor = Colors.green;
Color gBuyNowColor = Color(0xffF65905);
Color gSellColor = Colors.red;
BuildContext? currentContext;
RxBool gIsBalanceHide = false.obs;

class TemporaryData {
  static get selectedCurrencyPair => null;
  static String? activityType;
  static int? changingPageId;
}

enum IdVerificationType { none, nid, passport, driving, voter }

enum PhotoType { front, back, selfie }

class AssetConstants {
  //ICONS
  static const basePathIcons = "assets/icons/";
  static const icSearch = "${basePathIcons}icSearch.svg";
  static const icCross = "${basePathIcons}icCross.svg";
}

class FromKey {
  static const up = "up";
  static const down = "down";
  static const buy = "buy";
  static const sell = "sell";
  static const all = "all";
  static const buySell = "buy_sell";
  static const trade = "trade";
  static const dashboard = "dashboard";
  static const check = "check";
  static const home = "home";
  static const future = "future";
  static const open = "open";
  static const close = "close";
  static const swap = "swap";
}

class HistoryType {
  static const deposit = "deposit";
  static const withdraw = "withdraw";
  static const stopLimit = "stop_limit";
  static const swap = "swap";
  static const buyOrder = "buy_order";
  static const sellOrder = "sell_order";
  static const transaction = "transaction";
  static const fiatDeposit = "fiat_deposit";
  static const fiatWithdrawal = "fiat_withdrawal";
  static const refEarningWithdrawal = "ref_earning_withdrawal";
  static const refEarningTrade = "ref_earning_trade";
}

class PreferenceKey {
  static const isDark = 'is_dark';
  static const languageKey = "language_key";
  static const isOnBoardingDone = 'is_on_boarding_done';
  static const isLoggedIn = "is_logged_in";
  static const accessToken = "accessToken";
  static const userId = "userid";
  static const accessTokenEvm = "evm_access_token";
  static const accessType = "access_type";
  static const settingsObject = "settings_object";
  static const mediaList = "media_list";
  static const buySellColorIndex = "buy_sell_color_index";
  static const buySellUpDown = "buy_sell_up_down";
  static const isBalanceHide = "is_balance_hide";
  static const favoritesSpot = "favorites_spot";
  static const favoritesFuture = "favorites_future";
}

class DefaultValue {
  static const int kPasswordLength = 6;
  static const int codeLength = 6;
  static const String currency = "USD";
  static const String currencySymbol = "\$";
  static const String crispKey = "encrypt";

  static const int listLimitLarge = 20;
  static const int listLimitMedium = 10;
  static const int listLimitShort = 5;
  static const int listLimitOrderBook = 14;

  static const int fiatDecimal = 2;
  static const int cryptoDecimal = 4;

  static const bool showLanding = true;

  static const String randomImage = "https://picsum.photos/200";
  // "https://media.istockphoto.com/photos/high-angle-view-of-a-lake-and-forest-picture-id1337232523"; //"https://picsum.photos/200";
}

class ListConstants {
  static const List<String> percents = ['25', '50', '75', '100'];
  static const List<int> leverages = [
    1,
    5,
    10,
    20,
    30,
    40,
    50,
    60,
    70,
    80,
    90,
    100,
  ];

  static const List<String> coinType = [
    "BTC",
    "LTCT",
    "ETH",
    "LTC",
    "DOGE",
    "BCH",
    "DASH",
    "ETC",
    "USDT",
  ];
  static const kCategoryColorList = [
    Color(0xff1F78FC),
    Color(0xffE30261),
    Color(0xffD200A4),
    Color(0xffFFA800),
  ];
}

class EnvKeyValue {
  static const kStripKey = "stripKey";
  static const kEnvFile = ".env";
  static const kModePaypal = "modePaypal";
  static const kClientIdPaypal = "clientIdPaypal";
  static const kSecretPaypal = "secretPaypal";
  static const kApiSecret = "apiSecret";
}

class IdVerificationStatus {
  static const notSubmitted = "Not Submitted";
  static const pending = "Pending";
  static const accepted = "Approved";
  static const rejected = "Rejected";
}

class UserStatus {
  static const pending = 0;
  static const accepted = 1;
  static const rejected = 2;
  static const suspended = 4;
  static const deleted = 5;
}

class RegistrationType {
  static const facebook = 1;
  static const google = 2;
  static const twitter = 3;
  static const apple = 4;
}

class PaymentMethodType {
  static const paypal = 3;
  static const bank = 4;
  static const card = 5;
  static const wallet = 6;
  static const crypto = 8;
  static const payStack = 9;
}

class FAQType {
  static const main = 1;
  static const deposit = 2;
  static const withdrawn = 3;
  static const buy = 4;
  static const sell = 5;
  static const coin = 6;
  static const wallet = 7;
  static const trade = 8;
}

class StakingInvestmentStatus {
  static const running = 1;
  static const canceled = 2;
  static const unpaid = 3;
  static const paid = 4;
  static const success = 5;
}

class StakingTermsType {
  static const strict = 1;
  static const flexible = 2;
}

class StakingRenewType {
  static const manual = 1;
  static const auto = 2;
}

class GiftCardStatus {
  static const active = 1;
  static const redeemed = 2;
  static const transferred = 3;
  static const trading = 4;
  static const locked = 5;
}

class GiftCardCheckStatus {
  static const redeem = 1;
  static const add = 2;
  static const check = 3;
}

class GiftCardSendType {
  static const email = 1;
  static const phone = 2;
}

class WalletType {
  static const spot = 1;
  static const p2p = 2;
}

class FutureMarketKey {
  static const assets = "assets";
  static const hour = "hour";
  static const new_ = "new";
}

class BlogNewsType {
  static const recent = 1;
  static const popular = 2;
  static const feature = 3;
}

class AppBottomNavKey {
  static const cate = 1;
  static const around = 2;
  static const home = 3;
  static const cart = 4;
  static const dashboard = 5;
}

class SortKey {
  static const pair = 1;
  static const volume = 2;
  static const price = 3;
  static const change = 4;
  static const capital = 5;
}
