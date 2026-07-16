#!/usr/bin/env bash
# Records the four promo clips from the emulator. Run from repo root.
# Prereqs: emulator booted, app installed and SIGNED OUT, demo mode entered
# (reuses the demo-mode + notification-purge guard block from
# capture_screenshots.sh so no personal data can appear).
#
# Adaptations vs. the original brief (discovered empirically on this AVD,
# see task-mktg-5-report.md for full detail):
#  1. screenrecord here only advances the video PTS while the screen is
#     visibly changing; a quick gesture followed by a long idle hold
#     collapses the clip to a couple seconds of real video. Drivers below
#     favor slow, long-duration swipes and — for the detail scene — the
#     real "Set as wallpaper" flow (which has several seconds of genuine
#     state changes: chooser sheet, spinner, apply transition) instead of a
#     no-op swipe on a static image.
#  2. The floating nav pill expands a text label on the active tab, which
#     shifts the other icons' x-positions, so a fixed coordinate for jumping
#     from Settings back to Explore is not reliable. Rather than chain all
#     four clips through one app session (where each clip's driver depends
#     on exactly where the previous one left the UI), every clip force-stops
#     and restarts the app fresh, landing on a known Explore-at-top state
#     every time. This also sidesteps the "Set as wallpaper" network/apply
#     call, whose duration varies (sometimes several seconds) — with a fresh
#     restart per clip there's no next-clip driver waiting on that
#     completion or depending on which screen it left behind.
#  3. App cold-start time varies run to run; a fixed sleep was sometimes too
#     short. wait_ready() polls (via uiautomator) for the Explore feed's
#     "Featured" chip before driving any gestures.
set -euo pipefail
ADB="$HOME/Library/Android/sdk/platform-tools/adb"
OUT="tool/marketing/out/clips"
mkdir -p "$OUT"

wait_ready() {  # poll until the Explore feed (Featured chip) is on screen
  for _ in $(seq 1 25); do
    "$ADB" shell uiautomator dump /sdcard/wallify_ready.xml >/dev/null 2>&1 || true
    if "$ADB" exec-out cat /sdcard/wallify_ready.xml 2>/dev/null | grep -q 'text="Featured"'; then
      "$ADB" shell rm -f /sdcard/wallify_ready.xml
      return 0
    fi
    sleep 1
  done
  "$ADB" shell rm -f /sdcard/wallify_ready.xml
  echo "WARNING: Explore feed not detected as ready in time" >&2
}

# --- Demo mode: fixed 10:00 clock, full battery, no notification icons. -----
"$ADB" shell settings put global sysui_demo_allowed 1
"$ADB" shell am broadcast -a com.android.systemui.demo -e command enter >/dev/null
"$ADB" shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 1000 >/dev/null
"$ADB" shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false >/dev/null
"$ADB" shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4 >/dev/null
"$ADB" shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false >/dev/null

