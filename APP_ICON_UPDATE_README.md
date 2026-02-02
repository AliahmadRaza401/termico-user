# App Icon Not Updating – Fix Guide

## Why the icon didn’t change

On **Android 8+ (API 26+)**, the launcher uses the **adaptive icon** from `mipmap-anydpi-v26/`, which is built from:

- **Foreground:** `@drawable/ic_launcher_foreground`  
  → files in `drawable-hdpi/`, `drawable-mdpi/`, `drawable-xhdpi/`, `drawable-xxhdpi/`, `drawable-xxxhdpi/`
- **Background:** `@color/ic_launcher_background` in `values/colors.xml`

The **mipmap** PNGs (`mipmap-hdpi/ic_launcher.png`, etc.) are only used on **older** devices (below API 26).  
So if you only replaced the mipmap PNGs, the icon on newer phones will not change.

---

## Option A: You want the new icon on Android 8+ as well

Update the **foreground** drawables that the adaptive icon uses:

1. **Replace these files** with your new icon (same image, different sizes):

   - `android/app/src/main/res/drawable-mdpi/ic_launcher_foreground.png`     (48×48 px)
   - `android/app/src/main/res/drawable-hdpi/ic_launcher_foreground.png`    (72×72 px)
   - `android/app/src/main/res/drawable-xhdpi/ic_launcher_foreground.png`   (96×96 px)
   - `android/app/src/main/res/drawable-xxhdpi/ic_launcher_foreground.png`  (144×144 px)
   - `android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png` (192×192 px)

2. **Optional:** Change the adaptive icon background:
   - Edit `android/app/src/main/res/values/colors.xml`
   - Update `ic_launcher_background` to the color you want.

3. Then do **Option B** (clean build and reinstall).

---

## Option B: Clean build and reinstall (cache / build issues)

Even if the correct files are in place, the build or launcher can keep showing the old icon.

1. **Clean and get packages**
   ```bash
   flutter clean
   flutter pub get
   ```

2. **Uninstall the app** from the device/emulator  
   (Launchers cache icons; uninstall forces them to reload.)

3. **Rebuild and install**
   ```bash
   flutter run
   ```
   or build an APK/App Bundle and install that.

4. **If it still shows the old icon:**  
   Restart the device or emulator, then open the app list again.

---

## Summary

| What you updated        | Effect on Android 8+                  | What to do |
|-------------------------|--------------------------------------|------------|
| Only mipmap PNGs        | No change (adaptive icon is used)   | Update `drawable-*dpi/ic_launcher_foreground.png` (Option A) |
| Both mipmap + drawable  | Should update                        | Do Option B (clean + uninstall + reinstall) |
| Already correct files   | Cache / build issue                 | Do Option B |

---

## Your current setup

- **Manifest icon:** `@mipmap/ic_launcher`
- **Adaptive icon (API 26+):**  
  `res/mipmap-anydpi-v26/ic_launcher.xml` →  
  foreground: `@drawable/ic_launcher_foreground`,  
  background: `@color/ic_launcher_background`

To see your new icon on Android 8+:

1. Put the new icon into all `drawable-*dpi/ic_launcher_foreground.png` files (Option A), **and**
2. Run `flutter clean`, uninstall the app, then rebuild and install (Option B).
