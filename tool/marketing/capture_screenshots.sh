#!/usr/bin/env bash
# Captures the five marketing screenshots from the running emulator.
# Prereqs: emulator-5554 booted, latest debug app installed, SIGNED OUT.
# Run from repo root: bash tool/marketing/capture_screenshots.sh
set -euo pipefail
ADB="$HOME/Library/Android/sdk/platform-tools/adb"
OUT="marketing/screenshots/raw"
mkdir -p "$OUT"

shot() { sleep "$1"; "$ADB" exec-out screencap -p > "$OUT/$2.png"; echo "captured $2"; }

# Clean status bar via demo mode: fixed 10:00 clock, full battery, no notifications.
"$ADB" shell settings put global sysui_demo_allowed 1
"$ADB" shell am broadcast -a com.android.systemui.demo -e command enter >/dev/null
"$ADB" shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 1000 >/dev/null
"$ADB" shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false >/dev/null
"$ADB" shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4 >/dev/null
"$ADB" shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false >/dev/null

# --- Notification purge guard ------------------------------------------------
# Demo mode does NOT suppress real notifications: a real "Find Hub" system
# notification once put an icon in the status bar and leaked a personal Gmail
# address into captures. Purge everything and hard-fail if anything survives.
#
# `service call notification 1` (cancelAllNotifications) throws a
# SecurityException for the shell uid on API 36, so drive the UI instead:
# expand the shade, tap "Clear all", collapse. The button is located
# dynamically via uiautomator (its Y position shifts with the number of
# notifications); observed coordinates on this AVD (1080x2400) are the
# fallback if the dump fails.
notif_count() {
  # One line per active notification; `|| true` because grep -c exits 1 on
  # zero matches, which would kill the script under `set -e`.
  "$ADB" shell dumpsys notification | grep -c 'NotificationRecord(' || true
}

if [ "$(notif_count)" -ne 0 ]; then
  echo "active notifications found — clearing"
  "$ADB" shell cmd statusbar expand-notifications
  sleep 2
  "$ADB" shell uiautomator dump /sdcard/wallify_guard_ui.xml >/dev/null 2>&1 || true
  bounds=$("$ADB" exec-out cat /sdcard/wallify_guard_ui.xml 2>/dev/null \
    | grep -o 'content-desc="Clear all notifications."[^>]*bounds="\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]"' \
    | grep -o '\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]' | head -1)
  "$ADB" shell rm -f /sdcard/wallify_guard_ui.xml
  if [ -n "$bounds" ]; then
    read -r tap_x tap_y <<<"$(echo "$bounds" | sed 's/\]\[/,/; s/[][]//g' \
      | awk -F, '{ print int(($1+$3)/2), int(($2+$4)/2) }')"
  else
    tap_x=540; tap_y=932   # Clear-all center with one notification, API 36 emulator
  fi
  "$ADB" shell input tap "$tap_x" "$tap_y"
  sleep 2
  "$ADB" shell cmd statusbar collapse
  sleep 1
fi

# Assert nothing survived (some system notifications are uncancelable; none
# exist on this emulator image today — if a guaranteed-benign one ever
# appears, filter it out of notif_count above and document why here).
if [ "$(notif_count)" -ne 0 ]; then
  echo "ERROR: active notifications present — personal data may leak into captures" >&2
  exit 1
fi
# -----------------------------------------------------------------------------

# Fresh app start on the Explore tab.
"$ADB" shell am force-stop com.asghar.wallify
"$ADB" shell am start -n com.asghar.wallify/.MainActivity >/dev/null
shot 8 explore                                   # feed loaded

"$ADB" shell input tap 280 600                   # first wallpaper tile
shot 5 detail
"$ADB" shell input keyevent KEYCODE_BACK; sleep 2

"$ADB" shell input tap 620 2222                  # Saved tab in the nav pill
shot 3 saved

"$ADB" shell input tap 773 2222                  # Settings tab
shot 3 settings                                  # Account + Appearance visible

"$ADB" shell input swipe 540 1800 540 500 600    # scroll to About (slow, ends held — no fling)
# Settle nudge: after a fling into max scroll, the large "Settings" title can
# rest half-faded over APPEARANCE (stuck at partial opacity; reproduced as a
# byte-stable state). A same-direction nudge is pure overscroll and doesn't
# re-trigger the fade — scroll back ~250px and forward again so the header
# animation re-runs to fully hidden (verified on the emulator).
sleep 1
"$ADB" shell input swipe 540 700 540 950 300
sleep 1
"$ADB" shell input swipe 540 950 540 700 300
shot 3 about                                     # extra settle time: ghosting seen at 2s

"$ADB" shell am broadcast -a com.android.systemui.demo -e command exit >/dev/null
echo "done — verify each PNG visually before framing"
