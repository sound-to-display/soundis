import AppKit
import CoreGraphics

/// Shared text drawing for the Canvas2D-style themes (SEISMO, RAIN, INVADERS).
/// The stage view is `isFlipped`, so NSString drawing renders upright and the
/// coordinate system matches the JS canvas (origin top-left, y grows downward).
///
/// `y` is treated as the text *baseline* (like canvas `fillText`), so glyphs sit
/// where the JS code expects them.
func drawText(
    _ text: String,
    x: CGFloat,
    y: CGFloat,
    size: CGFloat,
    color: RGB,
    alpha: CGFloat = 1,
    align: NSTextAlignment = .left,
    bold: Bool = false,
    glow: (color: RGB, blur: CGFloat)? = nil
) {
    let font = NSFont.monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular)
    var attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(red: color.r, green: color.g, blue: color.b, alpha: alpha),
    ]
    if let glow {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(red: glow.color.r, green: glow.color.g, blue: glow.color.b, alpha: alpha)
        shadow.shadowBlurRadius = glow.blur
        shadow.shadowOffset = .zero
        attrs[.shadow] = shadow
    }
    let ns = NSString(string: text)
    var px = x
    if align != .left {
        let w = ns.size(withAttributes: attrs).width
        if align == .center { px -= w / 2 } else if align == .right { px -= w }
    }
    // Convert baseline y → top-left y (draw(at:) anchors the top of the glyphs).
    ns.draw(at: CGPoint(x: px, y: y - font.ascender), withAttributes: attrs)
}
