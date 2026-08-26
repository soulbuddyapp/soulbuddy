# SoulBuddy App Icon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the default Flutter Android launcher icon with the approved SoulBuddy remembrance-tablet mark and install the rebuilt app on connected physical devices.

**Architecture:** Keep a square master PNG beside the Android application resources and derive the five standard launcher mipmaps from it. Preserve the existing manifest reference so the package identity and launch behavior do not change.

**Tech Stack:** Flutter, Android mipmap resources, Pillow, ADB

---

### Task 1: Add and derive the launcher artwork

**Files:**
- Create: `apps/soulbuddy/android/app/src/main/icon/soulbuddy_launcher_master.png`
- Modify: `apps/soulbuddy/android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
- Modify: `apps/soulbuddy/android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
- Modify: `apps/soulbuddy/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
- Modify: `apps/soulbuddy/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
- Modify: `apps/soulbuddy/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`

- [ ] **Step 1: Copy the approved square master into the Android source tree**

Copy the generated opaque 1:1 artwork to `apps/soulbuddy/android/app/src/main/icon/soulbuddy_launcher_master.png` without modifying the generated original.

- [ ] **Step 2: Verify the master is square and fully opaque**

Run Pillow inspection and require matching width/height with `RGB` or fully opaque `RGBA` mode.

- [ ] **Step 3: Generate Android density resources**

Resize with Lanczos sampling to 48, 72, 96, 144, and 192 pixels for mdpi through xxxhdpi.

- [ ] **Step 4: Verify every generated resource**

Run Pillow inspection and require exact sizes:

```text
mdpi: 48x48
hdpi: 72x72
xhdpi: 96x96
xxhdpi: 144x144
xxxhdpi: 192x192
```

- [ ] **Step 5: Commit the launcher resources**

```bash
git add apps/soulbuddy/android/app/src/main/icon apps/soulbuddy/android/app/src/main/res/mipmap-*/ic_launcher.png
git commit -m "feat: add SoulBuddy launcher icon"
```

### Task 2: Build and install

**Files:**
- Verify: `apps/soulbuddy/build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 1: Run static analysis**

Run `flutter analyze` from `apps/soulbuddy` and require `No issues found`.

- [ ] **Step 2: Build the Android APK**

Run `flutter build apk --debug` from `apps/soulbuddy` and require a successful `app-debug.apk` build.

- [ ] **Step 3: Identify physical Android devices**

Run `adb devices -l` and exclude emulator serials.

- [ ] **Step 4: Install on each physical device**

For every connected physical serial, run `adb -s <serial> install -r <absolute-apk-path>` and require `Success`.

- [ ] **Step 5: Launch and verify the process**

Launch `app.soulbuddy.soulbuddy` with the Android launcher category and require `pidof app.soulbuddy.soulbuddy` to return a process ID on every installed device.

- [ ] **Step 6: Push the completed change**

```bash
git push origin main
```
