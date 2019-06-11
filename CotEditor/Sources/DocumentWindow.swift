//
//  DocumentWindow.swift
//
//  CotEditor
//  https://coteditor.com
//
//  Created by 1024jp on 2014-10-31.
//
//  ---------------------------------------------------------------------------
//
//  © 2014-2019 1024jp
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Cocoa

final class DocumentWindow: NSWindow {
    
    // MARK: Notification Names
    
    static let didChangeOpacityNotification = Notification.Name("WindowDidChangeOpacity")
    
    
    // MARK: Public Properties
    
    var contentBackgroundColor: NSColor = .controlBackgroundColor {
        
        didSet {
            guard !self.isOpaque, contentBackgroundColor != oldValue else { return }
            
            self.backgroundColor = contentBackgroundColor.withAlphaComponent(self.backgroundAlpha)
            self.invalidateShadow()
            self.contentView?.needsDisplay = true
        }
    }
    
    @objc var backgroundAlpha: CGFloat = 1.0 {
        
        didSet {
            backgroundAlpha = backgroundAlpha.clamped(to: 0.2...1.0)
            
            self.isOpaque = (backgroundAlpha == 1.0)
            self.backgroundColor = self.isOpaque ? nil : self.contentBackgroundColor.withAlphaComponent(backgroundAlpha)
            
            self.invalidateShadow()
            self.contentView?.needsDisplay = true
        }
    }
    
    
    // MARK: Private Properties
    
    private var appearanceObserver: NSKeyValueObservation?
    
    
    
    // MARK: -
    // MARK: Lifecycle
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing bufferingType: NSWindow.BackingStoreType, defer flag: Bool) {
        
        super.init(contentRect: contentRect, styleMask: style, backing: bufferingType, defer: flag)
        
        self.appearanceObserver = self.observe(\.effectiveAppearance) { [weak self] (_, _) in
            self?.invalidateTitlebarOpacity()
        }
        
        // observe toggling fullscreen mode
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterOpaqueMode), name: NSWindow.willEnterFullScreenNotification, object: self)
        NotificationCenter.default.addObserver(self, selector: #selector(willExitOpaqueMode), name: NSWindow.willExitFullScreenNotification, object: self)
        
        // observe toggling Versions browsing
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterOpaqueMode), name: NSWindow.willEnterVersionBrowserNotification, object: self)
        NotificationCenter.default.addObserver(self, selector: #selector(willExitOpaqueMode), name: NSWindow.willExitVersionBrowserNotification, object: self)
    }
    
    
    deinit {
        self.appearanceObserver?.invalidate()
    }
    
    
    
    // MARK: Window Methods
    
    /// notify about opacity change
    override var isOpaque: Bool {
        
        didSet {
            guard isOpaque != oldValue else { return }
            
            self.invalidateTitlebarOpacity()
            
            NotificationCenter.default.post(name: DocumentWindow.didChangeOpacityNotification, object: self)
        }
    }
    
    
    /// store UI state
    override func restoreState(with coder: NSCoder) {
        
        super.restoreState(with: coder)
        
        if coder.containsValue(forKey: #keyPath(backgroundAlpha)) {
            self.backgroundAlpha = CGFloat(coder.decodeDouble(forKey: #keyPath(backgroundAlpha)))
        }
    }
    
    
    /// resume UI state
    override func encodeRestorableState(with coder: NSCoder) {
        
        super.encodeRestorableState(with: coder)
        
        coder.encode(Double(self.backgroundAlpha), forKey: #keyPath(backgroundAlpha))
    }
    
    
    
    // MARK: Notifications
    
    /// entering Versions
    @objc private func willEnterOpaqueMode(_ notification: Notification) {
        
        self.isOpaque = true
    }
    
    
    /// exiting Versions
    @objc private func willExitOpaqueMode(_ notification: Notification) {
        
        self.isOpaque = (self.backgroundAlpha == 1)
    }
    
    
    
    // MARK: Private Methods
    
    /// make sure window title bar (incl. toolbar) is opaque
    private func invalidateTitlebarOpacity() {
        
        // dirty manupulation to avoid the title bar being dyed in the window background color (2016-01).
        self.titlebarView?.wantsLayer = !self.isOpaque
        self.titlebarView?.layer?.backgroundColor = self.isOpaque ? nil : NSColor.windowBackgroundColor.cgColor(for: self.effectiveAppearance)
    }

}



// MARK: Window Tabbing

extension DocumentWindow {
    
    /// settable window user tabbing preference (Don't forget to set to `nil` after use.)
    static var tabbingPreference: NSWindow.UserTabbingPreference?
    
    
    
    // MARK: Window Methods
    
    override class var userTabbingPreference: NSWindow.UserTabbingPreference {
        
        if let tabbingPreference = self.tabbingPreference {
            return tabbingPreference
        }
        
        if let tabbingPreference = NSWindow.UserTabbingPreference(rawValue: UserDefaults.standard[.windowTabbing]), tabbingPreference.rawValue >= 0 {  // -1 obays system setting
            return tabbingPreference
        }
        
        return super.userTabbingPreference
    }
    
    
    /// process user's shortcut input
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        
        guard !super.performKeyEquivalent(with: event) else { return true }
        
        // select tabbed window with `⌘+number`
        // -> select last tab with `⌘0`
        guard
            event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.numericPad) == .command,
            let characters = event.charactersIgnoringModifiers,
            let number = Int(characters), number > 0,
            let windows = self.tabbedWindows,
            let window = (number == 9) ? windows.last : windows[safe: number - 1]  // 1-based to 0-based
            else { return false }
        
        // prefer existing shortcut that user might define
        guard !NSApp.mainMenu!.performKeyEquivalent(with: event) else { return true }
        
        window.tabGroup?.selectedWindow = window
        
        return true
    }
    
}


// MARK: -

private extension NSWindow {
    
    var titlebarView: NSVisualEffectView? {
        
        return self.standardWindowButton(.closeButton)?.superview as? NSVisualEffectView
    }
    
}
