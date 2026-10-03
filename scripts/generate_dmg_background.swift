import Cocoa

// Logical points: 680 x 440
// Retina @2x: 1360 x 880
let ptWidth: CGFloat = 680
let ptHeight: CGFloat = 440
let scale: CGFloat = 2.0
let pxWidth = Int(ptWidth * scale)
let pxHeight = Int(ptHeight * scale)

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// ---------------------------------------------------------------------------
// 1. Render high-resolution @2x bitmap (1360 x 880)
// ---------------------------------------------------------------------------
guard let rep2x = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pxWidth,
    pixelsHigh: pxHeight,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .calibratedRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Error: Failed to create NSBitmapImageRep\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
guard let ctx = NSGraphicsContext(bitmapImageRep: rep2x) else {
    fputs("Error: Failed to get NSGraphicsContext\n", stderr)
    exit(1)
}
NSGraphicsContext.current = ctx
let cg = ctx.cgContext

cg.setAllowsAntialiasing(true)
cg.setShouldAntialias(true)
cg.interpolationQuality = .high
cg.scaleBy(x: scale, y: scale)

let colorSpace = CGColorSpaceCreateDeviceRGB()

// Background subtle Apple light gradient: top #FAFBFC -> bottom #EFF2F7
let bgGradientColors = [
    NSColor(calibratedRed: 0.985, green: 0.988, blue: 0.995, alpha: 1.0).cgColor,
    NSColor(calibratedRed: 0.930, green: 0.940, blue: 0.960, alpha: 1.0).cgColor
] as CFArray

if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgGradientColors, locations: [0.0, 1.0]) {
    cg.drawLinearGradient(bgGradient, start: CGPoint(x: 0, y: ptHeight), end: CGPoint(x: 0, y: 0), options: [])
}

// Center ambient glow (soft electric indigo aura)
let glowColors = [
    NSColor(calibratedRed: 0.35, green: 0.45, blue: 0.95, alpha: 0.08).cgColor,
    NSColor(calibratedRed: 0.35, green: 0.45, blue: 0.95, alpha: 0.0).cgColor
] as CFArray
if let glow = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
    cg.drawRadialGradient(
        glow,
        startCenter: CGPoint(x: ptWidth / 2, y: 225),
        startRadius: 0,
        endCenter: CGPoint(x: ptWidth / 2, y: 225),
        endRadius: 260,
        options: [.drawsAfterEndLocation]
    )
}

// Subtle outer window border
let borderRect = CGRect(x: 1, y: 1, width: ptWidth - 2, height: ptHeight - 2)
let borderPath = CGPath(roundedRect: borderRect, cornerWidth: 12, cornerHeight: 12, transform: nil)
cg.saveGState()
cg.setStrokeColor(NSColor.black.withAlphaComponent(0.05).cgColor)
cg.setLineWidth(1)
cg.addPath(borderPath)
cg.strokePath()
cg.restoreGState()

// Clean gradient canvas - icons have native macOS drop shadows

// Center Connection Arrow (y = 225 in Cocoa)
let arrowStartX: CGFloat = 265
let arrowEndX: CGFloat = 415
let centerY: CGFloat = 225

// Arrow shaft and chevron head
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -2), blur: 8, color: NSColor(calibratedRed: 0.25, green: 0.40, blue: 0.95, alpha: 0.30).cgColor)

let arrowPath = CGMutablePath()
arrowPath.move(to: CGPoint(x: arrowStartX, y: centerY))
arrowPath.addLine(to: CGPoint(x: arrowEndX, y: centerY))
arrowPath.addLine(to: CGPoint(x: arrowEndX - 15, y: centerY + 11))
arrowPath.move(to: CGPoint(x: arrowEndX, y: centerY))
arrowPath.addLine(to: CGPoint(x: arrowEndX - 15, y: centerY - 11))

cg.setStrokeColor(NSColor(calibratedRed: 0.22, green: 0.45, blue: 0.98, alpha: 1.0).cgColor)
cg.setLineWidth(3.5)
cg.setLineCap(.round)
cg.setLineJoin(.round)
cg.addPath(arrowPath)
cg.strokePath()
cg.restoreGState()

// "DRAG TO INSTALL" Pill Badge
let pillCenter = (arrowStartX + arrowEndX) / 2
let pillWidth: CGFloat = 126
let pillHeight: CGFloat = 24
let pillRect = CGRect(x: pillCenter - (pillWidth / 2), y: centerY + 24, width: pillWidth, height: pillHeight)
let pillShape = CGPath(roundedRect: pillRect, cornerWidth: 12, cornerHeight: 12, transform: nil)

cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -1), blur: 4, color: NSColor(calibratedRed: 0.20, green: 0.30, blue: 0.80, alpha: 0.12).cgColor)
cg.setFillColor(NSColor(calibratedRed: 0.935, green: 0.955, blue: 1.0, alpha: 1.0).cgColor)
cg.addPath(pillShape)
cg.fillPath()

cg.setStrokeColor(NSColor(calibratedRed: 0.70, green: 0.78, blue: 0.98, alpha: 1.0).cgColor)
cg.setLineWidth(1)
cg.addPath(pillShape)
cg.strokePath()

