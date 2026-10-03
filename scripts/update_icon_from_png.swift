import Cocoa

let srcPath = "Resources/Glassy Blue Clipboard Notes Icon.png"
guard let srcImage = NSImage(contentsOfFile: srcPath) else {
    fputs("Error: Could not load \(srcPath)\n", stderr)
    exit(1)
}

let iconsetDir = "build/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconsetDir)
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, px) in sizes {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: px,
        pixelsHigh: px,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext
    cg.interpolationQuality = .high
    
    // Draw centered with aspect ratio fit
    let srcSize = srcImage.size
    let maxDim = max(srcSize.width, srcSize.height)
    let drawW = (srcSize.width / maxDim) * CGFloat(px)
    let drawH = (srcSize.height / maxDim) * CGFloat(px)
    let drawX = (CGFloat(px) - drawW) / 2
    let drawY = (CGFloat(px) - drawH) / 2
    
    srcImage.draw(in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH),
                  from: .zero,
                  operation: .sourceOver,
                  fraction: 1.0)
    
    NSGraphicsContext.restoreGraphicsState()
    
    if let data = rep.representation(using: .png, properties: [:]) {
        let fileUrl = URL(fileURLWithPath: "\(iconsetDir)/\(name)")
        try? data.write(to: fileUrl)
    }
}

// Save 1024x1024 Logo.png
let logoRep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: 1024,
    pixelsHigh: 1024,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .calibratedRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
let logoCtx = NSGraphicsContext(bitmapImageRep: logoRep)!
NSGraphicsContext.current = logoCtx
logoCtx.cgContext.interpolationQuality = .high
srcImage.draw(in: CGRect(x: 0, y: 0, width: 1024, height: 1024), from: .zero, operation: .sourceOver, fraction: 1.0)
NSGraphicsContext.restoreGraphicsState()

if let data = logoRep.representation(using: .png, properties: [:]) {
    try? data.write(to: URL(fileURLWithPath: "Resources/Logo.png"))
    try? data.write(to: URL(fileURLWithPath: "docs/assets/logo.png"))
    print("Saved Resources/Logo.png and docs/assets/logo.png")
}

// Convert to icns
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconsetDir, "-o", "Resources/AppIcon.icns"]
try? p.run()
p.waitUntilExit()

if FileManager.default.fileExists(atPath: "Resources/AppIcon.icns") {
    print("Successfully generated Resources/AppIcon.icns")
} else {
    fputs("Error: Failed to generate AppIcon.icns\n", stderr)
    exit(1)
}
