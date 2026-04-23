import 'package:cabinet_checker/utils/common_widgets.dart';
import 'package:cabinet_checker/utils/dimens.dart';
import 'package:cabinet_checker/utils/network_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:get/get_navigation/src/routes/transitions_type.dart';
import 'pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Get.putAsync<NetworkController>(
    () => NetworkController().init(),
    permanent: true,
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]).then((value) => runApp(const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final net = Get.find<NetworkController>();
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      defaultTransition: Transition.rightToLeftWithFade,
      theme: ThemeData(colorSchemeSeed: Colors.white, useMaterial3: true),
      initialRoute: "/",
      builder: (context, child) {
        final scale = MediaQuery.of(
          context,
        ).textScaler.clamp(minScaleFactor: 0.8, maxScaleFactor: 1.3);
        final content = MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: child!,
        );

        // Overlay loading khi offline ở BẤT KỲ màn hình nào
        return Obx(
          () => Stack(
            children: [
              content,
              if (!net.isOnline.value)
                Positioned.fill(
                  child: AbsorbPointer(
                    absorbing: true,
                    child: handleNetworkViewWithLoading(
                      message: "Đang kiểm tra kết nối...".tr,
                      height: Dimens.mainContendGapTop,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      home: HomePage(),
    );
  }
}
