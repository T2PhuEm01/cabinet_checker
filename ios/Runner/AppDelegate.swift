import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var exportBackgroundTaskId: UIBackgroundTaskIdentifier = .invalid

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let launchResult = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "cabinet_checker/ios_background_task",
        binaryMessenger: controller.binaryMessenger
      )

      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(false)
          return
        }

        switch call.method {
        case "beginExportTask":
          result(self.beginExportBackgroundTask())
        case "endExportTask":
          self.endExportBackgroundTask()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return launchResult
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func beginExportBackgroundTask() -> Bool {
    if exportBackgroundTaskId != .invalid {
      UIApplication.shared.endBackgroundTask(exportBackgroundTaskId)
      exportBackgroundTaskId = .invalid
    }

    exportBackgroundTaskId = UIApplication.shared.beginBackgroundTask(
      withName: "cabinet_checker_export"
    ) { [weak self] in
      guard let self = self else { return }
      if self.exportBackgroundTaskId != .invalid {
        UIApplication.shared.endBackgroundTask(self.exportBackgroundTaskId)
        self.exportBackgroundTaskId = .invalid
      }
    }

    return exportBackgroundTaskId != .invalid
  }

  private func endExportBackgroundTask() {
    guard exportBackgroundTaskId != .invalid else { return }
    UIApplication.shared.endBackgroundTask(exportBackgroundTaskId)
    exportBackgroundTaskId = .invalid
  }
}
