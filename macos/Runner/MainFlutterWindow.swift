import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "com.rewriter/platform",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "getFrontmostApp":
        if let app = NSWorkspace.shared.frontmostApplication {
          result([
            "bundleId": app.bundleIdentifier ?? "",
            "name": app.localizedName ?? ""
          ])
        } else {
          result([:] as [String: String])
        }

      case "getRunningApps":
        let apps = NSWorkspace.shared.runningApplications
          .filter { $0.activationPolicy == .regular }
          .compactMap { app -> [String: String]? in
            guard let bundleId = app.bundleIdentifier else { return nil }
            return ["bundleId": bundleId, "name": app.localizedName ?? bundleId]
          }
        let unique = Dictionary(apps.map { ($0["bundleId"]!, $0) }, uniquingKeysWith: { first, _ in first })
        let sorted = Array(unique.values).sorted { ($0["name"] ?? "") < ($1["name"] ?? "") }
        result(sorted)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
