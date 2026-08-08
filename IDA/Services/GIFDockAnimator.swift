import Foundation
import AppKit
import ImageIO

final class GIFDockAnimator {

    static let shared = GIFDockAnimator()

    public private(set) var isRunning: Bool = false
    public var frameCount: Int { styledFrames.count }

    private var timer: Timer?
    private var rawFrames: [NSImage] = []                
    private var styledFrames: [NSImage] = []             
    private var frameDurationsSec: [TimeInterval] = []   
    private var currentIdx: Int = 0
    private var fallbackBaseIcon: NSImage?

    private init() {
        
    }

    func start() {
        guard !isRunning else { return }

        if styledFrames.isEmpty {
            loadAndPrepareFrames()
        }
        guard !styledFrames.isEmpty else { return }

        if fallbackBaseIcon == nil {
            fallbackBaseIcon = NSApp.applicationIconImage ?? NSImage(named: "IDAAppIcon")
        }

        isRunning = true
        currentIdx = 0
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.showCurrentFrame()
            self.scheduleNext()
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.resumeIfPaused()
        }
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        NotificationCenter.default.removeObserver(self, name: NSApplication.didBecomeActiveNotification, object: nil)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let base = self.fallbackBaseIcon {
                NSApp.applicationIconImage = base
            } else {
                NSApp.applicationIconImage = NSImage(named: "IDAAppIcon")
            }
        }
    }

    private func loadAndPrepareFrames() {
        
        if let dir = resolveFramesDirectory() {
            loadFramesFromDirectory(dir)
        }
        
        if rawFrames.isEmpty {
            loadFramesFromGIFDirectly()
        }
        
        if rawFrames.isEmpty {
            rawFrames = buildPlaceholderFrames(count: 4, side: 1024)
            frameDurationsSec = [TimeInterval](repeating: 0.16, count: rawFrames.count)
        }

        if frameDurationsSec.count != rawFrames.count {
            frameDurationsSec = [TimeInterval](
                repeating: max(0.10, frameDurationsSec.first ?? 0.12),
                count: rawFrames.count
            )
        }

        styledFrames = rawFrames.compactMap { img -> NSImage? in
            let whiteBG = img.withWhiteBackground()
            let shrink = whiteBG.resized(maxEdge: 1024)
            return shrink.asMacOSAppIcon() ?? shrink
        }
        if styledFrames.isEmpty {
            styledFrames = rawFrames
        }
    }

    private func resolveFramesDirectory() -> URL? {
        let fm = FileManager.default

        let inBundleMain = Bundle.main.resourceURL?.appendingPathComponent("GIFAppIconFrames", isDirectory: true)
        let inBundleContents = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/GIFAppIconFrames", isDirectory: true)
        
        let devPaths: [URL?] = [
            Bundle.main.resourceURL?.deletingLastPathComponent()
                .appendingPathComponent("Resources/GIFAppIconFrames", isDirectory: true),
            URL(fileURLWithPath: "/Users/pxx917144686/Desktop/Mac应用/surge_副本/IDA/IDA/Resources/GIFAppIconFrames", isDirectory: true),
        ]

        for candidate in ([inBundleMain, inBundleContents] + devPaths).compactMap({ $0 }) {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: candidate.path, isDirectory: &isDir),
               isDir.boolValue,
               fm.fileExists(atPath: candidate.appendingPathComponent("frame_0000.png").path) {
                return candidate
            }
        }
        return nil
    }

    private func loadFramesFromDirectory(_ dir: URL) {
        let fm = FileManager.default

        let durUrl = dir.appendingPathComponent("durations.json")
        if let data = try? Data(contentsOf: durUrl),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [Int] {
            frameDurationsSec = arr.map { TimeInterval($0) / 1000.0 }
        }

        do {
            let files = try fm.contentsOfDirectory(atPath: dir.path)
                .filter { $0.starts(with: "frame_") && $0.hasSuffix(".png") }
                .sorted()   
            var imgs: [NSImage] = []
            for f in files {
                let url = dir.appendingPathComponent(f)
                if let img = NSImage(contentsOf: url) {
                    imgs.append(img)
                }
            }
            rawFrames = imgs
        } catch {
            rawFrames = []
        }
    }

    private func loadFramesFromGIFDirectly() {
        let candidates: [URL] = [
            Bundle.main.url(forResource: "XXOO", withExtension: "GIF"),
            Bundle.main.url(forResource: "XXOO", withExtension: "gif"),
            Bundle.main.resourceURL?.appendingPathComponent("XXOO.GIF"),
            Bundle.main.resourceURL?.appendingPathComponent("XXOO.gif"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/XXOO.GIF"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/XXOO.gif"),
        ].compactMap { $0 }

        for url in candidates {
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { continue }
            let n = CGImageSourceGetCount(src)
            guard n > 0 else { continue }
            var imgs: [NSImage] = []
            var durs: [TimeInterval] = []
            for i in 0..<n {
                guard let cg = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
                let square = squarePadded(cg, side: 1024)
                imgs.append(square)
                var d: TimeInterval = 0.12
                if let props = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [CFString: Any],
                   let gifDict = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
                    if let v = gifDict[kCGImagePropertyGIFUnclampedDelayTime] as? Double, v > 0 { d = v }
                    else if let v = gifDict[kCGImagePropertyGIFDelayTime] as? Double, v > 0 { d = v }
                }
                durs.append(d)
            }
            if imgs.isEmpty { continue }
            rawFrames = imgs
            frameDurationsSec = durs
            return
        }
    }

    private func scheduleNext() {
        guard isRunning else { return }
        guard !styledFrames.isEmpty else { return }
        let idx = min(currentIdx, frameDurationsSec.count - 1)
        let dur = (idx >= 0 && idx < frameDurationsSec.count) ? frameDurationsSec[idx] : 0.12
        let clamped = max(0.06, min(0.4, dur))

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: clamped, repeats: false) { [weak self] _ in
            self?.tick()
        }
        
        if let t = timer {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    private func tick() {
        guard isRunning, !styledFrames.isEmpty else { return }
        currentIdx = (currentIdx + 1) % styledFrames.count
        showCurrentFrame()
        scheduleNext()
    }

    private func showCurrentFrame() {
        guard styledFrames.indices.contains(currentIdx) else { return }
        NSApp.applicationIconImage = styledFrames[currentIdx]
    }

    private func resumeIfPaused() {
        guard isRunning else { return }
        if timer == nil {
            showCurrentFrame()
            scheduleNext()
        }
    }

    private func squarePadded(_ cg: CGImage, side: CGFloat) -> NSImage {
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let ratio = min(side / w, side / h)
        let nw = w * ratio, nh = h * ratio
        let size = NSSize(width: side, height: side)
        let ns = NSImage(size: size)
        ns.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: side, height: side)).fill()
        let rect = NSRect(x: (side - nw) / 2, y: (side - nh) / 2, width: nw, height: nh)
        NSGraphicsContext.current?.imageInterpolation = .high
        NSImage(cgImage: cg, size: NSZeroSize).draw(
            in: rect, from: NSZeroRect, operation: .sourceOver, fraction: 1.0
        )
        ns.unlockFocus()
        return ns
    }

    private func buildPlaceholderFrames(count: Int, side: CGFloat) -> [NSImage] {
        var result: [NSImage] = []
        let size = NSSize(width: side, height: side)
        for i in 0..<count {
            let ns = NSImage(size: size)
            ns.lockFocus()
            
            let hue = CGFloat(i) / CGFloat(max(1, count))
            let accent = NSColor(calibratedHue: hue, saturation: 0.55, brightness: 0.92, alpha: 1.0)
            let dark = NSColor(calibratedHue: hue, saturation: 0.7, brightness: 0.55, alpha: 1.0)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: [accent.cgColor, dark.cgColor] as CFArray,
                locations: [0.0, 1.0]
            )!
            if let ctx = NSGraphicsContext.current?.cgContext {
                ctx.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: side),
                    end: CGPoint(x: side, y: 0),
                    options: []
                )
            }
            
            let label = "\(i + 1)" as NSString
            let fontSize = side * 0.42
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .heavy),
                .foregroundColor: NSColor.white.withAlphaComponent(0.95),
                .shadow: ({
                    let s = NSShadow(); s.shadowBlurRadius = 8; s.shadowColor = NSColor.black.withAlphaComponent(0.4); return s
                })(),
            ]
            let labelSize = label.size(withAttributes: attrs)
            label.draw(
                at: NSPoint(x: (side - labelSize.width) / 2, y: (side - labelSize.height) / 2),
                withAttributes: attrs
            )
            ns.unlockFocus()
            result.append(ns)
        }
        return result
    }
}

private extension NSImage {
    
    func withWhiteBackground() -> NSImage {
        let size = self.size
        let out = NSImage(size: size)
        out.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(in: NSRect(origin: .zero, size: size),
             from: NSRect(origin: .zero, size: size),
             operation: .sourceOver,
             fraction: 1.0)
        out.unlockFocus()
        return out
    }
    
    func resized(maxEdge: CGFloat) -> NSImage {
        let w = size.width, h = size.height
        guard max(w, h) > maxEdge, w > 0, h > 0 else { return self }
        let ratio = maxEdge / max(w, h)
        let nw = (w * ratio).rounded(.down)
        let nh = (h * ratio).rounded(.down)
        let newSize = NSSize(width: nw, height: nh)
        let out = NSImage(size: newSize)
        out.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(in: NSRect(origin: .zero, size: newSize),
             from: NSRect(origin: .zero, size: size),
             operation: .sourceOver,
             fraction: 1.0)
        out.unlockFocus()
        return out
    }
}
