# FocusFlow — Build / Run / Test

## Build / Run / Test

```bash
# Compile check only
swift build

# Run the in-process self-test suite (FocusFlowCore regressions) — see below
swift run SelfTests

# Build, assemble .app bundle, and launch
./script/build_and_run.sh

# Full post-change verification (build + launch + process check) — use this after every change
./script/build_and_run.sh --verify

# Stream os_log output while running
./script/build_and_run.sh --logs

# Package an ad-hoc-signed distributable ZIP into dist/
./script/package_release.sh
```

**Do NOT run `swift test`.** On this machine (Command Line Tools only, no full Xcode),
`swift test` silently exits 0 without running any tests. The Tests/FocusFlowTests/*.swift
suite is effectively dead — use `swift run SelfTests` instead, which ports the same
assertions into a plain executable target (`Sources/SelfTests/main.swift`) that actually
runs and returns a non-zero exit code on failure. The correct end-to-end verification path
is `swift run SelfTests` followed by `./script/build_and_run.sh --verify`.

**Antigravity briefs:** the default Verification block for any focus-flow brief
(`_briefs/YYYY-MM-DD-<slug>.md`, per `~/GitHub & Coding Projects/BRIEF-TEMPLATE.md`) is
`swift build` + `swift run SelfTests` + `./script/build_and_run.sh --verify` — all three
must pass, with real output in the execution report.

---

## Conventions / Gotchas

- **CLT-only build environment.** No Xcode.app installed. SwiftPM only. `xcodebuild` and
  XCTest runner are unavailable. All build/run/verify must go through `swift build` or
  `./script/build_and_run.sh`.
- **Swift 6 strict concurrency.** All shared state must be `@MainActor`-isolated or
  `Sendable`. Do not suppress warnings with `@preconcurrency` or `nonisolated(unsafe)`
  without a comment explaining why it is safe.
- **No Xcode project.** No `.xcodeproj`, no asset catalogs. Icons live at `AppIcon.icns`
  in the repo root and are copied into the bundle by `build_and_run.sh`.
- **SwiftUI + AppKit.** The app target uses AppKit (menus, NSEvent, NSSound). The Core
  library target must stay AppKit-free — it is tested in isolation.
- **Do not widen the timer window.** Max ~360 px. Menu-bar dropdown stays narrow.
- **No feature scope creep.** No iCloud sync, widgets, web blocking, or calendar sync.
  No `.xcodeproj`. See `HANDOFF.md` for the full "what NOT to do" list.
- **Bundle ID:** `com.gabrielblacher.FocusFlow` · **Min macOS:** 14.0

# macOS Swift/AppKit Patterns (moved from Antigravity global rules, 2026-07-10)

## Swift 6 Strict Concurrency Rules

When writing Swift code targeting macOS 14+ with strict concurrency checks enabled, apply the following patterns to resolve common actor-isolation and sendability warnings:

1. **Non-Sendable Callback Observers (e.g., `NSObjectProtocol`)**:
   Observing system-wide notifications (e.g., `DistributedNotificationCenter.default().addObserver`) returns an `any NSObjectProtocol` object, which is non-Sendable. Accessing or removing this observer in a class `deinit` will cause a compiler error because `deinit` is nonisolated.

   **Pattern**: Wrap it in a file-private `@unchecked Sendable` helper struct:

   ```swift
   private struct SendableObserver: @unchecked Sendable {
       let value: any NSObjectProtocol
   }
   ```

   Store this wrapper as a class property and clean it up inside `deinit`:

   ```swift
   private var observer: SendableObserver?

   deinit {
       if let observer = observer {
           DistributedNotificationCenter.default().removeObserver(observer.value)
       }
   }
   ```

2. **Main Actor Isolation in Closures**:
   If an observer callback closure is run in a non-isolated or background context, do not call `@MainActor` isolated methods or update `@Published` variables synchronously.

   **Pattern**: Wrap the call inside a `@MainActor` Task block:

   ```swift
   Task { @MainActor in
       self.updateMainActorState()
   }
   ```

## SwiftUI and AppKit Integration Patterns

When developing hybrid SwiftUI and AppKit macOS applications, follow these established design patterns to coordinate window life cycle, environment access, and status item event handling:

1. **Accessing the App Delegate under the SwiftUI Lifecycle**:
   SwiftUI installs its own internal forwarding delegate under the `@main` lifecycle, meaning direct casts like `NSApp.delegate as? AppDelegate` will always return `nil` even when using `@NSApplicationDelegateAdaptor`.

   **Pattern**: Maintain a static weak reference to the active delegate during initialization:
   ```swift
   @MainActor
   final class AppDelegate: NSObject, NSApplicationDelegate {
       private(set) static weak var shared: AppDelegate?

       override init() {
           super.init()
           AppDelegate.shared = self
       }
   }
   ```

2. **Accessing SwiftUI Environment Actions in AppKit/Non-SwiftUI Code**:
   SwiftUI window-opening closures (e.g., `@Environment(\.openWindow)`) are environment-driven and cannot be directly resolved in AppKit classes (like `NSStatusItem` delegates or controllers).

   **Pattern**: Host an off-screen, invisible (e.g., 1x1, borderless) `NSWindow` containing an `NSHostingView` wrapping a minimal bridge view. This view captures the environment closures in a `.task` and binds them to a shared model:
   ```swift
   let win = NSWindow(
       contentRect: NSRect(x: -100, y: -100, width: 1, height: 1),
       styleMask: [.borderless],
       backing: .buffered,
       defer: false
   )
   win.isReleasedWhenClosed = false
   win.isExcludedFromWindowsMenu = true
   win.contentView = NSHostingView(rootView: EnvironmentBridgeView(app: app))

   // CRITICAL: Force layout calculation so the hosting view is rendered and its .task fires
   win.contentView?.layoutSubtreeIfNeeded()
   ```
   Inside the bridge view:
   ```swift
   private struct EnvironmentBridgeView: View {
       let app: AppModel
       @Environment(\.openWindow) private var openWindow

       var body: some View {
           Color.clear
               .frame(width: 0, height: 0)
               .task {
                   app.openTimerWindow = { openWindow(id: "timer") }
               }
       }
   }
   ```

3. **Custom NSStatusItem Left/Right Click Interception**:
   When replacing SwiftUI's `MenuBarExtra` with AppKit's `NSStatusItem` to allow custom click logic (e.g. right-click to fast-path resume, left-click to show a dropdown):
   - **Dual Action Configuration**: Enable both mouse up events on the status button:
     ```swift
     button.sendAction(on: [.leftMouseUp, .rightMouseUp])
     ```
   - **Event Filtering**: Check `NSApp.currentEvent?.type == .rightMouseUp` to branch.
   - **Accessibility & VoiceOver Fallback**: Programmatic and assistive clicks arrive with no mouse event (e.g., `NSApp.currentEvent` is `nil` or has another type). Always fall back to the default left-click (showing the menu) so the status item remains accessible:
     ```swift
     @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
         if NSApp.currentEvent?.type == .rightMouseUp, app.performSecondaryAction() {
             return
         }
         // Default menu display path
     }
     ```
   - **Programmatic Menu Display**: When triggering the AppKit menu under the status item button programmatically, assign it temporarily to the status item's `menu` property, trigger it, and immediately clear it so subsequent clicks still route to the click action:
     ```swift
     let menu = buildMenu()
     statusItem.menu = menu
     sender.performClick(nil) // Opens the menu natively aligned with the item
     statusItem.menu = nil    // Clears the property to keep action forwarding active
     ```

4. **Launch Ordering with Environment Bridges**:
   If window-opening closures are captured via an environment bridge, do not execute startup actions that depend on those closures (e.g. "show window at launch" preferences) in your initial app code. At that point, the environment task has not run yet. Instead, trigger startup window-opening checks inside the bridge view's `.task` block *after* the environment closures are successfully assigned.

5. **NSViewRepresentable / UIViewRepresentable Delegate Concurrency**:
   When implementing a `Coordinator` that conforms to a custom delegate protocol for an AppKit/UIKit view, the compiler may flag `sending 'self' risks causing data races` if you attempt to wrap delegate method bodies in `Task { @MainActor in }`.
   
   **Pattern**: Do not use `Task` wrappers inside the methods. Instead, mark both the delegate protocol and the `Coordinator` class with `@MainActor`, as AppKit/UIKit UI events are inherently fired on the main thread.
   
   ```swift
   @MainActor
   protocol MyCustomViewDelegate: AnyObject {
       func didTriggerEvent()
   }

   @MainActor
   class Coordinator: MyCustomViewDelegate {
       func didTriggerEvent() {
           // Safe to directly access @MainActor state here without Task { @MainActor in }
       }
   }
   ```
