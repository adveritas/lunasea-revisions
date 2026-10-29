# Building LunaSea Android with UnifiedPush

Follow these steps on your development machine (Linux, macOS, or Windows with WSL/Flutter installed):

### 1. Clone the LunaSea Repository
```bash
git clone https://github.com/jagandeepbrar/lunasea.git
cd lunasea
git checkout -b feature/unifiedpush-android
```

### 2. Update Dependencies
Copy the `pubspec.yaml` additions and run:
```bash
flutter pub get
```

### 3. Apply the UnifiedPush Code Files
Place the following files in the project:
- `android/app/src/main/AndroidManifest.xml` (add receiver)
- `lib/core/services/unifiedpush_service.dart` (core push service)
- `lib/core/models/notification/unifiedpush_payload.dart` (payload parser)
- `lib/modules/settings/routes/notifications/unifiedpush_settings.dart` (UI route)

### 4. Initialize UnifiedPush in `lib/main.dart`
Inside the `main()` function of `lib/main.dart`, initialize the service after Hive:
```dart
void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  
  // Initialize serverless UnifiedPush notifications
  await UnifiedPushService().initialize();
  
  // Only launch full UI app if not triggered purely as a headless background push receiver
  if (!args.contains("--unifiedpush-bg")) {
    runApp(const LunaSeaApp());
  }
}
```

### 5. Install a UnifiedPush Distributor on Android
On your physical phone or Android emulator, install any distributor:
- **ntfy** (F-Droid or Google Play: `io.heckel.ntfy`) — Recommended
- **NextPush** (F-Droid)

### 6. Build and Install the APK
```bash
# Build release APK
flutter build apk --release

# Or run directly on connected device:
flutter run --release
```

When LunaSea opens, navigate to **Settings > Notifications > UnifiedPush**, select your distributor, and copy your instant webhook URL!

