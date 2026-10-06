import Flutter
import UIKit
import MessageUI

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var feedbackResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerFeedbackChannel(engineBridge.pluginRegistry)
  }
}

// Uses the user's Mail account. No email-service secrets are stored in the app.
extension AppDelegate: MFMailComposeViewControllerDelegate {
  func registerFeedbackChannel(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "BoxillFeedback") else { return }
    let channel = FlutterMethodChannel(name: "com.boxill/feedback", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "sendFeedback" else { result(FlutterMethodNotImplemented); return }
      guard let self = self else { result("failed"); return }
      guard self.feedbackResult == nil else { result("failed"); return }
      guard let args = call.arguments as? [String: String],
        let message = args["message"], let category = args["category"],
        message.trimmingCharacters(in: .whitespacesAndNewlines).utf16.count >= 10,
        message.utf16.count <= 4000,
        ["General feedback", "Report a problem", "Feature idea", "Question"].contains(category)
      else { result("failed"); return }
      guard MFMailComposeViewController.canSendMail() else { result("unavailable"); return }
      guard let scene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
        let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
      else { result("failed"); return }
      var presenter = root
      while let presented = presenter.presentedViewController { presenter = presented }
      guard !presenter.isBeingDismissed, !presenter.isBeingPresented else { result("failed"); return }
      let info = Bundle.main.infoDictionary ?? [:]
      let name = info["CFBundleDisplayName"] as? String ?? "App"
      let version = info["CFBundleShortVersionString"] as? String ?? ""
      let build = info["CFBundleVersion"] as? String ?? ""
      let mail = MFMailComposeViewController()
      mail.mailComposeDelegate = self
      mail.setToRecipients(["support@boxillapps.com"])
      mail.setSubject("\(name) — \(category)")
      mail.setMessageBody("\(message)\n\n---\n\(name) \(version) (\(build))", isHTML: false)
      self.feedbackResult = result
      presenter.present(mail, animated: true)
    }
  }

  func mailComposeController(_ controller: MFMailComposeViewController,
    didFinishWith result: MFMailComposeResult, error: Error?) {
    let callback = feedbackResult
    feedbackResult = nil
    let outcome: String
    if error != nil { outcome = "failed" }
    else {
      switch result {
      case .sent: outcome = "sent"
      case .saved: outcome = "saved"
      case .cancelled: outcome = "cancelled"
      case .failed: outcome = "failed"
      @unknown default: outcome = "failed"
      }
    }
    controller.dismiss(animated: true) { callback?(outcome) }
  }
}
