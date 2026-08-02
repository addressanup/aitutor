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

    public func attribute(_ name: String) -> AnyObject? {
        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(raw, name as CFString, &value)
        return err == .success ? value : nil
    }

    public var role: String? { attribute(kAXRoleAttribute) as? String }
    public var title: String? { attribute(kAXTitleAttribute) as? String }

    public func children() -> [AXElement] {
        guard let arr = attribute(kAXChildrenAttribute) as? [AXUIElement] else { return [] }
        return arr.map(AXElement.init)
    }

    public func press() -> Bool {
        AXUIElementPerformAction(raw, kAXPressAction as CFString) == .success
    }

    public func setValue(_ value: String, for attribute: String) -> Bool {
        AXUIElementSetAttributeValue(raw, attribute as CFString, value as CFString) == .success
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
