import CoreVideo
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
    registerV3Vision(engineBridge.pluginRegistry)
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
      guard let root = registrar.viewController ?? UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene }).flatMap({ $0.windows })
        .first(where: { $0.isKeyWindow })?.rootViewController
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
      mail.setSubject("\(name) - \(category)")
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

import AVFoundation
import CoreImage
import ImageIO
// Version 3 native camera, local cutouts and export. Photo bytes are sent only by the consented Dart request.
import PhotosUI
import Vision
import UserNotifications

private enum V3Media {
  static var folder: URL {
    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("V3Media", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }
  static func normalized(_ image: UIImage, maxEdge: CGFloat = 1200) -> UIImage {
    let factor = min(1, maxEdge / max(image.size.width, image.size.height))
    let size = CGSize(
      width: max(1, image.size.width * factor), height: max(1, image.size.height * factor))
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = false
    return UIGraphicsImageRenderer(size: size, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: size))
    }
  }
  static func quality(_ image: UIImage) -> (Double, Double) {
    guard let cg = image.cgImage else { return (0, 0) }
    let size = 128
    var pixels = [UInt8](repeating: 0, count: size * size)
    guard
      let context = CGContext(
        data: &pixels, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size,
        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
    else { return (0, 0) }
    context.draw(cg, in: CGRect(x: 0, y: 0, width: size, height: size))
    var total = 0.0
    var square = 0.0
    var brightness = 0.0
    var count = 0.0
    for p in pixels { brightness += Double(p) }
    for y in 1..<(size - 1) {
      for x in 1..<(size - 1) {
        let i = y * size + x
        let v = Double(
          Int(pixels[i - 1]) + Int(pixels[i + 1]) + Int(pixels[i - size]) + Int(pixels[i + size])
            - 4 * Int(pixels[i]))
        total += v
        square += v * v
        count += 1
      }
    }
    return (square / count - pow(total / count, 2), brightness / Double(size * size))
  }
  static func save(_ source: UIImage) throws -> [String: Any] {
    let image = normalized(source)
    guard image.size.width >= 256, image.size.height >= 256 else {
      throw NSError(
        domain: "photo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Choose a larger photo."])
    }
    let (sharpness, brightness) = quality(image)
    guard sharpness >= 10, brightness >= 12, brightness <= 249 else {
      throw NSError(
        domain: "photo", code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Use a clearer photo with better lighting."])
    }
    guard let data = image.jpegData(compressionQuality: 0.78), data.count <= 1_800_000 else {
      throw NSError(
        domain: "photo", code: 3, userInfo: [NSLocalizedDescriptionKey: "Use a smaller photo."])
    }
    let name = UUID().uuidString + ".jpg"
    try data.write(to: folder.appendingPathComponent(name), options: .atomic)
    return [
      "file": name, "base64": data.base64EncodedString(), "sharpness": sharpness,
      "width": image.size.width, "height": image.size.height,
    ]
  }
  static func file(_ name: String) -> URL? {
    guard name.range(of: "^[A-Za-z0-9-]+\\.(jpg|png|pdf)$", options: .regularExpression) != nil
    else { return nil }
    return folder.appendingPathComponent(name)
  }
  static func redact(_ name:String) throws -> [String:Any] {
    guard let source=file(name),let image=UIImage(contentsOfFile:source.path),let cg=image.cgImage else {throw NSError(domain:"photo",code:1)}
    let request=VNDetectBarcodesRequest();try VNImageRequestHandler(cgImage:cg,options:[:]).perform([request])
    let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
    let output=UIGraphicsImageRenderer(size:image.size,format:format).image { context in
      image.draw(at:.zero);UIColor.black.setFill()
      for barcode in request.results ?? [] {
        let b=barcode.boundingBox
        let r=CGRect(x:b.minX*image.size.width,y:(1-b.maxY)*image.size.height,width:b.width*image.size.width,height:b.height*image.size.height).insetBy(dx:-6,dy:-6)
        context.cgContext.fill(r)
      }
    }
    return try save(output)
  }
  static func cutout(_ name: String, box: [Double]) throws -> String {
    guard let source = file(name), let image = UIImage(contentsOfFile: source.path)?.cgImage,
      box.count == 4,
      box.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1000 }), box[2] > box[0], box[3] > box[1]
    else {
      throw NSError(
        domain: "cutout", code: 1, userInfo: [NSLocalizedDescriptionKey: "Check the garment crop."])
    }
    let rect = CGRect(
      x: box[1] / 1000 * Double(image.width), y: box[0] / 1000 * Double(image.height),
      width: (box[3] - box[1]) / 1000 * Double(image.width),
      height: (box[2] - box[0]) / 1000 * Double(image.height)
    ).integral
    guard let cropped = image.cropping(to: rect) else { throw NSError(domain: "cutout", code: 2) }
    guard #available(iOS 17.0, *) else {
      throw NSError(
        domain: "cutout", code: 3,
        userInfo: [NSLocalizedDescriptionKey: "Clothing cutouts need iOS 17 or later."])
    }
    func maskedImage(cpuOnly: Bool) throws -> CVPixelBuffer {
      let request = VNGenerateForegroundInstanceMaskRequest()
      request.usesCPUOnly = cpuOnly
      let handler = VNImageRequestHandler(cgImage: cropped, options: [:])
      try handler.perform([request])
      guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
        throw NSError(domain: "cutout", code: 4, userInfo: [NSLocalizedDescriptionKey: "Use a plain background and keep the whole subject visible."])
      }
      return try observation.generateMaskedImage(ofInstances: observation.allInstances, from: handler, croppedToInstancesExtent: true)
    }
    let buffer: CVPixelBuffer
    #if targetEnvironment(simulator)
    buffer = try maskedImage(cpuOnly: true)
    #else
    do { buffer = try maskedImage(cpuOnly: false) }
    catch { buffer = try maskedImage(cpuOnly: true) }
    #endif
    let ci = CIImage(cvPixelBuffer: buffer)
    guard let cg = CIContext().createCGImage(ci, from: ci.extent),
      let data = normalized(UIImage(cgImage: cg), maxEdge: 720).pngData()
    else { throw NSError(domain: "cutout", code: 5) }
    let output = UUID().uuidString + ".png"
    try data.write(to: folder.appendingPathComponent(output), options: .atomic)
    return output
  }
}

