// Draws the ClipBoardUltra app icon: a slip of thermal paper feeding out of a gunmetal
// printer slot, with a safety-orange key and an amber status light.
//
// Usage: swift scripts/generate_icon.swift <output-dir>
//   writes <output-dir>/AppIcon.iconset/*.png and <output-dir>/Logo.png (1024 px)
import Cocoa

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func roundedRect(_ r: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func linear(_ ctx: CGContext, _ colors: [CGColor], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors as CFArray, locations: nil)!
    ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

/// Renders the icon into a square context of `px` pixels. Geometry is authored on a
/// 1024 canvas with a top-left origin.
func drawIcon(px: Int) -> CGImage {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let k = CGFloat(px) / 1024
    ctx.scaleBy(x: k, y: k)
    ctx.translateBy(x: 0, y: 1024)
    ctx.scaleBy(x: 1, y: -1)          // top-left origin from here on
    ctx.interpolationQuality = .high

    // 1. Tile (macOS grid: 824 pt body inside 1024, soft drop shadow)
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = roundedRect(tile, 186)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 14), blur: 28, color: rgb(0x000000, 0.45))
    ctx.addPath(tilePath); ctx.setFillColor(rgb(0x1E2023)); ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath); ctx.clip()
    linear(ctx, [rgb(0x3A3D42), rgb(0x25282C), rgb(0x16181B)], from: CGPoint(x: 512, y: 100), to: CGPoint(x: 512, y: 924))
    // Fine machined grain
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.018)); ctx.setLineWidth(2)
    for y in stride(from: 110, to: 924, by: 8) {
        ctx.move(to: CGPoint(x: 100, y: CGFloat(y))); ctx.addLine(to: CGPoint(x: 924, y: CGFloat(y)))
    }
    ctx.strokePath()
    ctx.restoreGState()

    // Bevel: bright top edge fading down
    ctx.saveGState()
    ctx.addPath(roundedRect(tile.insetBy(dx: 3, dy: 3), 183))
    ctx.setLineWidth(6)
    ctx.replacePathWithStrokedPath(); ctx.clip()
    linear(ctx, [rgb(0xFFFFFF, 0.22), rgb(0xFFFFFF, 0.03), rgb(0x000000, 0.25)], from: CGPoint(x: 512, y: 100), to: CGPoint(x: 512, y: 924))
    ctx.restoreGState()

    // 2. Slot (back) — the dark mouth the paper feeds from
    let slot = CGRect(x: 170, y: 262, width: 684, height: 84)
    ctx.addPath(roundedRect(slot, 42)); ctx.setFillColor(rgb(0x08090A)); ctx.fillPath()

    // 3. Paper slip with torn zig-zag bottom
    let left: CGFloat = 262, right: CGFloat = 762, top: CGFloat = 304, bottom: CGFloat = 792
    let teeth = 7, depth: CGFloat = 30
    let slip = CGMutablePath()
    slip.move(to: CGPoint(x: left, y: top))
    slip.addLine(to: CGPoint(x: right, y: top))
    slip.addLine(to: CGPoint(x: right, y: bottom))
    let w = (right - left) / CGFloat(teeth)
    for i in 0..<teeth {
        let x0 = right - CGFloat(i) * w
        slip.addLine(to: CGPoint(x: x0 - w / 2, y: bottom + depth))
        slip.addLine(to: CGPoint(x: x0 - w, y: bottom))
    }
    slip.closeSubpath()

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 22), blur: 34, color: rgb(0x000000, 0.55))
    ctx.addPath(slip); ctx.setFillColor(rgb(0xE9ECE7)); ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(slip); ctx.clip()
    linear(ctx, [rgb(0xF4F6F2), rgb(0xE6E9E3), rgb(0xD5D9D2)], from: CGPoint(x: 512, y: top), to: CGPoint(x: 512, y: bottom + depth))
    // Shadow where the paper leaves the slot
    linear(ctx, [rgb(0x000000, 0.35), rgb(0x000000, 0)], from: CGPoint(x: 512, y: top), to: CGPoint(x: 512, y: top + 70))

    // Orange key printed on the slip
    let key = CGRect(x: 318, y: 398, width: 104, height: 104)
    ctx.addPath(roundedRect(key.offsetBy(dx: 0, dy: 8), 24)); ctx.setFillColor(rgb(0xC94B0C)); ctx.fillPath()
    ctx.addPath(roundedRect(key, 24)); ctx.clip()
    linear(ctx, [rgb(0xFF9048), rgb(0xFF6A1A)], from: CGPoint(x: 0, y: key.minY), to: CGPoint(x: 0, y: key.maxY))
    ctx.resetClip()
    ctx.addPath(slip); ctx.clip()

    // Ink lines
    ctx.setFillColor(rgb(0x1C1F23))
    ctx.addPath(roundedRect(CGRect(x: 456, y: 424, width: 250, height: 40), 20)); ctx.fillPath()
    ctx.setFillColor(rgb(0x555A62))
    ctx.addPath(roundedRect(CGRect(x: 456, y: 480, width: 170, height: 22), 11)); ctx.fillPath()
    ctx.addPath(roundedRect(CGRect(x: 318, y: 560, width: 388, height: 26), 13)); ctx.fillPath()
    ctx.addPath(roundedRect(CGRect(x: 318, y: 614, width: 300, height: 26), 13)); ctx.fillPath()

    // Perforation
    ctx.setStrokeColor(rgb(0x9CA19A)); ctx.setLineWidth(6); ctx.setLineDash(phase: 0, lengths: [16, 14])
    ctx.move(to: CGPoint(x: left + 26, y: 704)); ctx.addLine(to: CGPoint(x: right - 26, y: 704)); ctx.strokePath()
    ctx.setLineDash(phase: 0, lengths: [])
    ctx.restoreGState()

    // 4. Front lip of the slot, overlapping the top of the slip
    let lip = CGRect(x: 170, y: 292, width: 684, height: 54)
    ctx.saveGState()
    ctx.addPath(roundedRect(lip, 27)); ctx.clip()
    linear(ctx, [rgb(0x3B3F45), rgb(0x24272B)], from: CGPoint(x: 0, y: lip.minY), to: CGPoint(x: 0, y: lip.maxY))
    ctx.restoreGState()
    ctx.addPath(roundedRect(lip.insetBy(dx: 1.5, dy: 1.5), 25.5))
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.14)); ctx.setLineWidth(3); ctx.strokePath()

    // 5. Amber status light
    let led = CGPoint(x: 792, y: 208)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 26, color: rgb(0xFFB547, 0.9))
    ctx.setFillColor(rgb(0xFFB547))
    ctx.fillEllipse(in: CGRect(x: led.x - 15, y: led.y - 15, width: 30, height: 30))
    ctx.restoreGState()
    ctx.setFillColor(rgb(0xFFF1D6, 0.9))
    ctx.fillEllipse(in: CGRect(x: led.x - 6, y: led.y - 9, width: 10, height: 8))

    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let iconset = outDir.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for pt in [16, 32, 128, 256, 512] {
    writePNG(drawIcon(px: pt), to: iconset.appendingPathComponent("icon_\(pt)x\(pt).png"))
    writePNG(drawIcon(px: pt * 2), to: iconset.appendingPathComponent("icon_\(pt)x\(pt)@2x.png"))
}
writePNG(drawIcon(px: 1024), to: outDir.appendingPathComponent("Logo.png"))
print("Wrote \(iconset.path) and Logo.png")
