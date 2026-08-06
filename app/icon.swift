// icon.swift — рисует значок приложения: красная кнопка под стеклом.
// Свой рисунок, без чужих картинок — ничьи права не задеты.
import Cocoa

func drawIcon(_ size: CGFloat) -> NSImage {
  let img = NSImage(size: NSSize(width: size, height: size))
  img.lockFocus()
  let ctx = NSGraphicsContext.current!.cgContext
  let s = size

  // корпус
  let body = CGRect(x: s * 0.06, y: s * 0.06, width: s * 0.88, height: s * 0.88)
  let path = CGPath(roundedRect: body, cornerWidth: s * 0.22, cornerHeight: s * 0.22, transform: nil)
  ctx.addPath(path)
  let cs = CGColorSpaceCreateDeviceRGB()
  let bodyGrad = CGGradient(colorsSpace: cs, colors: [
    CGColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 1),
    CGColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1)
  ] as CFArray, locations: [0, 1])!
  ctx.saveGState(); ctx.clip()
  ctx.drawLinearGradient(bodyGrad, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])
  ctx.restoreGState()

  // юбка кнопки
  ctx.setFillColor(CGColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1))
  ctx.fillEllipse(in: CGRect(x: s * 0.18, y: s * 0.2, width: s * 0.64, height: s * 0.5))

  // сама кнопка
  let btn = CGRect(x: s * 0.24, y: s * 0.3, width: s * 0.52, height: s * 0.44)
  let redGrad = CGGradient(colorsSpace: cs, colors: [
    CGColor(red: 0.94, green: 0.34, blue: 0.26, alpha: 1),
    CGColor(red: 0.62, green: 0.10, blue: 0.09, alpha: 1)
  ] as CFArray, locations: [0, 1])!
  ctx.saveGState()
  ctx.addEllipse(in: btn); ctx.clip()
  ctx.drawLinearGradient(redGrad, start: CGPoint(x: 0, y: btn.maxY), end: CGPoint(x: 0, y: btn.minY), options: [])
  ctx.restoreGState()

  // блик
  ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.32))
  ctx.fillEllipse(in: CGRect(x: s * 0.32, y: s * 0.56, width: s * 0.22, height: s * 0.11))

  // тень под кнопкой
  ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.35))
  ctx.fillEllipse(in: CGRect(x: s * 0.26, y: s * 0.26, width: s * 0.48, height: s * 0.1))

  img.unlockFocus()
  return img
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
for px in [16, 32, 64, 128, 256, 512, 1024] {
  let img = drawIcon(CGFloat(px))
  guard let tiff = img.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let png = rep.representation(using: .png, properties: [:]) else { continue }
  let scale = px >= 64 ? 2 : 1
  let base = px / scale
  let name = scale == 2 ? "icon_\(base)x\(base)@2x.png" : "icon_\(base)x\(base).png"
  try? png.write(to: URL(fileURLWithPath: out).appendingPathComponent(name))
}
print("иконки готовы")
