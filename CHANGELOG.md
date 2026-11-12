# Changelog

## 1.2.0

### New

- **Updates from within the app.** PeakBar checks GitHub once a day for a new version. When there is one, you get a notification and an **Update** button on the card; one click downloads, verifies and installs it, then restarts PeakBar. Powered by [Sparkle](https://sparkle-project.org).
- Settings: **Check for updates** with a **Check now** button, and **Notify when an update is available**. The back of the card also shows the version.

### Security

- Updates and the update feed are signed with an EdDSA key; unsigned or altered updates are refused.

### Note

- Version 1.1.1 and older have no updater: install this version once by hand, later versions arrive by themselves.

## 1.1.1

### Fixed

- **No more repeated Keychain password prompts.** The token is now read through `/usr/bin/security`, which macOS already trusts for Claude Code's Keychain item. "Always Allow" used to be lost whenever Claude Code renewed its token or the app was rebuilt.

### Changed

- Settings card is about a quarter shorter: minute steppers sit on the same line as their notification.

## 1.1.0

### New

- **Settings on the back of the card.** The gear icon flips the panel over to all settings; **Done** flips it back.
- **Refresh as an icon.** The refresh button is now an icon next to the gear and spins while loading.
- **Weekly pace.** The week bar shows a marker for how much of the week has passed, so you can see at a glance whether you are ahead of schedule.
- **Weekly forecast.** A line under the week bar tells you where your current pace leads, for example "At this pace you run out Thu 20:24" or "On track: about 42% at the reset".
- **Daily budget.** Shows how much of the weekly limit you can use per remaining day to stay on track.
- **Weekly usage ring.** The menu bar dot gets an orange ring at 80% weekly usage and a red ring at 90%.
- **Notifications** (each can be switched off on the back of the card):
  - Peak hours: before they start (0 to 60 minutes ahead, 0 = at the start), before they end (1 to 60 minutes ahead), and when they have ended. Scheduled with macOS ahead of time, so they arrive on time.
  - Session: warnings at 80% and 90% of the 5-hour session, and a notification when the session resets.
  - Week: warnings at 75% and 90%, and when the current pace runs out before the reset. Each is sent at most once per week.
  - Claude status: when status.claude.com reports a disruption and when it is resolved.
- **Peak status only during peak hours.** Outside peak hours the menu bar shows just the session percentage, e.g. "42%"; during peak hours it shows "42% · Peak 2h".

### Changed

- The menu bar percentage is always the 5-hour session.
- "Open status page" moved to an icon next to Claude status; "Quit" moved to the back of the card.

### Under the hood

- Settings are one value object (`AppSettings`), stored in `UserDefaults`.
- Notification rules live in `NotificationPlanner`, which has no side effects; delivery goes through `UserNotificationService`.
- Weekly pace, forecast and daily budget are calculated in `WeekPace`.
- New English and Dutch strings for all of the above.

## 1.0.0

First release: peak hours, session and weekly usage, and live Claude status in the menu bar.
