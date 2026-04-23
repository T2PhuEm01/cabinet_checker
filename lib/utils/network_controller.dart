import 'dart:async';
import 'package:cabinet_checker/utils/network_util.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

class NetworkController extends GetxService {
  final RxBool isOnline = true.obs;

  late final StreamSubscription _connSub;
  Timer? _probe;

  Future<NetworkController> init() async {
    // Lắng nghe thay đổi kết nối
    _connSub = Connectivity().onConnectivityChanged.listen((result) async {
      // Nếu mất hoàn toàn -> offline; nếu có kết nối -> xác minh thật sự online bằng ping
      if (result.contains(ConnectivityResult.none)) {
        isOnline.value = false;
      } else {
        isOnline.value = await NetworkCheck.isOnline();
      }
    });

    // Probe định kỳ phòng khi onConnectivityChanged không đủ chính xác
    _probe = Timer.periodic(const Duration(seconds: 5), (_) async {
      final ok = await NetworkCheck.isOnline();
      if (ok != isOnline.value) isOnline.value = ok;
    });

    // Khởi tạo trạng thái ban đầu
    isOnline.value = await NetworkCheck.isOnline();
    return this;
  }

  @override
  void onClose() {
    _probe?.cancel();
    _connSub.cancel();
    super.onClose();
  }
}
