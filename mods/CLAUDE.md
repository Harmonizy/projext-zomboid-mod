# Notes for Claude

## Logging (owner's rule, always)
- Every feature or fix writes to console.txt — when unsure, and also when sure,
  because a later edit might break it. The log is how bugs get found in the
  real game.
- GardenToPlate: use `HARMONIE_GTP.Log(tag, fmt, ...)` (prints
  `[HARMONIE_GTP][tag][SP|client|server] ...`). For anything that repeats
  every tick or every frame, use `HARMONIE_GTP.LogOnce(key, tag, fmt, ...)`
  or log only on state changes. Never flood the log every frame or tick.
- Other mods (same idea, each has its own helper):
  | mod | prefix | helper |
  |---|---|---|
  | TheWayToAttack | `[HARMONIE_TWA]` | `TWALog`, `TWALogOnce`, `TWALogErr`, `TWALogName`, `TWALogType`, `TWALogAction(cls, name)` (timed actions), `TWALogMethods(cls, tag, {names})` (window buttons) — `shared/000_HARMONIE_TWA_Log.lua` |
  | HomeMedic (own HM code) | `[HARMONIE_HM]` | `HMLog`, `HMLogOnce`, `HMLogErr`, `HMLogName`, `HMLogType`, `HMLogMethods` — `shared/HARMONIEHomeMedic/000_HM_Log.lua` (bundled EHR / TOC keep their own `[EHR` / `[TOC` prints) |
  | SVU3Sandbox | `[HARMONIE_SVU3]` | local `log` / `logOnce` per file (`C.log` in SkillCap) |
  | ModernFirearmsSystemFix | `[HARMONIE_MFSFix]` | local `log` / `logOnce` per file |
  | LifestyleAudioTune | `[HARMONIE_LAT]` | local `log` / `logOnce` per file |
  | PerfProbe | `[PerfProbe` | the mod itself is a log |
- A log line must never break the game: read item / player names through
  the safe helpers (`TWALogType(item)`, `HMLogName(p)`, ...), never
  `item:getFullType()` directly inside a log call.
- Log: load or setup results (counts), every network message that is
  rejected or dropped, fallbacks taken (a missing API, a pcall failure),
  user actions in our windows, and first-time / daily summaries.
