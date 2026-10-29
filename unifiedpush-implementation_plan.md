# LunaSea Android: Serverless Push Notifications via UnifiedPush & Media Manager Workbench

A comprehensive implementation plan to modernize **LunaSea** (the Flutter mobile media controller for Radarr, Sonarr, and SABnzbd) by replacing its deprecated, defunct Firebase Cloud Messaging infrastructure with **UnifiedPush**. This achieves 100% serverless, private, and self-hosted push notifications directly from Radarr and Sonarr webhooks to Android devices without hosting any custom intermediate service.

---

## User Review & Critical Decisions

> [!IMPORTANT]
> **Confirmed Choices from Phase 1 Planning:**
> - **Notification Transport**: **UnifiedPush** with `ntfy` (or any user-selected distributor like NextPush). By utilizing Radarr and Sonarr's built-in Webhook integration pointing directly to the device's UnifiedPush endpoint URL, you do **not** need to self-host or maintain the retired Node.js `lunasea-notification-service` or Firebase Cloud Functions.
> - **Deliverable Structure**: **Flutter codebase patch & step-by-step modification guide**, paired with an **interactive Webhook & UnifiedPush developer workbench** in this web applet to test, validate, and dispatch payloads to real Android devices in real time.
> - **Core Scope Focus**: Prioritizing rock-solid notification delivery, background parsing for Radarr/Sonarr events (Grab, Download, Upgrade, Health), and local notification history.

---

## 1. Overview & Core Concept

- **What It Does**:
  - Replaces LunaSea's retired Firebase notification module with the open-source **UnifiedPush** standard on Android.
  - Enables Radarr, Sonarr, and SABnzbd to trigger push notifications on your Android device over simple HTTP POST webhooks with zero intermediate server software.
  - Provides a developer workbench to test Radarr and Sonarr webhook payloads, simulate notification triggers, inspect JSON structures, and verify end-to-end delivery on a mobile device running ntfy or any UnifiedPush distributor.
- **Target Persona**:
  - Self-hosters and media server administrators managing Radarr, Sonarr, and SABnzbd who want push notifications on mobile without depending on proprietary Firebase infrastructure or running an extra relay container.
- **Key Value**:
  - **Zero Server Hosting**: No container or VPS needed for notifications.
  - **Privacy & Decentralization**: Notifications route via your own ntfy instance or free public distributor without Google account ties.
  - **Rich Event Context**: Parses movie/episode titles, release quality, indexers, and file sizes directly on-device.

---

## 2. User Experience & Visual Design

### A. Android App UX (In LunaSea)
1. **Settings > Notifications > UnifiedPush**:
   - Clean status card showing current distributor state: Active distributor name (e.g., `ntfy`), connection status, and device registration key.
   - **"Register Device" / "Re-register" Action**: Registers a dedicated channel with the UnifiedPush distributor.
   - **1-Click Copy Webhook URL**: Gives the user the exact webhook endpoint URL to paste into Radarr and Sonarr (`Settings > Connect > Webhook`).
   - **Send Test Notification**: Fires a test event to verify local background notification dispatch.
2. **System Notification Experience**:
   - High-priority heads-up notification with action buttons.
   - Custom styling: Movie poster or media badge, clean title (e.g., `"Radarr: Grabbed Dune (2021) 1080p WEB-DL"`), release specs (indexer, size, quality), and deep-linking into LunaSea's movie/series view when tapped.
3. **Notification History Feed**:
   - In-app archive stored in Hive so users can review recent alerts even if dismissed from the Android notification shade.

### B. Interactive Developer Workbench UX (In This Applet)
1. **Layout Contract (SaaS & Developer Dashboard)**:
   - **Top Navigation Bar**: Single-line wordmark (`LunaSea // Push Workbench`), clean nav links (`Architecture & Flow`, `Flutter Codebase Patch`, `Webhook Simulator`, `Live Dispatcher`), and primary action (`Generate Full Patch`).
   - **3-Panel Master Workspace**:
     - **Panel 1: Architecture & Setup Guide**: Step-by-step walkthrough of file modifications for LunaSea (`pubspec.yaml`, `AndroidManifest.xml`, Dart services, models).
     - **Panel 2: Radarr/Sonarr Webhook Payload Studio**: Interactive event selector (`Grab`, `Download`, `Upgrade`, `Rename`, `Health`), visual form and raw JSON editor with pre-filled realistic media metadata.
     - **Panel 3: UnifiedPush Live Dispatcher**: Paste your device's actual UnifiedPush or ntfy endpoint URL and send live push notifications from the browser directly to your phone.
2. **Visual Identity & Theme**:
   - Match the settings UI and theme of the rest of the current project.

---

## 3. Key Product Decisions & Trade-Offs

