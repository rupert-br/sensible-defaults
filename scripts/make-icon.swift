// Draws the app icon and writes an .iconset directory. Usage: swift scripts/make-icon.swift <out.iconset>
import AppKit

func render(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(pixels)

    // Rounded tile.
    let tile = NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
    let path = NSBezierPath(roundedRect: tile, xRadius: s * 0.18, yRadius: s * 0.18)
    NSGradient(starting: NSColor(calibratedRed: 0.16, green: 0.20, blue: 0.30, alpha: 1),
               ending: NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.15, alpha: 1))!.draw(in: path, angle: -90)

    // Three menu rows; the top one is the highlighted choice.
    let rowHeight = s * 0.13, gap = s * 0.055
    let left = s * 0.24, width = s * 0.52
    var y = s * 0.5 + rowHeight * 0.5 + gap
    for (index, alpha) in [1.0, 0.35, 0.35].enumerated() {
        let row = NSRect(x: left, y: y, width: index == 2 ? width * 0.7 : width, height: rowHeight)
        let color = index == 0 ? NSColor(calibratedRed: 0.25, green: 0.62, blue: 1.0, alpha: 1) : NSColor.white
        color.withAlphaComponent(alpha).setFill()
        NSBezierPath(roundedRect: row, xRadius: rowHeight * 0.3, yRadius: rowHeight * 0.3).fill()
        y -= rowHeight + gap
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try render(points).write(to: out.appendingPathComponent("icon_\(points)x\(points).png"))
    try render(points * 2).write(to: out.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
