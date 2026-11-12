# Troubleshooting and removal

**Input feels wrong:** click the configured button once to exit a lock, choose Emergency Disable or send `kill -USR1 PID`. If necessary, terminate using Activity Monitor/`kill -TERM PID`. Normal input is intended to resume when the process-owned tap disappears; no seized device or persistent cursor setting is used. Do not reboot as a routine fix. Stop hardware testing on any failure of normal-input recovery.

**No scrolling:** check disabled/enabled status, whether `--no-live-input` diagnostics are active, verified secondary button, `046D:C408` connection and existing Accessibility trust. No app permission is requested by code. Tap denial is a safe stopped state; do not run as root, grant unrelated permissions or weaken macOS settings. Prior supervised testing created a HID-entry tap with Accessibility alone; pointer stability still needs explicit hardware validation.

**Button detector shows unexpected number:** numbers are zero-based CG button IDs. Detection observes all secondary mice, not only Logitech. Physical labels, other drivers/remappers and device configurations can differ. Test each small button separately after approval. Primary buttons cannot be reserved.

**Scrolls another region / horizontal does nothing:** macOS dispatches at pointer location. Put the pointer in the desired scrollable pane. Horizontal behavior requires application/document support and actual overflow; no synthetic focus/click is generated. Some modifiers may change app scroll behavior because event flags are preserved.

**Stops after timeout, reconnect or wake:** failure/sleep/disconnect resets activation. At most one timeout recovery is automatic and it never restores a lock. Other recovery needs deliberate re-enable. Inspect the menu tooltip's stop reason. There are no persistent input logs.

**Accessibility no longer recognized after moving/rebuilding:** use one fixed bundle during testing. Ad-hoc identity can change with source/build. After approval, quit and update that exact app entry manually through System Settings. No automatic TCC database edits/reset, quarantine removal or Gatekeeper bypass.

**Xcode build unavailable:** the host currently has Command Line Tools selected. Use the SwiftPM scripts for verified compilation. The macOS CI validates the Xcode project using a full Xcode installation; do not silently switch developer directories or download tools.

## Uninstall — user actions after any approved installation

1. Disable and quit MarbleScroll. If registered, turn off Launch at Login or remove it in System Settings → General → Login Items. No helper/daemon must be removed.
2. Remove the exact bundle from Accessibility, and Input Monitoring only if you separately authorized/added it. The app never grants permissions itself; supervised Accessibility setup has been performed manually.
3. Move the installed app to Trash. Optionally remove its preferences with `defaults delete com.kaushr.MarbleScroll` after quitting.
4. Delete the local `build/` and `.build/` directories if build products/caches are no longer needed. Source and the separately preserved DragScroll audit are independent.

No administrator privilege, reboot, macOS security change or system-wide input configuration cleanup is expected. Record any contrary result as an acceptance failure.
