# Deployment guide (Google Play)

## 0. Prerequisites
- Flutter 3.19+ and Android SDK installed (`flutter doctor` all green).
- A Google Play Developer account ($25 one-time).
- (Optional but recommended) Firebase configured — see `FIREBASE_SETUP.md`.

## 1. App identity
- Package / applicationId: `com.chickenhunter.spacewar` (set in
  `android/app/build.gradle`). Change it before first upload if you want your
  own — it can never change after publishing.
- App name: edit `android:label` in `AndroidManifest.xml`.
- Version: bump `version:` in `pubspec.yaml` (format `name+build`, e.g.
  `1.0.1+2`). The build number must increase every upload.

## 2. App icon & splash
- Add icons with [`flutter_launcher_icons`] or place them under
  `android/app/src/main/res/mipmap-*`.
- Splash logo: drop a bitmap into `launch_background.xml` (commented stub
  provided).

## 3. AdMob
1. Create an app + ad units in the [AdMob console](https://admob.google.com/).
2. Replace the **test** IDs in `lib/config/game_config.dart`
   (`admobAppIdAndroid`, `bannerAdUnitId`, `interstitialAdUnitId`,
   `rewardedAdUnitId`).
3. Replace the AdMob app id `meta-data` value in `AndroidManifest.xml`.
4. Never click your own live ads — it can get you banned.

## 4. In-app purchases
1. In Play Console → **Monetize → Products → In-app products / Subscriptions**,
   create products with IDs matching `GameConfig.iapProductIds`:
   `remove_ads`, `gems_500`, `gems_1200`, `gems_3000`, `battle_pass_season`,
   `starter_pack`.
2. Upload a build to a test track and add license testers to test purchases.
3. **Recommended:** verify purchases server-side (Play Developer API via a
   Cloud Function) before granting — wire it in `IapService.serverVerify`.

## 5. Signing the release
```bash
# Generate an upload keystore (once):
keytool -genkey -v -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Configure signing:
cp android/key.properties.example android/key.properties
#   then edit android/key.properties with your passwords/alias/path
```
`android/key.properties` and the `.jks` are gitignored. Keep them safe — losing
the key means you can't update the app (unless using Play App Signing).

## 6. Build the release bundle
```bash
flutter clean
flutter pub get
flutter build appbundle --release        # produces build/app/outputs/bundle/release/app-release.aab
```
For local testing of the release build:
```bash
flutter build apk --release
flutter install
```

## 7. Performance / size checks
- `flutter build appbundle --analyze-size` to inspect the size breakdown.
- Test on a **low-end** device (2 GB RAM). If frames drop, lower
  `GameConfig.particleBudget` and `starCount`.
- R8/resource shrinking is already enabled for release in `app/build.gradle`.

## 8. Play Console listing
- Create the app, fill store listing (title, short/full description,
  screenshots, feature graphic).
- Complete: content rating, data safety form (declare Ads, Analytics, and any
  data sent to Firebase), target audience, privacy policy URL.
- Upload the `.aab` to **Internal testing** first, validate, then promote to
  **Production**.

## 9. Live-ops after launch
- Tune difficulty/economy/events live via **Firebase Remote Config** (keys in
  `assets/data/balance.json`) — no app update needed.
- Watch **Analytics** funnels (run start, run over, purchases) and **Crashlytics**
  (add `firebase_crashlytics` for crash monitoring).
- Rotate battle-pass seasons and weekly events to drive retention.

## Release checklist
- [ ] applicationId finalised
- [ ] Real AdMob IDs in code + manifest
- [ ] IAP products created & tested
- [ ] Firebase configured, security rules deployed
- [ ] Upload keystore created & `key.properties` set
- [ ] Icon + splash added
- [ ] Version bumped
- [ ] Tested on low-end + high-end devices
- [ ] `.aab` built and uploaded to a test track