private final class V3Picker: NSObject, PHPickerViewControllerDelegate {
  var completion: ((UIImage?, Error?) -> Void)?
  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    guard let item = results.first?.itemProvider else {
      picker.dismiss(animated: true) { self.completion?(nil, nil) }
      return
    }
    item.loadObject(ofClass: UIImage.self) { object, error in
      DispatchQueue.main.async {
        picker.dismiss(animated: true) { self.completion?(object as? UIImage, error) }
      }
    }
  }
}

private final class V3Camera: UIViewController, AVCapturePhotoCaptureDelegate,
  AVCaptureVideoDataOutputSampleBufferDelegate
{
  let session = AVCaptureSession()
  let output = AVCapturePhotoOutput()
  let queue = DispatchQueue(label: "com.boxill.camera")
  var completion: ((UIImage?, Error?) -> Void)?
  var preview: AVCaptureVideoPreviewLayer?
  var device: AVCaptureDevice?
  let message = UILabel()
  let frame = UIView()
  var captureButton = UIButton(type: .system)
  var autoButton = UIButton(type: .system)
  var autoCapture = true
  var stable = 0
  var lastTime = 0.0
  var capturing = false
  var previousBrightness = 0.0
  var previousSharpness = 0.0
  var guide = "Center one item. Use even lighting."
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    message.text = guide
    message.textColor = .white
    message.numberOfLines = 2
    message.textAlignment = .center
    message.font = .systemFont(ofSize: 18, weight: .semibold)
    frame.layer.borderWidth = 3
    frame.layer.cornerRadius = 24
    frame.layer.borderColor = UIColor.white.cgColor
    frame.isUserInteractionEnabled = false
    captureButton.setTitle("Take photo", for: .normal)
    captureButton.titleLabel?.font = .systemFont(ofSize: 19, weight: .bold)
    captureButton.backgroundColor = .white
    captureButton.tintColor = .black
    captureButton.layer.cornerRadius = 28
    captureButton.addTarget(self, action: #selector(capture), for: .touchUpInside)
    autoButton.setTitle("Auto capture: on", for: .normal)
    autoButton.tintColor = .white
    autoButton.addTarget(self, action: #selector(toggleAuto), for: .touchUpInside)
    let cancel = UIButton(type: .system)
    cancel.setTitle("Cancel", for: .normal)
    cancel.tintColor = .white
    cancel.addTarget(self, action: #selector(cancelCapture), for: .touchUpInside)
    for child in [frame, message, captureButton, autoButton, cancel] {
      child.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(child)
    }
    NSLayoutConstraint.activate([
      cancel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
      cancel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      cancel.heightAnchor.constraint(equalToConstant: 48),
      frame.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
      frame.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
      frame.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -25),
      frame.heightAnchor.constraint(equalTo: frame.widthAnchor, multiplier: 1.2),
      message.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      message.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      message.bottomAnchor.constraint(equalTo: frame.topAnchor, constant: -16),
      captureButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
      captureButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
      captureButton.heightAnchor.constraint(equalToConstant: 58),
      captureButton.bottomAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
      autoButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      autoButton.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -12),
      autoButton.heightAnchor.constraint(equalToConstant: 48),
    ])
    let layer = AVCaptureVideoPreviewLayer(session: session)
    layer.videoGravity = .resizeAspectFill
    view.layer.insertSublayer(layer, at: 0)
    preview = layer
    queue.async { self.configure() }
  }
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    preview?.frame = view.bounds
  }
  func configure() {
    session.beginConfiguration()
    session.sessionPreset = .photo
    guard
      let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
      let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input)
    else {
      session.commitConfiguration()
      fail("Camera is unavailable.")
      return
    }
    device = camera
    session.addInput(input)
    guard session.canAddOutput(output) else {
      session.commitConfiguration()
      fail("Camera is unavailable.")
      return
    }
    session.addOutput(output)
    let stream = AVCaptureVideoDataOutput()
    stream.alwaysDiscardsLateVideoFrames = true
    stream.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    stream.setSampleBufferDelegate(self, queue: queue)
    if session.canAddOutput(stream) { session.addOutput(stream) }
    if let connection = stream.connection(with: .video), connection.isVideoOrientationSupported {
      connection.videoOrientation = .portrait
    }
    if let connection = output.connection(with: .video), connection.isVideoOrientationSupported {
      connection.videoOrientation = .portrait
    }
    session.commitConfiguration()
    session.startRunning()
  }
  func captureOutput(
    _ output: AVCaptureOutput, didOutput buffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    let now = Date.timeIntervalSinceReferenceDate
    guard now - lastTime > 0.55, !capturing, let imageBuffer = CMSampleBufferGetImageBuffer(buffer)
    else { return }
    lastTime = now
    let ci = CIImage(cvPixelBuffer: imageBuffer)
    guard let cg = CIContext().createCGImage(ci, from: ci.extent) else { return }
    let (sharpness, brightness) = V3Media.quality(UIImage(cgImage: cg))
    var text = "Hold still"
    var ready = false
    if brightness < 35 {
      text = "Improve the lighting"
      stable = 0
    } else if brightness > 235 {
      text = "Move away from the glare"
      stable = 0
    } else if sharpness < 35 {
      text = "Move closer and focus"
      stable = 0
    } else if device?.isAdjustingFocus == true || abs(brightness - previousBrightness) > 15
      || abs(sharpness - previousSharpness) > max(80, sharpness * 0.7)
    {
      text = "Hold still"
      stable = 0
    } else {
      stable += 1
      ready = stable >= 3
      text = ready ? "Looking clear" : "Hold still"
    }
    previousBrightness = brightness
    previousSharpness = sharpness
    DispatchQueue.main.async {
      self.message.text = text
      self.frame.layer.borderColor = (ready ? UIColor.systemGreen : UIColor.white).cgColor
      if ready && self.autoCapture { self.capture() }
    }
  }
  @objc func toggleAuto() {
    autoCapture.toggle()
    stable = 0
    autoButton.setTitle(autoCapture ? "Auto capture: on" : "Auto capture: off", for: .normal)
  }
  @objc func capture() {
    guard !capturing, session.isRunning else { return }
    capturing = true
    captureButton.isEnabled = false
    queue.async { self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self) }
  }
  func photoOutput(
    _ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?
  ) {
    let image = photo.fileDataRepresentation().flatMap { UIImage(data: $0) }
    queue.async { if self.session.isRunning { self.session.stopRunning() } }
    DispatchQueue.main.async { self.dismiss(animated: true) { self.completion?(image, error) } }
  }
  @objc func cancelCapture() {
    queue.async { if self.session.isRunning { self.session.stopRunning() } }
    dismiss(animated: true) { self.completion?(nil, nil) }
  }
  func fail(_ text: String) {
    DispatchQueue.main.async {
      self.dismiss(animated: true) {
        self.completion?(
          nil, NSError(domain: "camera", code: 1, userInfo: [NSLocalizedDescriptionKey: text]))
      }
    }
  }
}

