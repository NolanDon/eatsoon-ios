import Flutter
import UIKit
import MessageUI
import DeviceCheck
import CryptoKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var feedbackResult: FlutterResult?
  private let speech = AVSpeechSynthesizer()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerFeedbackChannel(engineBridge.pluginRegistry)
    registerCompanionChannel(engineBridge.pluginRegistry)
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

// Secure AI proxy requests: the Gemini key is never present in the application.
extension AppDelegate {
  func registerCompanionChannel(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "BoxillCompanion") else { return }
    let channel = FlutterMethodChannel(name: "com.boxill/companion", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "attestKey":
        let service = DCAppAttestService.shared
        guard service.isSupported else { result(nil); return }
        if let key = UserDefaults.standard.string(forKey: "boxill.appAttest.key") {
          result(key); return
        }
        service.generateKey { key, error in DispatchQueue.main.async {
          if let key = key { UserDefaults.standard.set(key, forKey: "boxill.appAttest.key"); result(key) }
          else { result(FlutterError(code: "attestation", message: error?.localizedDescription, details: nil)) }
        }}
      case "forgetAttestKey":
        UserDefaults.standard.removeObject(forKey: "boxill.appAttest.key")
        result(nil)
      case "attest", "assert":
        guard let key = args["keyId"] as? String, let text = args["data"] as? String,
          text.utf8.count < 3100000 else {
          result(FlutterError(code: "arguments", message: "Invalid attestation data", details: nil)); return
        }
        let hash = Data(SHA256.hash(data: Data(text.utf8)))
        let completion: (Data?, Error?) -> Void = { proof, error in DispatchQueue.main.async {
          if let proof = proof { result(proof.base64EncodedString()) }
          else {
            if let e = error as NSError?, e.code == DCError.invalidKey.rawValue {
              UserDefaults.standard.removeObject(forKey: "boxill.appAttest.key")
            }
            result(FlutterError(code: "attestation", message: error?.localizedDescription, details: nil))
          }
        }}
        if call.method == "attest" { DCAppAttestService.shared.attestKey(key, clientDataHash: hash, completionHandler: completion) }
        else { DCAppAttestService.shared.generateAssertion(key, clientDataHash: hash, completionHandler: completion) }
      default: self.handleCompanionFeature(call, result: result)
      }
    }
  }
}

extension AppDelegate {
  func handleCompanionFeature(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "speak", let args = call.arguments as? [String: String], let text = args["text"], text.count <= 200 {
      speech.stopSpeaking(at: .immediate)
      let utterance = AVSpeechUtterance(string: text)
      utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
      utterance.rate = 0.42
      speech.speak(utterance)
      result(nil)
    } else if call.method == "stopSpeech" {
      speech.stopSpeaking(at: .immediate); result(nil)
    } else { result(FlutterMethodNotImplemented) }
  }
}
