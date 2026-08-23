# FocusFlow History Summary

## 1. Session timeline

- 2026-06-17: FocusFlow was conceived, planned, implemented as a native SwiftPM macOS menu-bar Pomodoro app, reviewed after a design refinement pass, installed to `/Applications`, and then refined again toward a slimmer Flow-like UX.
- 2026-06-19: Notification settings were reworked so the app shows live macOS notification permission state and explains why phase alerts are or are not appearing.

## 2. My requests

- `"lets program a pomodoro timer with similar functions as the "flow" app currently installed on my mac - it should work in a similar way"`  
  Outcome: `PARTIAL`  
  Notes: this produced a detailed implementation plan first; the app was built only after the later explicit implementation request.

- `"PLEASE IMPLEMENT THIS PLAN: # FocusFlow Native Pomodoro App ..."`  
  Outcome: `DONE`  
  Notes: the app was implemented at `/Users/gabrielblacher/Documents/Codex/focus-flow`, built, tested, and launched.

- `"execute with "high" level reasoning"`  
  Outcome: `DONE`  
  Notes: the implementation continued under that instruction.

- `"give me a prompt + handoff so other model can improve the UX - building from the inspiration app we used and what you actually delivered"`  
  Outcome: `DONE`

- `"Project: /Users/gabrielblacher/Documents/Codex/focus-flow ... Build and run the app, then do a thorough visual and functional review ... Fix anything that looks off."`  
  Outcome: `DONE`  
  Notes: fixes included VoiceOver wording, quieter Reduce Motion behavior, removing a stray ring dot, removing blank-looking statistics stripes, and bringing the existing timer window forward on shortcut.

- `"ok, how do i install it?"`  
  Outcome: `DONE`

- `"yes pls"`  
  Outcome: `DONE`  
  Notes: FocusFlow was copied to `/Applications/FocusFlow.app` and launched.

- `"lets plan some improvements: ... 1) ... border size below is inconsistent ... 2) overall, lets make it slimmer ... 3) tag colors should appear on the timer ... 4) we need a timer clock on the menu bar ... before implementing: install/configure any tools you may need ... follow liquid glass "guidelines"`  
  Outcome: `PARTIAL`  
  Notes: the initial attempt was interrupted; a formal UX refinement plan was later produced. I did not find evidence that extra tools were installed during that planning step.

- `"try again"`  
  Outcome: `DONE`  
  Notes: used to resume the interrupted planning attempt.

- `"try again"`  
  Outcome: `DONE`  
  Notes: used to resume the interrupted planning attempt.

- `"try again"`  
  Outcome: `DONE`  
  Notes: this led to the explicit UX refinement plan being produced.

- `"PLEASE IMPLEMENT THIS PLAN: # FocusFlow UX Refinement Plan ..."`  
  Outcome: `PARTIAL`  
  Notes: the refinement was implemented and verified, but the final tiny Statistics label fix was not rebuilt/reinstalled into `/Applications` because approval credits ran out after the last source-only tweak.

- `"In /Users/gabrielblacher/Documents/Codex/focus-flow, make notification setup explicit. Show the current macOS notification permission status in Settings, add a button to open the right system settings when permission is denied, and make the notifications section clear enough that I’ll know immediately why phase alerts are or aren’t appearing."`  
  Outcome: `DONE`

## 3. Decisions and constraints

- You wanted the app to be `"similar"` to Flow in behavior and feel, but not a clone.
- You explicitly approved the name `FocusFlow` through the implementation plan.
- You explicitly constrained V1 to a menu-bar-first native SwiftPM macOS app with a compact timer window and separate settings/statistics surfaces.
- You explicitly deferred these items to later / Phase 2: app or web blocking, iCloud sync, widgets, calendar sync, Health sync, and AppleScript automation.
- You explicitly wanted the app to avoid copying `"Flow branding, assets, or private data"`.
- You explicitly allowed global shortcuts only `"where practical"` and wanted local shortcuts kept if macOS rejected global registration.
- In the review/fix pass, you explicitly said: `"Do not add new features."`
- In that same pass, you explicitly constrained the work to HANDOFF rules: `≤360px timer window`, `no nested cards`, `native materials only`, and edits limited to `views/AppModel/Support`.
- In the UX-improvement request, you explicitly wanted the app `"slimmer"`, wanted tag colors to appear on the timer, and wanted a Flow-like timer clock in the menu bar.
- You explicitly asked that any notification UX make it so you would `"know immediately why phase alerts are or aren’t appearing"`, which drove the later permission-status work.
- `(inferred)` The repeated `"try again"` messages indicate you preferred the same task to continue rather than be abandoned after interruption.

## 4. Known issues left open

none found

## 5. Deferred / planned work

- App / web blocking was repeatedly marked as `Phase 2`.
- iCloud sync was repeatedly deferred.
- Widgets were repeatedly deferred.
- Calendar sync was repeatedly deferred.
- Health sync was repeatedly deferred.
- AppleScript automation was repeatedly deferred.
- Onboarding / help screens were described as remaining out of scope for the UX refinement pass.

## 6. Environment notes

- The project was created and built as a SwiftPM macOS app, not an Xcode-project app.
- On 2026-06-17, the implementation assumed `"Full Xcode is not currently selected, so SwiftPM is the primary build path."`
- On 2026-06-17, test-related framework/rpath settings were added in `Package.swift` so Swift Testing would work with the installed Command Line Tools layout.
- On 2026-06-19, initial SwiftPM checks hit sandbox/toolchain issues; successful verification required redirected module cache paths and elevated permissions.
- On 2026-06-19, Swift 6 concurrency surfaced a data-race diagnostic around the notification service; the recorded fix was marking `NotificationService` as `@unchecked Sendable`.
- During the later UX refinement implementation, a final tiny Statistics label fix could not be rebuilt/reinstalled into `/Applications` because the approval system started rejecting elevated build actions due `"workspace out of credits"`.