| Decision | Chosen Approach | Rationale | Alternatives Rejected |
| :--- | :--- | :--- | :--- |
| **Push Protocol** | UnifiedPush with `ntfy` | Allows completely serverless push: Radarr/Sonarr webhooks post directly to the endpoint URL. No custom server code to host. | Self-hosting `lunasea-notification-service` Node.js server (tedious to run); Personal Firebase Project (requires Google developer account and custom build keys). |
| **Payload Decoding** | On-Device Dart Parser | Radarr & Sonarr send JSON via webhook. LunaSea's client can parse the payload upon notification reception and format it locally. | Server-side translation layer (creates another failure point and requires hosting). |
| **Local Alerts** | `flutter_local_notifications` | Native Android notification channels, heads-up alerts, notification grouping, and custom sound/vibration profiles. | Basic Android toast (poor UX, missed alerts). |
| **Persistence** | Local Hive Box (`notifications`) | Native to LunaSea's existing Hive architecture; zero migration overhead, fast key-value storage. | SQLite (adds unnecessary dependency when Hive is already present). |

---

## 4. Technical Architecture & Data Strategy

### System Flow Diagram

```
┌─────────────────────────────────┐
│   Media Server (*arr Stack)     │
│   • Radarr (Movie grabbed/dl)   │
│   • Sonarr (Episode grabbed/dl) │
│   • SABnzbd (Queue completed)   │
└────────────────┬────────────────┘
                 │ HTTP POST Webhook
                 │ Payload: { eventType, movie/series, release, ... }
                 ▼
┌─────────────────────────────────┐
│     UnifiedPush Distributor     │
│     (e.g., ntfy.sh or self-host)│
│     Endpoint: https://ntfy.sh/..│
└────────────────┬────────────────┘
                 │ WebPush / UP Android Broadcast
                 │ Action: org.unifiedpush.flutter.connector.MESSAGE
                 ▼
┌────────────────────────────────────────────────────────┐
│               Android Device (LunaSea)                 │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 1. UnifiedPush Receiver (Background Service)     │  │
│  │    • Receives raw string/JSON payload            │  │
│  └──────────────────────────┬───────────────────────┘  │
│                             ▼                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 2. LunaSea Payload Parser                        │  │
│  │    • Detects source (Radarr vs Sonarr vs SAB)    │  │
│  │    • Extracts title, quality, release group, size│  │
│  └──────────────────────────┬───────────────────────┘  │
│                             ▼                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 3. Dispatch & Storage                            │  │
│  │    • flutter_local_notifications (System Shade)  │  │
│  │    • Hive Box 'notifications' (In-App History)   │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

### Exact Flutter Codebase Modifications Required

1. **`pubspec.yaml`**:
   - Add `unifiedpush: ^2.1.2`
   - Ensure `flutter_local_notifications: ^17.0.0` or compatible version is declared.
   - Remove deprecated `firebase_messaging` dependencies.
2. **`android/app/src/main/AndroidManifest.xml`**:
   - Register UnifiedPush receiver broadcast filters:
     ```xml
     <receiver android:name="org.unifiedpush.flutter.connector.PluginReceiver"
         android:exported="true">
         <intent-filter>
             <action android:name="org.unifiedpush.android.connector.MESSAGE"/>
             <action android:name="org.unifiedpush.android.connector.UNREGISTERED"/>
             <action android:name="org.unifiedpush.android.connector.NEW_ENDPOINT"/>
             <action android:name="org.unifiedpush.android.connector.REGISTRATION_FAILED"/>
         </intent-filter>
     </receiver>
     ```
3. **`lib/core/services/unifiedpush_service.dart`**:
   - UnifiedPush initialization, callback registration (`onNewEndpoint`, `onMessage`, `onUnregistered`).
   - Endpoint caching in Hive settings.
4. **`lib/core/models/notification/unifiedpush_payload.dart`**:
   - Model parsing Radarr events (`Grab`, `Download`, `Rename`, `MovieDelete`, `Health`, `Test`).
   - Model parsing Sonarr events (`Grab`, `Download`, `Rename`, `SeriesDelete`, `EpisodeFileDelete`, `Health`, `Test`).
   - Model parsing SABnzbd completion webhooks.
5. **`lib/modules/settings/routes/notifications/unifiedpush_settings.dart`**:
   - Dedicated configuration screen with status indicator, distributor picker, endpoint copy button, and test trigger.

---

## 5. Implementation Roadmap & Deliverables

1. **Interactive Workbench & Testing Suite (Immediate Build)**:
   - Build the interactive web applet providing:
     - Real-time **Webhook Simulator & Tester** (send actual HTTP requests from browser to any ntfy/UnifiedPush endpoint).
     - **Interactive Patch Explorer**: Full, copyable Dart files, `AndroidManifest.xml` diffs, and `pubspec.yaml` snippets ready to drop into your cloned `lunasea` repository.
     - **Radarr & Sonarr Config Generator**: Generates the exact URL, headers, and test payloads to configure in Radarr/Sonarr settings.
2. **Step-by-Step Fork Guide**:
   - Clear instructions on checking out LunaSea, applying the patch, testing on an Android device or emulator with ntfy, and building the APK via `flutter build apk`.
