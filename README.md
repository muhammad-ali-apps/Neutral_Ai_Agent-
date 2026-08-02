# Neutral AI Agent UI (Flutter — design-only prototype)

This is a **UI-only** Flutter project for the NeuroRoute FYP. No LLM/backend
API is connected anywhere. The only "real" functionality is the device
camera / gallery / file picker used by the attach button in the chat input
bar (via `image_picker` and `file_picker`) — everything else (routing
decisions, model responses, login/signup, OTP) is fake/dummy data for
demonstration purposes.

## 1. First-time setup

This zip only contains `lib/`, `pubspec.yaml`, and `assets/` — it does **not**
include the `android/`, `ios/`, or `web/` platform folders. To turn it into a
runnable project:

```bash
# from an empty folder
flutter create .
# then copy/overwrite lib/, pubspec.yaml and assets/ from this zip into it
flutter pub get
flutter run              # or: flutter run -d chrome
```

## 2. Camera / Gallery / File picker permissions

Because the attach button uses **real** device pickers, you must add
permissions once `android/` and `ios/` exist:

### Android — `android/app/src/main/AndroidManifest.xml`
Add inside `<manifest>` (above `<application>`):
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
```

### iOS — `ios/Runner/Info.plist`
Add inside the outer `<dict>`:
```xml
<key>NSCameraUsageDescription</key>
<string>NeuroRoute needs camera access to attach photos to a prompt.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>NeuroRoute needs photo library access to attach screenshots/images.</string>
```

Without these, the camera/gallery pickers will fail or the OS will silently
deny access.

### "Camera" is opening a file browser instead of the camera

The code itself calls the correct API for a real camera capture
(`ImagePicker().pickImage(source: ImageSource.camera)` — this is different
from `ImageSource.gallery`, which is what the "Screenshot" button uses).
If it's still opening a file/gallery picker instead of the camera, it's
almost always one of these:

1. **Missing the `CAMERA` permission** above — without it, some Android
   builds silently fall back to the gallery picker instead of erroring.
2. **Testing on Chrome/desktop web** — browsers don't have a native camera
   app; `ImageSource.camera` on web opens the OS's own camera-or-file
   chooser (this is a browser limitation, not something the app controls).
   It works as a real camera capture on **mobile Chrome/Safari** and on
   native Android/iOS builds.
3. **Android emulator without a virtual camera enabled** — in Android
   Studio's AVD Manager, edit the emulator and set "Camera: Back" to
   "Webcam0" (or "Emulated"), otherwise Android reports no camera and
   quietly opens the gallery instead.
4. Run `flutter clean && flutter pub get` after adding the manifest
   permission — Android caches manifest merges and won't pick up the new
   permission until a clean rebuild.

If it still doesn't work after checking all four, test on a **real Android
phone** — that's the most reliable way to confirm the camera path works,
since emulators/web have the caveats above.


## 3. Adding your own fonts

1. Drop `.ttf` / `.otf` files into `assets/fonts/`.
2. Uncomment and edit the `fonts:` block in `pubspec.yaml` to match your
   font's family name and each file's weight.
3. Set `fontFamily: 'YourFontName'` inside `lib/app_theme.dart` (both
   `AppTheme.dark()` and `AppTheme.light()`) to apply it app-wide.

## 4. Adding your own images

Drop image files into `assets/images/` — the folder is already declared in
`pubspec.yaml`, so they'll be available via `Image.asset('assets/images/your_file.png')`
anywhere in the app.

## 5. What's real vs. dummy — quick reference

| Feature                          | Status                                          |
|-----------------------------------|--------------------------------------------------|
| Login / Signup / Forgot / OTP     | UI + field validation only, no backend/auth       |
| Google / GitHub sign-in buttons   | UI only, no OAuth                                 |
| Smart Routing "best model" pick   | Random (from **active** models only), fake        |
| Comparison responses              | Static placeholder text                           |
| Offline / Ollama connection       | Fake delay + dummy model list                     |
| Camera / Screenshot / Project     | **Real** device pickers (image_picker/file_picker)|
| Edit / Copy / Regenerate prompt   | Real (in-memory) — edit re-triggers a dummy reply |
| Per-mode chat history (main sidebar)| Real, but in-memory only (resets on app restart)  |
| Models: add/rename/toggle (Admin) | Real, shared instantly with Smart Routing/Comparison |
| Avatar / account name in sidebar  | Static placeholder ("Muhammad Ali")               |

Everywhere a real backend needs to be wired in, look for functions like
`_send()`, `_login()`, `_connect()` etc. — replace the `Future.delayed(...)`
fake-network-call block with a real API call and keep the same `setState`
shape.
