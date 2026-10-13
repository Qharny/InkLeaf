# Releasing to Google Play and the App Store

What the code already does to meet store policy, and what still has to be
filled in by hand in Play Console and App Store Connect.

App ID on both stores: `kabuteyy.InkLeaf`, with a capital I and L. IDs are
case-sensitive, and the ID can't change after the first upload.

## Already handled in the code

- **Privacy policy:** [PRIVACY.md](../PRIVACY.md), also in the app under
  Settings → Privacy policy, and published with the rest of the website
  (see below).
- **Permissions** are asked for only when a feature is first used, and every
  iOS prompt has a purpose string. Android asks for no storage or media
  permissions (photos come through the system picker), so the Photo and Video
  Permissions policy doesn't apply.
- **Reminders** use exact alarms only when Android allows them and otherwise
  fall back to inexact ones. The app declares `SCHEDULE_EXACT_ALARM`, not the
  restricted `USE_EXACT_ALARM`, so no Play declaration is needed.
- **Target SDK** 36, which meets Play's current requirement.
- **iOS privacy manifest:** `ios/Runner/PrivacyInfo.xcprivacy` covers the
  required-reason APIs the plugins use. Swift Package Manager links them into
  the app binary.
- **Export compliance:** `ITSAppUsesNonExemptEncryption` is `false`, since the
  app uses only the operating system's standard encryption.
- **Release builds** are minified with R8 (`android/app/proguard-rules.pro`)
  and signed with your upload key (see below).

## Website

`site/` is published to GitHub Pages by `.github/workflows/pages.yml` on every
push to `main` that touches it. Use these links in both consoles:

| Page | URL |
| --- | --- |
| Home (marketing URL) | <https://qharny.github.io/InkLeaf/> |
| Privacy policy | <https://qharny.github.io/InkLeaf/privacy.html> |
| Terms of use | <https://qharny.github.io/InkLeaf/terms.html> |
| Support | <https://qharny.github.io/InkLeaf/support.html> |

The privacy policy exists in three places: `site/privacy.html`, `PRIVACY.md`
and the in-app screen. Change all three together.

## Before the first Android upload

1. Create an upload key, kept out of git:

   ```bash
   keytool -genkey -v -keystore ~/inkleaf-upload.jks -keyalg RSA \
     -keysize 2048 -validity 10000 -alias upload
   ```

2. Create `android/key.properties` (gitignored):

   ```properties
   storeFile=/home/<you>/inkleaf-upload.jks
   storePassword=...
   keyAlias=upload
   keyPassword=...
   ```

3. Build with `flutter build appbundle`, and use Play App Signing when you
   create the app.

Without `key.properties`, release builds fall back to the debug key, and Play
rejects them.

## GitHub releases

`.github/workflows/release.yml` builds signed APKs and publishes them as a
GitHub Release, so people can download Inkleaf without Play.

**One-time setup:** add the upload key from the steps above as four
repository secrets:

```bash
base64 -w0 ~/inkleaf-upload.jks | gh secret set ANDROID_KEYSTORE_BASE64
gh secret set ANDROID_KEYSTORE_PASSWORD   # prompts for the value
gh secret set ANDROID_KEY_ALIAS           # upload
gh secret set ANDROID_KEY_PASSWORD
```

Without these, the workflow stops rather than publish debug-signed APKs. A
later release couldn't install over a debug-signed APK.

**To release:**

1. Set `version:` in `pubspec.yaml`. Raise the number after `+` every time.
2. Write `release-notes/v<version>.md`: what's new and the known issues.
   It becomes the text of the release, followed by install instructions.
   The workflow stops if the file is missing.
3. Merge to `main`, then tag that commit:

   ```bash
   git tag v1.0.0 && git push origin v1.0.0
   ```

The workflow runs the tests and builds:

- a universal APK
- one APK each for arm64-v8a, armeabi-v7a and x86_64
- `SHA256SUMS.txt`

It then publishes them under Releases, with your release notes. A
tag with a suffix such as `v1.1.0-beta.1` becomes a pre-release. A
tag that doesn't match the pubspec version fails before anything is built.

To check a build without publishing, run the workflow by hand from the
Actions tab. The APKs are attached to the run.

**Play and GitHub installs don't mix.** With Play App Signing, Google
re-signs the Play version with its own key. The GitHub APKs are signed with
your upload key. Android won't update one with the other, so someone who
switches has to uninstall first and loses their notes unless they export a
backup. Say this on the release page or the website once Inkleaf is on Play.

## Play Console answers

**Data safety.** The answers come from Google ML Kit, which sends Google
diagnostics. Inkleaf itself collects nothing. Check them against
[ML Kit's data disclosure](https://developers.google.com/ml-kit/android/data-disclosure)
before submitting, in case Google has updated it.

| Question | Answer |
| --- | --- |
| Collects or shares user data? | Yes: collected, not shared |
| Data types | App info and performance → **Diagnostics**; Device or other IDs → **Device or other IDs** |
| Purpose | Analytics (ML Kit diagnostics) |
| Optional for users? | No, required |
| Processed ephemerally? | No |
| Encrypted in transit? | Yes |
| Users can request deletion? | No; there's no account, and Inkleaf holds no data |
| Audio, photos, files, messages | **Not collected.** They're processed and stored only on the device |

**Other forms.**

| Form | Answer |
| --- | --- |
| Ads | Contains no ads |
| App access | All features work without signing in. The app lock is optional and off by default |
| Target audience | 13 and over; not designed for children |
| Content rating | Fill in the IARC questionnaire: no violence, user-to-user sharing, purchases or location sharing |
| Health, finance, news, government | Not applicable |

A new personal developer account must run a closed test with at least 12
testers for 14 days before it can publish to production.

## App Store Connect answers

**App Privacy.** Data used to track you: **none**. Data not linked to you:
**Diagnostics** (Performance Data and Other Diagnostic Data), from ML Kit,
for app functionality. Nothing else is collected.

**Other answers.**

| Form | Answer |
| --- | --- |
| Privacy policy URL | https://qharny.github.io/InkLeaf/privacy.html |
| Support URL | https://qharny.github.io/InkLeaf/support.html |
| Marketing URL | https://qharny.github.io/InkLeaf/ |
| Sign-in required? | No |
| Age rating | 4+ (no objectionable content, no unrestricted web access) |
| iPad | The app supports iPad (`TARGETED_DEVICE_FAMILY = 1,2`), so upload iPad screenshots and check the layout on an iPad simulator before you submit. Otherwise, remove iPad support in Xcode |

Apple requires App Store uploads to be built with a current Xcode and SDK,
so build on an up-to-date Mac.

## Keep it true

If a change adds networking, analytics, crash reporting, accounts or ads,
update PRIVACY.md, the in-app policy, the privacy manifest and both store
forms in the same change. Store listings and marketing that say "Everything
stays on your phone" are accurate for notes and media; don't extend the claim
to "Inkleaf sends nothing anywhere," because ML Kit sends diagnostics.