let pillPara = NSMutableParagraphStyle()
pillPara.alignment = .center
let pillAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 10, weight: .bold),
    .foregroundColor: NSColor(calibratedRed: 0.20, green: 0.35, blue: 0.90, alpha: 1.0),
    .paragraphStyle: pillPara
]
let pillStr = NSAttributedString(string: "DRAG TO INSTALL", attributes: pillAttrs)
pillStr.draw(in: CGRect(x: pillRect.origin.x, y: pillRect.origin.y + 4.5, width: pillWidth, height: 15))
cg.restoreGState()

// Header Typography
let headerPara = NSMutableParagraphStyle()
headerPara.alignment = .center

let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 28, weight: .heavy),
    .foregroundColor: NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.15, alpha: 1.0),
    .paragraphStyle: headerPara
]
let titleStr = NSAttributedString(string: "ClipBoardUltra", attributes: titleAttrs)
titleStr.draw(in: CGRect(x: 0, y: ptHeight - 64, width: ptWidth, height: 34))

let subAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
    .foregroundColor: NSColor(calibratedRed: 0.40, green: 0.45, blue: 0.52, alpha: 1.0),
    .paragraphStyle: headerPara
]
let subStr = NSAttributedString(string: "Supercharged Native Clipboard Manager for macOS", attributes: subAttrs)
subStr.draw(in: CGRect(x: 0, y: ptHeight - 90, width: ptWidth, height: 18))

// Bottom Shortcut Ribbon
let footerRect = CGRect(x: (ptWidth - 360) / 2, y: 65, width: 360, height: 32)
let footerPath = CGPath(roundedRect: footerRect, cornerWidth: 16, cornerHeight: 16, transform: nil)

cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -1), blur: 6, color: NSColor.black.withAlphaComponent(0.04).cgColor)
cg.setFillColor(NSColor.white.withAlphaComponent(0.92).cgColor)
cg.addPath(footerPath)
cg.fillPath()

cg.setStrokeColor(NSColor.black.withAlphaComponent(0.06).cgColor)
cg.setLineWidth(1)
cg.addPath(footerPath)
cg.strokePath()

let footerPara = NSMutableParagraphStyle()
footerPara.alignment = .center

let footerAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
    .foregroundColor: NSColor(calibratedRed: 0.25, green: 0.28, blue: 0.35, alpha: 1.0),
    .paragraphStyle: footerPara
]
let footerStr = NSAttributedString(string: "Press  ⌘ + Shift + V  anywhere to summon", attributes: footerAttrs)
footerStr.draw(in: CGRect(x: footerRect.origin.x, y: footerRect.origin.y + 7, width: footerRect.width, height: 18))
cg.restoreGState()

NSGraphicsContext.restoreGraphicsState()

// ---------------------------------------------------------------------------
// 2. Export 2x PNG (1360 x 880)
// ---------------------------------------------------------------------------
let png2xPath = "\(outDir)/dmg_background@2x.png"
if let pngData2x = rep2x.representation(using: .png, properties: [:]) {
    try? pngData2x.write(to: URL(fileURLWithPath: png2xPath))
    print("Saved @2x PNG: \(png2xPath)")
}

// ---------------------------------------------------------------------------
// 3. Render and export 1x PNG (680 x 440)
// ---------------------------------------------------------------------------
guard let rep1x = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(ptWidth),
    pixelsHigh: Int(ptHeight),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .calibratedRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else { exit(1) }

NSGraphicsContext.saveGraphicsState()
if let ctx1x = NSGraphicsContext(bitmapImageRep: rep1x) {
    NSGraphicsContext.current = ctx1x
    let cg1x = ctx1x.cgContext
    cg1x.interpolationQuality = .high
    if let cgImage2x = rep2x.cgImage {
        cg1x.draw(cgImage2x, in: CGRect(x: 0, y: 0, width: ptWidth, height: ptHeight))
    }
}
NSGraphicsContext.restoreGraphicsState()

let png1xPath = "\(outDir)/dmg_background.png"
if let pngData1x = rep1x.representation(using: .png, properties: [:]) {
    try? pngData1x.write(to: URL(fileURLWithPath: png1xPath))
    print("Saved 1x PNG: \(png1xPath)")
}

// ---------------------------------------------------------------------------
// 4. Also export TIFFs and combine via tiffutil for HiDPI support
// ---------------------------------------------------------------------------
let tiff1xPath = "\(outDir)/dmg_1x.tiff"
let tiff2xPath = "\(outDir)/dmg_2x.tiff"
let tiffHiDPIPath = "\(outDir)/dmg_background.tiff"

if let tiffData1x = rep1x.representation(using: .tiff, properties: [:]) {
    try? tiffData1x.write(to: URL(fileURLWithPath: tiff1xPath))
}
if let tiffData2x = rep2x.representation(using: .tiff, properties: [:]) {
    try? tiffData2x.write(to: URL(fileURLWithPath: tiff2xPath))
}

// Run tiffutil to combine
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/tiffutil")
process.arguments = ["-cathidpicheck", tiff1xPath, tiff2xPath, "-out", tiffHiDPIPath]
try? process.run()
process.waitUntilExit()

if FileManager.default.fileExists(atPath: tiffHiDPIPath) {
    print("Saved HiDPI TIFF: \(tiffHiDPIPath)")
    try? FileManager.default.removeItem(atPath: tiff1xPath)
    try? FileManager.default.removeItem(atPath: tiff2xPath)
}