private var v3PickerKey: UInt8 = 0
extension AppDelegate {
  func registerV3Vision(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "BoxillV3Vision") else { return }
    let channel = FlutterMethodChannel(
      name: "com.boxill/vision", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "reminderPermission":
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in DispatchQueue.main.async { result(granted) } }
      case "clearReminder":
        guard let id = args["id"] as? String else { result(false);return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["v3." + id]);result(true)
      case "setReminder":
        guard let id=args["id"] as? String,let date=args["date"] as? String,let title=args["title"] as? String,let body=args["body"] as? String else {result(false);return}
        let parts=date.split(separator:"-").compactMap { Int($0) }
        guard parts.count==3 else {result(false);return}
        var components=DateComponents();components.year=parts[0];components.month=parts[1];components.day=parts[2];components.hour=9
        guard let at=Calendar.current.date(from:components),at>Date() else { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["v3." + id]);result(false);return }
        let content=UNMutableNotificationContent();content.title=String(title.prefix(120));content.body=String(body.prefix(240));content.sound = .default
        let request=UNNotificationRequest(identifier:"v3."+id,content:content,trigger:UNCalendarNotificationTrigger(dateMatching:components,repeats:false))
        UNUserNotificationCenter.current().add(request) { error in DispatchQueue.main.async {result(error==nil)} }
      case "directory": result(V3Media.folder.path)
      case "processPhoto":
        guard let data = args["base64"] as? String, let bytes = Data(base64Encoded: data),
          bytes.count <= 3_000_000, let image = UIImage(data: bytes)
        else {
          result(FlutterError(code: "image", message: "Invalid image.", details: nil))
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          do {
            let data = try V3Media.save(image)
            DispatchQueue.main.async { result(data) }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(code: "image", message: error.localizedDescription, details: nil))
            }
          }
        }
      case "redactTicket":
        guard let name=args["file"] as? String else {result(FlutterError(code:"photo",message:"Check the ticket photo.",details:nil));return}
        DispatchQueue.global(qos:.userInitiated).async {do {let data=try V3Media.redact(name);DispatchQueue.main.async {result(data)}}catch{DispatchQueue.main.async {result(FlutterError(code:"photo",message:error.localizedDescription,details:nil))}}}
      case "cutout":
        guard let name = args["file"] as? String, let box = args["box"] as? [Double] else {
          result(FlutterError(code: "crop", message: "Check the crop.", details: nil))
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          do {
            let name = try V3Media.cutout(name, box: box)
            DispatchQueue.main.async { result(name) }
          } catch {
            DispatchQueue.main.async {
              result(
                FlutterError(code: "cutout", message: error.localizedDescription, details: nil))
            }
          }
        }
      case "removePhoto":
        guard let name = args["file"] as? String, let url = V3Media.file(name) else {
          result(false)
          return
        }
        do {
          try FileManager.default.removeItem(at: url)
          result(true)
        } catch { result(false) }
      case "transferPhoto":
        guard let name=args["file"] as? String, let url=V3Media.file(name), let image=UIImage(contentsOfFile:url.path) else { result(FlutterError(code:"image",message:"A saved photo is missing.",details:nil));return }
        DispatchQueue.global(qos:.userInitiated).async {
          let normalized=V3Media.normalized(image,maxEdge:640)
          let data=name.hasSuffix(".png") ? normalized.pngData() : normalized.jpegData(compressionQuality:0.75)
          DispatchQueue.main.async {
            guard let data=data,data.count<=3_000_000 else {result(FlutterError(code:"image",message:"Choose a smaller saved photo.",details:nil));return}
            result(data.base64EncodedString())
          }
        }
      case "transferQr":
        guard let text=args["text"] as? String,text.count<=400,let filter=CIFilter(name:"CIQRCodeGenerator") else {result(nil);return}
        filter.setValue(Data(text.utf8),forKey:"inputMessage");filter.setValue("M",forKey:"inputCorrectionLevel")
        guard let output=filter.outputImage,let cg=CIContext().createCGImage(output.transformed(by:CGAffineTransform(scaleX:8,y:8)),from:output.extent.applying(CGAffineTransform(scaleX:8,y:8))) else {result(nil);return}
        let image=UIImage(cgImage:cg),size=CGSize(width:CGFloat(cg.width+64),height:CGFloat(cg.height+64))
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        let rendered=UIGraphicsImageRenderer(size:size,format:format).image {c in UIColor.white.setFill();c.fill(CGRect(origin:.zero,size:size));c.cgContext.interpolationQuality = .none;image.draw(at:CGPoint(x:32,y:32))}
        result(rendered.pngData()?.base64EncodedString())
      case "readTransferQr":
        guard let name=args["file"] as? String,let url=V3Media.file(name),let image=UIImage(contentsOfFile:url.path)?.cgImage else {result(nil);return}
        DispatchQueue.global(qos:.userInitiated).async {
          do { let request=VNDetectBarcodesRequest();request.symbologies=[.qr];try VNImageRequestHandler(cgImage:image,options:[:]).perform([request]);let text=request.results?.first?.payloadStringValue;DispatchQueue.main.async {result(text)} }
          catch {DispatchQueue.main.async {result(FlutterError(code:"qr",message:"Keep the whole share QR in frame and try again.",details:nil))}}
        }
      case "shareTransfer":
        guard let text=args["text"] as? String,text.count<=1800,let presenter=self.v3Presenter(registrar) else {result(false);return}
        var items:[Any]=[text]
        if let encoded=args["qr"] as? String,let bytes=Data(base64Encoded:encoded),bytes.count<=1_000_000,let image=UIImage(data:bytes){items.append(image)}
        let activity=UIActivityViewController(activityItems:items,applicationActivities:nil)
        activity.popoverPresentationController?.sourceView=presenter.view
        activity.completionWithItemsHandler={_,completed,_,_ in result(completed)}
        presenter.present(activity,animated:true)
      case "shareImage":
        guard let encoded = args["base64"] as? String, let data = Data(base64Encoded: encoded),
          data.count <= 10_000_000, let image = UIImage(data: data),
          let presenter = self.v3Presenter(registrar)
        else {
          result(false)
          return
        }
        let activity = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = presenter.view
        activity.completionWithItemsHandler = { _, completed, _, _ in result(completed) }
        presenter.present(activity, animated: true)
      case "capture", "pick":
        guard let presenter = self.v3Presenter(registrar),
          objc_getAssociatedObject(self, &v3PickerKey) == nil
        else {
          result(
            FlutterError(code: "busy", message: "Finish the current photo first.", details: nil))
          return
        }
        let completion: (UIImage?, Error?) -> Void = { image, error in
          objc_setAssociatedObject(self, &v3PickerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
          if let error = error {
            result(FlutterError(code: "photo", message: error.localizedDescription, details: nil))
            return
          }
          guard let image = image else {
            result(nil)
            return
          }
          DispatchQueue.global(qos: .userInitiated).async {
            do {
              let data = try V3Media.save(image)
              DispatchQueue.main.async { result(data) }
            } catch {
              DispatchQueue.main.async {
                result(
                  FlutterError(code: "photo", message: error.localizedDescription, details: nil))
              }
            }
          }
        }
        if call.method == "pick" {
          let delegate = V3Picker()
          delegate.completion = completion
          objc_setAssociatedObject(self, &v3PickerKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
          var configuration = PHPickerConfiguration()
          configuration.filter = .images
          configuration.selectionLimit = 1
          let picker = PHPickerViewController(configuration: configuration)
          picker.delegate = delegate
          presenter.present(picker, animated: true)
        } else {
          objc_setAssociatedObject(self, &v3PickerKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
          guard AVCaptureDevice.default(for: .video) != nil else {
            completion(nil,NSError(domain:"camera",code:2,userInfo:[NSLocalizedDescriptionKey:"Camera is unavailable here. Choose a photo or enter manually."]))
            return
          }
          AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
              if !granted {
                completion(
                  nil,
                  NSError(
                    domain: "camera", code: 1,
                    userInfo: [
                      NSLocalizedDescriptionKey:
                        "Camera access is off. Choose a photo or use manual entry."
                    ]))
                return
              }
              let camera = V3Camera()
              camera.completion = completion
              let guides=["clothing":"Lay one item flat. Fill the frame.","fridge":"Frame your fridge. Keep labels visible.","plant":"Show the leaves. Use even lighting.","meal":"Fill the frame with a clear meal.","knitting":"Keep the pattern or stitches sharp.","furniture":"Show the item and printed sizes.","ticket":"Frame event details. Hide private info.","maintenance":"Frame a receipt or odometer.","goal":"Show your goal and any printed price.","drawing":"Fill the frame with your drawing."]
              camera.guide=guides[args["kind"] as? String ?? ""] ?? camera.guide
              camera.modalPresentationStyle = .fullScreen
              presenter.present(camera, animated: true)
            }
          }
        }
      default: result(FlutterMethodNotImplemented)
      }
    }
  }
  private func v3Presenter(_ registrar:FlutterPluginRegistrar) -> UIViewController? {
    let windows=UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }
    guard var controller=registrar.viewController ?? windows.first(where: { $0.isKeyWindow })?.rootViewController ?? windows.first(where: { $0.rootViewController != nil })?.rootViewController else {return nil}
    while let presented=controller.presentedViewController {controller=presented}
    return controller
  }
}
