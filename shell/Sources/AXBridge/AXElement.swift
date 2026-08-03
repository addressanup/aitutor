@preconcurrency import ApplicationServices
import AppKit
import Foundation

// Thin value-oriented wrapper over AXUIElement: read attributes, press actions,
// walk the menu bar. Enough to power axprobe (observe) and snapshot-spike (menu
// drive). AXUIElement is a CF type; we keep it inside this type and expose Swift
// values.

public struct AXElement {
    public let raw: AXUIElement

    public init(_ raw: AXUIElement) { self.raw = raw }

    public static func application(pid: pid_t) -> AXElement {
        AXElement(AXUIElementCreateApplication(pid))
    }

    /// Resolve a running app's pid by bundle id.
    public static func pid(forBundleId bundleId: String) -> pid_t? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first?.processIdentifier
    }

    /// Pid of the frontmost app, asked of the accessibility system directly.
    /// NSWorkspace.frontmostApplication is notification-cached and goes stale in a
    /// CLI tool, which has no run loop pumping those notifications.
    public static func focusedApplicationPid() -> pid_t? {
        let system = AXUIElementCreateSystemWide()
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(
                system, kAXFocusedApplicationAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        var pid: pid_t = 0
        guard AXUIElementGetPid(value as! AXUIElement, &pid) == .success else { return nil }
        return pid
    }

    public func attribute(_ name: String) -> AnyObject? {
        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(raw, name as CFString, &value)
        return err == .success ? value : nil
    }

    public var role: String? { attribute(kAXRoleAttribute) as? String }
    public var subrole: String? { attribute(kAXSubroleAttribute) as? String }
    public var title: String? { attribute(kAXTitleAttribute) as? String }
    public var identifier: String? { attribute(kAXIdentifierAttribute) as? String }
    public var stringValue: String? { attribute(kAXValueAttribute) as? String }

    public func children() -> [AXElement] {
        guard let arr = attribute(kAXChildrenAttribute) as? [AXUIElement] else { return [] }
        return arr.map(AXElement.init)
    }

    public func press() -> Bool { perform(kAXPressAction as String) }

    /// Actions this element advertises. Discovering affordances beats guessing at
    /// them — a save panel's name field, for instance, advertises AXConfirm, which
    /// is how a typed path gets resolved without posting keystrokes at all.
    public func actions() -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(raw, &names) == .success,
              let list = names as? [String] else { return [] }
        return list
    }

    @discardableResult
    public func perform(_ action: String) -> Bool {
        AXUIElementPerformAction(raw, action as CFString) == .success
    }

    public func setValue(_ value: String, for attribute: String) -> Bool {
        AXUIElementSetAttributeValue(raw, attribute as CFString, value as CFString) == .success
    }

    /// Boolean attribute setter. Needed for `AXManualAccessibility`, the flag that makes
    /// Chromium/Electron build its accessibility tree at all — without it those apps look
    /// silent to an observer, which is a false negative, not a density result.
    @discardableResult
    public func setValue(_ flag: Bool, for attribute: String) -> Bool {
        AXUIElementSetAttributeValue(
            raw, attribute as CFString, (flag ? kCFBooleanTrue : kCFBooleanFalse) as CFTypeRef
        ) == .success
    }

    /// All of the app's windows. Note a sheet is not listed here — it arrives as the
    /// focused window instead, which is exactly the distinction that made a naive
    /// "focused window has an AXSheet child" probe never match.
    public var windows: [AXElement] {
        (attribute(kAXWindowsAttribute) as? [AXUIElement])?.map(AXElement.init) ?? []
    }

    /// The app's focused window, if any.
    public var focusedWindow: AXElement? {
        guard let value = attribute(kAXFocusedWindowAttribute) else { return nil }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return AXElement(value as! AXUIElement)
    }

    private func axValue(_ name: String) -> AXValue? {
        guard let value = attribute(name), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return (value as! AXValue)
    }

    /// Screen position of this element's top-left corner, in Quartz global coordinates.
    public var position: CGPoint? {
        guard let value = axValue(kAXPositionAttribute) else { return nil }
        var out = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &out) else { return nil }
        return out
    }

    public var size: CGSize? {
        guard let value = axValue(kAXSizeAttribute) else { return nil }
        var out = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &out) else { return nil }
        return out
    }

    /// Screen rect of this element, when both position and size are readable.
    public var frame: CGRect? {
        guard let position, let size else { return nil }
        return CGRect(origin: position, size: size)
    }

    /// Depth-bounded subtree walk. Yields (depth, element) pairs in pre-order.
    /// Bounded because AX trees in browser-backed apps can be enormous.
    public func descendants(maxDepth: Int, maxNodes: Int = 4000) -> [(depth: Int, element: AXElement)] {
        var out: [(depth: Int, element: AXElement)] = []
        var stack: [(Int, AXElement)] = [(0, self)]
        while let (depth, node) = stack.popLast() {
            out.append((depth, node))
            if out.count >= maxNodes { break }
            guard depth < maxDepth else { continue }
            for child in node.children().reversed() { stack.append((depth + 1, child)) }
        }
        return out
    }

    /// Walk the app's menu bar along a title path, e.g. ["File", "Export as PDF…"].
    public func menuBarItem(path: [String]) -> AXElement? {
        guard var node = attribute(kAXMenuBarAttribute).map({ AXElement($0 as! AXUIElement) }) else { return nil }
        for (index, title) in path.enumerated() {
            let match = node.children().first { $0.title == title }
            guard let found = match else { return nil }
            if index == path.count - 1 { return found }
            // descend into the submenu (first child of role AXMenu)
            guard let submenu = found.children().first(where: { $0.role == kAXMenuRole }) else {
                node = found
                continue
            }
            node = submenu
        }
        return node
    }
}
