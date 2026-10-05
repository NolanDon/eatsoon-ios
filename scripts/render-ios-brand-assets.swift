// Run from the app directory: swift scripts/render-ios-brand-assets.swift
// App icons stay square and opaque; splash PNGs have rounded transparent corners.
import AppKit
import Foundation
import ImageIO

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1
  ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent("assets/branding/app-icon-source.png")
let catalog = root.appendingPathComponent("ios/Runner/Assets.xcassets")
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil)!
let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
let width = image.width, height = image.height
precondition(width == height, "The source must have a square canvas")
let buffer = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
  bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo)!
buffer.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
let pixels = buffer.data!.assumingMemoryBound(to: UInt8.self)
func rgb(_ x: Int, _ y: Int) -> [Double] {
  let offset = (y * width + x) * 4
  return (0..<3).map { Double(pixels[offset + $0]) }
}
let samples = [rgb(width / 2, height / 16), rgb(width / 2, height * 15 / 16),
  rgb(width / 16, height / 2), rgb(width * 15 / 16, height / 2)]
let background = (0..<3).map { channel in samples.map { $0[channel] }.sorted()[1] }
// Extend a baked outer matte into the intended color, including antialiased
// edges. Only corner-connected matte pixels are changed; artwork is preserved.
let corners = [0, width - 1, (height - 1) * width, width * height - 1]
var changed = 0
for corner in corners {
  let outside = (0..<3).map { Double(pixels[corner * 4 + $0]) }
  let direction = (0..<3).map { outside[$0] - background[$0] }
  let norm = direction.reduce(0) { $0 + $1 * $1 }
  if norm < 300 { continue }
  var visited = [Bool](repeating: false, count: width * height)
  var queue = [corner], cursor = 0
  visited[corner] = true
  while cursor < queue.count {
    let index = queue[cursor]; cursor += 1
    let offset = index * 4
    let delta = (0..<3).map { Double(pixels[offset + $0]) - background[$0] }
    let blend = zip(delta, direction).reduce(0) { $0 + $1.0 * $1.1 } / norm
    let residual = (0..<3).map { abs(delta[$0] - direction[$0] * blend) }.max()!
    guard blend > 0.015 && blend < 1.5 && residual < 10 else { continue }
    for channel in 0..<3 { pixels[offset + channel] = UInt8(background[channel].rounded()) }
    pixels[offset + 3] = 255
    changed += 1
    let x = index % width, y = index / width
    let neighbors = [x > 0 ? index - 1 : -1, x + 1 < width ? index + 1 : -1,
      y > 0 ? index - width : -1, y + 1 < height ? index + width : -1]
    for next in neighbors where next >= 0 && !visited[next] {
      visited[next] = true; queue.append(next)
    }
  }
}
let square = buffer.makeImage()!
func writePNG(_ size: Int, to url: URL, roundedSplash: Bool = false) throws {
  let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
    bytesPerRow: size * 4, space: colorSpace, bitmapInfo: bitmapInfo)!
  if roundedSplash {
    let radius = CGFloat(size) * 40 / 180
    let mask = CGPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size),
      cornerWidth: radius, cornerHeight: radius, transform: nil)
    context.addPath(mask)
    context.clip()
  }
  context.setFillColor(CGColor(colorSpace: colorSpace, components: background.map { $0 / 255 } + [1])!)
  context.fill(CGRect(x: 0, y: 0, width: size, height: size))
  context.interpolationQuality = .high
  context.draw(square, in: CGRect(x: 0, y: 0, width: size, height: size))
  if roundedSplash {
    // ImageIO preserves alpha outside the mask; the launch storyboard stays static.
    let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    guard CGImageDestinationFinalize(destination) else {
      throw NSError(domain: "BrandAssets", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Could not write splash PNG"])
    }
    return
  }
  // Encode RGB, with no alpha channel, for App Store app-icon requirements.
  let input = context.data!.assumingMemoryBound(to: UInt8.self)
  let output = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: size * 3, bitsPerPixel: 24)!
  let data = output.bitmapData!
  for index in 0..<(size * size) {
    for channel in 0..<3 { data[index * 3 + channel] = input[index * 4 + channel] }
  }
  try output.representation(using: .png, properties: [:])!.write(to: url)
}
// Persist the cleaned master too, so its corners contain the actual background.
try writePNG(width, to: sourceURL)
let iconDir = catalog.appendingPathComponent("AppIcon.appiconset")
let contents = try JSONSerialization.jsonObject(with: Data(contentsOf: iconDir.appendingPathComponent("Contents.json"))) as! [String: Any]
for item in contents["images"] as! [[String: Any]] {
  guard let filename = item["filename"] as? String, let points = item["size"] as? String,
    let scale = item["scale"] as? String else { continue }
  let size = Int((Double(points.components(separatedBy: "x")[0])! * Double(scale.dropLast())!).rounded())
  try writePNG(size, to: iconDir.appendingPathComponent(filename))
}
let launchDir = catalog.appendingPathComponent("LaunchMark.imageset")
try FileManager.default.createDirectory(at: launchDir, withIntermediateDirectories: true)
var launchImages = [[String: String]]()
for scale in 1...3 {
  let filename = "LaunchMark@\(scale)x.png"
  try writePNG(180 * scale, to: launchDir.appendingPathComponent(filename), roundedSplash: true)
  launchImages.append(["filename": filename, "idiom": "universal", "scale": "\(scale)x"])
}
let launchContents: [String: Any] = ["images": launchImages, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: launchContents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: launchDir.appendingPathComponent("Contents.json"))
print("\(root.lastPathComponent): opaque edge-to-edge icons; 180pt rounded splash PNG (40pt radius); \(changed) outer matte pixels extended")
