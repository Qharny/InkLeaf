# Inkleaf privacy policy

_Last updated: 22 November 2026_

Inkleaf is a notebook app. It has no accounts, no ads and no analytics of its
own. Your notes stay on your phone. This is the same text the app shows under
**Settings → Privacy policy**, and the published copy is at
<https://qharny.github.io/InkLeaf/privacy.html>.

## What Inkleaf keeps, and where

Your notes, checklists, sketches, canvases, collections, voice recordings,
scanned pages, reminders and settings are saved only in Inkleaf's private
storage on your device. The developer never receives them, and there is no
Inkleaf server. Deleting the app deletes them.

If you've turned on your phone's own backup (Google backup on Android, iCloud
on iPhone), that backup may include Inkleaf's data. It's handled by Google or
Apple under your account and their privacy policies.

## Permissions

Inkleaf asks for each permission only when you first use the feature that
needs it, and you can say no and keep using the rest of the app.

- **Microphone:** used only while you record a voice note.
- **Camera and photos:** used only when you scan a page or pick a photo to
  scan.
- **Notifications:** used to show the reminders you set.
- **Alarms & reminders (Android):** lets reminders arrive on the minute.
- **Fingerprint or face:** used for the optional app lock. Your phone checks
  it; Inkleaf never sees your fingerprint or face data.
- **Internet (Android):** used only to download the speech model for voice
  transcription, when you ask for it. Android grants this without asking.

## Text recognition (Google ML Kit)

Inkleaf uses Google's ML Kit to read the text in pages you scan. Recognition
runs entirely on your device. Your photos and the recognised text are never
sent anywhere.

ML Kit itself sends Google a small amount of diagnostic information so Google
can maintain and improve it: details such as the device model, operating
system and app version, an identifier for this installation of the app, which
ML Kit features were used, and error and performance figures. It doesn't
include your notes, photos, recordings or any text. See
[Google's ML Kit data disclosure](https://developers.google.com/ml-kit/android/data-disclosure)
and [Google's privacy policy](https://policies.google.com/privacy).

## Voice transcription (Whisper)

Inkleaf can turn your voice recordings into text with Whisper, a speech
recognition model that runs on your device. It's off until you ask for a
transcript or turn it on in Settings.

The model is too large to include in the app, so the first time, Inkleaf
downloads it (about 142 MB) from Hugging Face (huggingface.co). That
download is the only thing transcription uses the internet for. Your
recordings and their text are never uploaded. Like any download, the request
shows Hugging Face your device's IP address; see
[Hugging Face's privacy policy](https://huggingface.co/privacy). You can
delete the model under **Settings → Voice notes**.

## Sharing and backups

Inkleaf only sends something out of the app when you ask it to: sharing a
note, or exporting a backup `.zip` through your phone's share sheet. It goes
wherever you choose to send it.

## Children

Inkleaf isn't directed at children and doesn't knowingly collect any personal
information from anyone, including children.

## Changes

If this policy changes, the new version will be published at
<https://qharny.github.io/InkLeaf/privacy.html> and in the app, with a new date at the top.

## Contact

Questions about this policy: open an issue at
<https://github.com/Qharny/InkLeaf/issues>.
