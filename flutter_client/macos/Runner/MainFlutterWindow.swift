import Cocoa
import CoreImage
import FlutterMacOS
import ImageIO
import UniformTypeIdentifiers
import Vision
import desktop_multi_window

private func configureTransparentFlutterSurface(_ controller: FlutterViewController) {
  // FlutterViewController defaults its render surface to black. This official
  // engine property changes the clear color itself; changing only NSWindow or
  // the outer CALayer leaves the black rectangle visible.
  controller.backgroundColor = .clear
  controller.view.wantsLayer = true
  controller.view.layer?.isOpaque = false
  controller.view.layer?.backgroundColor = NSColor.clear.cgColor

}

private final class PowerEventStreamHandler: NSObject, FlutterStreamHandler {
  private var sink: FlutterEventSink?

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    sink = events
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(willSleep),
      name: NSWorkspace.willSleepNotification,
      object: nil
    )
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(didWake),
      name: NSWorkspace.didWakeNotification,
      object: nil
    )
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NSWorkspace.shared.notificationCenter.removeObserver(self)
    sink = nil
    return nil
  }

  @objc private func willSleep() { sink?("sleep") }
  @objc private func didWake() { sink?("wake") }
}

@available(macOS 14.0, *)
private enum ForegroundRemoval {
  static func makePNG(from data: Data, width: Int, height: Int) throws -> Data {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
      throw NSError(domain: "AssTimer", code: 1, userInfo: [
        NSLocalizedDescriptionKey: "无法读取图片"
      ])
    }
    let request = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    try handler.perform([request])
    guard let observation = request.results?.first,
          !observation.allInstances.isEmpty else {
      throw NSError(domain: "AssTimer", code: 2, userInfo: [
        NSLocalizedDescriptionKey: "没有识别到清晰的前景主体"
      ])
    }
    let pixelBuffer = try observation.generateMaskedImage(
      ofInstances: observation.allInstances,
      from: handler,
      croppedToInstancesExtent: true
    )
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let ciContext = CIContext(options: [.cacheIntermediates: false])
    guard let foreground = ciContext.createCGImage(ciImage, from: ciImage.extent),
          let context = bitmapContext(width: width, height: height) else {
      throw NSError(domain: "AssTimer", code: 3, userInfo: [
        NSLocalizedDescriptionKey: "图片处理失败"
      ])
    }
    let padding = CGFloat(min(width, height)) * 0.065
    let scale = min(
      (CGFloat(width) - padding * 2) / CGFloat(foreground.width),
      (CGFloat(height) - padding * 2) / CGFloat(foreground.height)
    )
    let drawWidth = CGFloat(foreground.width) * scale
    let drawHeight = CGFloat(foreground.height) * scale
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    context.interpolationQuality = .high
    context.draw(
      foreground,
      in: CGRect(
        x: (CGFloat(width) - drawWidth) / 2,
        y: (CGFloat(height) - drawHeight) / 2,
        width: drawWidth,
        height: drawHeight
      )
    )
    guard let output = context.makeImage() else {
      throw NSError(domain: "AssTimer", code: 4)
    }
    let result = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
      result,
      UTType.png.identifier as CFString,
      1,
      nil
    ) else {
      throw NSError(domain: "AssTimer", code: 5)
    }
    CGImageDestinationAddImage(destination, output, nil)
    guard CGImageDestinationFinalize(destination) else {
      throw NSError(domain: "AssTimer", code: 6)
    }
    return result as Data
  }

  private static func bitmapContext(width: Int, height: Int) -> CGContext? {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
      ?? CGColorSpaceCreateDeviceRGB()
    return CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
  }
}

class MainFlutterWindow: NSWindow {
  private let powerEvents = PowerEventStreamHandler()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    configureTransparentFlutterSurface(flutterViewController)
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.isOpaque = false
    self.backgroundColor = .clear
    self.hasShadow = false

    RegisterGeneratedPlugins(registry: flutterViewController)
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      configureTransparentFlutterSurface(controller)
      RegisterGeneratedPlugins(registry: controller)
    }

    let messenger = flutterViewController.engine.binaryMessenger
    FlutterMethodChannel(
      name: "ass_timer/legacy_migration",
      binaryMessenger: messenger
    ).setMethodCallHandler { call, result in
      switch call.method {
      case "readLegacyState":
        let defaults = UserDefaults.standard
        var payload: [String: Any] = [:]
        if let data = defaults.data(forKey: "ass_timer_user_config") {
          payload["configData"] = FlutterStandardTypedData(bytes: data)
        }
        let nextReminder = defaults.double(forKey: "ass_timer_next_reminder_ts")
        if nextReminder > 0 {
          payload["nextReminderTimestamp"] = nextReminder
        }
        result(payload)
      case "removeBackground":
        guard #available(macOS 14.0, *) else {
          result(FlutterError(
            code: "UNAVAILABLE",
            message: "去除背景需要 macOS 14 或更高版本",
            details: nil
          ))
          return
        }
        guard let arguments = call.arguments as? [String: Any],
              let typedData = arguments["data"] as? FlutterStandardTypedData else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: nil, details: nil))
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          do {
            let png = try ForegroundRemoval.makePNG(
              from: typedData.data,
              width: arguments["width"] as? Int ?? 216,
              height: arguments["height"] as? Int ?? 288
            )
            DispatchQueue.main.async {
              result(FlutterStandardTypedData(bytes: png))
            }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(
                code: "PROCESSING_FAILED",
                message: error.localizedDescription,
                details: nil
              ))
            }
          }
        }
      case "supportsBackgroundRemoval":
        if #available(macOS 14.0, *) {
          result(true)
        } else {
          result(false)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    FlutterMethodChannel(
      name: "ass_timer/desktop_host",
      binaryMessenger: messenger
    ).setMethodCallHandler { call, result in
      switch call.method {
      case "setActivationPolicy":
        let policy = call.arguments as? String
        NSApp.setActivationPolicy(policy == "regular" ? .regular : .accessory)
        if policy == "regular" {
          NSApp.activate(ignoringOtherApps: true)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    FlutterEventChannel(
      name: "ass_timer/power_events",
      binaryMessenger: messenger
    ).setStreamHandler(powerEvents)

    super.awakeFromNib()
  }
}
