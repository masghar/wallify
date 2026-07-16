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
      name: "wallify/platform",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "setWallpaper":
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
          result(FlutterError(code: "bad_args", message: "Missing 'path'", details: nil))
          return
        }
        let url = URL(fileURLWithPath: path)
        // Fill each screen edge-to-edge (scale up/down proportionally and
        // clip the overflow) so the wallpaper never letterboxes or tiles.
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
          .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
          .allowClipping: true,
        ]
        do {
          for screen in NSScreen.screens {
            try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: options)
          }
          result(true)
        } catch {
          result(FlutterError(
            code: "set_failed",
            message: error.localizedDescription,
            details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
