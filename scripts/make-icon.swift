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

    // The </> glyph: white chevrons with an accent-coloured slash.
    func stroke(_ points: [(CGFloat, CGFloat)], _ color: NSColor) {
        let line = NSBezierPath()
        line.move(to: NSPoint(x: points[0].0 * s, y: points[0].1 * s))
        points.dropFirst().forEach { line.line(to: NSPoint(x: $0.0 * s, y: $0.1 * s)) }
        line.lineWidth = s * 0.06
        line.lineCapStyle = .round
        line.lineJoinStyle = .round
        color.setStroke()
        line.stroke()
    }
    stroke([(0.39, 0.64), (0.25, 0.50), (0.39, 0.36)], .white)
    stroke([(0.61, 0.64), (0.75, 0.50), (0.61, 0.36)], .white)
    stroke([(0.555, 0.69), (0.445, 0.31)], NSColor(calibratedRed: 0.25, green: 0.62, blue: 1.0, alpha: 1))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try render(points).write(to: out.appendingPathComponent("icon_\(points)x\(points).png"))
    try render(points * 2).write(to: out.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
