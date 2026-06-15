# Firebase setup

The game runs fully offline with `GameConfig.enableFirebase = true` but no
config (it fails soft). Follow these steps to enable cloud save, anonymous
auth, leaderboard, analytics, and remote config.

## 1. Create the project
1. Go to the [Firebase console](https://console.firebase.google.com/) → **Add
   project**.
2. Name it (e.g. *Chicken Hunter Space War*). Enable Google Analytics.

## 2. Install the CLI tooling
```bash
dart pub global activate flutterfire_cli
npm install -g firebase-tools
firebase login
```

## 3. Configure the apps
From the project root:
```bash
flutterfire configure
```
- Select your Firebase project.
- Choose the **android** platform (use applicationId `com.chickenhunter.spacewar`).
- This generates `lib/firebase_options.dart` and downloads
  `android/app/google-services.json`.

> Both files are **gitignored** — keep them out of source control.

## 4. Enable the Google Services Gradle plugin
In `android/app/build.gradle`, uncomment:
```gradle
id "com.google.gms.google-services"
```
(The classpath is already declared in `android/settings.gradle`.)

## 5. Initialise Firebase in code
`FirebaseService.init()` already calls `Firebase.initializeApp()`. After
`flutterfire configure`, update it to pass the generated options:
```dart
import '../firebase_options.dart';
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```

## 6. Enable the products you use
In the Firebase console:
- **Authentication** → Sign-in method → enable **Anonymous**.
- **Firestore Database** → Create database (production mode).
- **Remote Config** → add the keys from `assets/data/balance.json`.
- **Analytics** is on by default.

## 7. Firestore security rules
Start strict — players may only read/write their own save, and leaderboard
writes are validated. Example:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Each player can only touch their own save document.
    match /saves/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }

    // Leaderboard: read all, write only your own row, scores sanity-checked.
    match /leaderboard/{uid} {
      allow read: if true;
      allow write: if request.auth != null
                   && request.auth.uid == uid
                   && request.resource.data.score is int
                   && request.resource.data.score >= 0
                   && request.resource.data.score < 100000000;
    }
  }
}
```

> For a competitive launch, validate scores server-side (Cloud Functions) — the
> client should never be fully trusted with leaderboard numbers or IAP grants.

## 8. Verify
```bash
flutter run
```
Open **Settings → Cloud Save Now**; you should see a signed-in UID, and a
`saves/{uid}` document should appear in Firestore.