# --- Notification purge guard ------------------------------------------------
# Demo mode does NOT suppress real notifications; purge everything and
# hard-fail if anything survives so no personal data leaks into recordings.
notif_count() {
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

if [ "$(notif_count)" -ne 0 ]; then
  echo "ERROR: active notifications present — personal data may leak into recordings" >&2
  exit 1
fi
# -----------------------------------------------------------------------------

rec() {  # rec <name> <seconds> <driver-function>
  local name=$1 secs=$2 driver=$3
  "$ADB" shell am force-stop com.asghar.wallify
  "$ADB" shell am start -n com.asghar.wallify/.MainActivity >/dev/null
  wait_ready
  "$ADB" shell "screenrecord --time-limit $secs --bit-rate 8000000 /sdcard/$name.mp4" &
  local pid=$!
  sleep 1
  $driver
  wait $pid
  "$ADB" pull "/sdcard/$name.mp4" "$OUT/$name.mp4" >/dev/null
  "$ADB" shell rm "/sdcard/$name.mp4"
  echo "recorded $name"
}

drive_explore() {  # slow browse of the feed — continuous motion throughout,
                    # extra swipe + margin since real captured frame count
                    # varies run to run on this AVD (see adaptation note).
  sleep 1
  "$ADB" shell input swipe 540 1800 540 800 1200
  sleep 1
  "$ADB" shell input swipe 540 1800 540 800 1200
  sleep 1
  "$ADB" shell input swipe 540 1800 540 800 1200
  sleep 0.5
}

# The detail scene is recorded in TWO parts and concatenated: on this AVD,
# screenrecord reliably halts ~3.2 s after the Hero transition into the
# full-bleed detail screen (single-recording attempts produced dud or
# truncated clips repeatedly). Part A captures feed -> tap -> detail with
# the attribution panel; part B (a fresh screenrecord, which survives fine
# once the transition is behind it) captures Set as wallpaper -> the
# Home/Lock/Both chooser sheet. This is the validated method that produced
# the committed detail.mp4.
record_detail() {
  "$ADB" shell am force-stop com.asghar.wallify
  "$ADB" shell am start -n com.asghar.wallify/.MainActivity >/dev/null
  wait_ready
  "$ADB" shell "screenrecord --time-limit 7 --bit-rate 8000000 /sdcard/detail_a.mp4" &
  local pid=$!
  sleep 1.2
  "$ADB" shell input tap 282 642    # first wallpaper tile
  sleep 3.5
  "$ADB" shell input swipe 540 1900 540 1450 500   # reveal the glass panel
  wait $pid
  "$ADB" shell "screenrecord --time-limit 5 --bit-rate 8000000 /sdcard/detail_b.mp4" &
  pid=$!
  sleep 1.5
  "$ADB" shell input tap 456 2183   # "Set as wallpaper" -> chooser sheet
  wait $pid
  "$ADB" pull /sdcard/detail_a.mp4 "$OUT/detail_a.mp4" >/dev/null
  "$ADB" pull /sdcard/detail_b.mp4 "$OUT/detail_b.mp4" >/dev/null
  "$ADB" shell rm /sdcard/detail_a.mp4 /sdcard/detail_b.mp4
  "$ADB" shell input keyevent KEYCODE_BACK   # dismiss the sheet
  ffmpeg -y -loglevel error -i "$OUT/detail_a.mp4" -i "$OUT/detail_b.mp4" \
    -filter_complex "[0:v]fps=30,setpts=PTS-STARTPTS[a];[1:v]fps=30,setpts=PTS-STARTPTS[b];[a][b]concat=n=2:v=1:a=0[v];[v]tpad=stop_mode=clone:stop_duration=1.0[out]" \
    -map "[out]" -c:v libx264 -crf 18 "$OUT/detail.mp4"
  rm "$OUT/detail_a.mp4" "$OUT/detail_b.mp4"
  echo "recorded detail (2-part concat)"
}

drive_dark() {     # browse a dark category — fresh restart lands on Explore
  sleep 0.5
  "$ADB" shell input tap 590 290        # Abstract chip
  sleep 1.3
  "$ADB" shell input swipe 540 1900 540 1000 3200   # slow continuous scroll, 3.2s
  sleep 0.3
}

drive_saved() {    # saved grid then settings account row
  "$ADB" shell input tap 620 2222       # Saved tab (from Explore — verified coordinate)
  sleep 1
  "$ADB" shell input swipe 540 1900 540 1300 2500   # slow scroll of saved grid, 2.5s
  sleep 0.3
  "$ADB" shell input tap 773 2222       # Settings tab (from Saved — verified coordinate)
  sleep 1
  "$ADB" shell input swipe 540 1500 540 1150 2000   # gentle scroll, keeps Account in view
  sleep 0.3
}

rec explore 10 drive_explore
record_detail
rec dark 7 drive_dark
rec saved 9 drive_saved
"$ADB" shell am broadcast -a com.android.systemui.demo -e command exit >/dev/null
echo "done — watch each clip before composing"
