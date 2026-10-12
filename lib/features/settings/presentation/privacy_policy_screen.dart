import 'package:flutter/material.dart';

import '../../../app/theme/sketch_styles.dart';

/// The privacy policy, readable offline. Keep in step with PRIVACY.md and
/// site/privacy.html.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const updated = '12 October 2026';

  static const _sections = <(String, List<String>)>[
    (
      'What Inkleaf keeps, and where',
      [
        'Your notes, checklists, sketches, canvases, collections, voice '
            'recordings, scanned pages, reminders and settings are saved only '
            "in Inkleaf's private storage on your device. The developer never "
            'receives them, and there is no Inkleaf server. Deleting the app '
            'deletes them.',
        "If you've turned on your phone's own backup (Google backup on "
            "Android, iCloud on iPhone), that backup may include Inkleaf's "
            "data. It's handled by Google or Apple under your account and "
            'their privacy policies.',
      ],
    ),
    (
      'Permissions',
      [
        'Inkleaf asks for each permission only when you first use the feature '
            'that needs it, and you can say no and keep using the rest of the '
            'app.',
        'Microphone: used only while you record a voice note.',
        'Camera and photos: used only when you scan a page or pick a photo to '
            'scan.',
        'Notifications: used to show the reminders you set.',
        'Alarms & reminders (Android): lets reminders arrive on the minute.',
        'Fingerprint or face: used for the optional app lock. Your phone '
            'checks it; Inkleaf never sees your fingerprint or face data.',
      ],
    ),
    (
      'Text recognition (Google ML Kit)',
      [
        "Inkleaf uses Google's ML Kit to read the text in pages you scan. "
            'Recognition runs entirely on your device. Your photos and the '
            'recognised text are never sent anywhere.',
        'ML Kit itself sends Google a small amount of diagnostic information '
            'so Google can maintain and improve it: details such as the device '
            'model, operating system and app version, an identifier for this '
            'installation of the app, which ML Kit features were used, and '
            "error and performance figures. It doesn't include your notes, "
            'photos, recordings or any text. More at '
            'developers.google.com/ml-kit/android/data-disclosure and '
            'policies.google.com/privacy.',
      ],
    ),
    (
      'Sharing and backups',
      [
        'Inkleaf only sends something out of the app when you ask it to: '
            "sharing a note, or exporting a backup .zip through your phone's "
            'share sheet. It goes wherever you choose to send it.',
      ],
    ),
    (
      'Children',
      [
        "Inkleaf isn't directed at children and doesn't knowingly collect any "
            'personal information from anyone, including children.',
      ],
    ),
    (
      'Changes',
      [
        'If this policy changes, the new version will be published in the app '
            'and at qharny.github.io/InkLeaf/privacy.html, with a new date at '
            'the top.',
      ],
    ),
    (
      'Contact',
      [
        'Questions about this policy: open an issue at '
            'github.com/Qharny/InkLeaf/issues.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final soft = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy policy')),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'Last updated: $updated',
              style: text.bodyMedium?.copyWith(color: soft),
            ),
            const SizedBox(height: 12),
            Text(
              'Inkleaf is a notebook app. It has no accounts, no ads and no '
              'analytics of its own. Your notes stay on your phone.',
              style: text.bodyLarge,
            ),
            for (final (title, paragraphs) in _sections) ...[
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: MarkerHighlight(
                  child: Text(title, style: text.titleMedium),
                ),
              ),
              for (final p in paragraphs) ...[
                const SizedBox(height: 8),
                Text(p, style: text.bodyLarge),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
