# Play Store listing

The text for the Google Play store listing (en-US). Keep it in sync with
what the app actually does: Play rejected an earlier description under the
Metadata policy for not describing the app's core functionality clearly.

When a feature ships, is removed or changes, update this file and the Play
Console listing together. See [store-release.md](store-release.md) for the
privacy wording rules (don't claim the app sends nothing anywhere; ML Kit
sends diagnostics).

## App name

```
Inkleaf
```

Optionally `Inkleaf: Notes, Sketches & Scans`. Don't add keyword lists.

## Short description

78 characters (limit 80).

```
Notes, checklists, sketches, voice notes and page scans, stored on your phone.
```

## Full description

About 3,400 characters (limit 4,000).

```
Inkleaf is a note-taking app for Android. You can write text notes, make checklists, draw sketches, record voice notes and turn them into text, and scan paper pages into searchable text. You can then sort your notes into collections, link them to each other, set reminders and lay them out on a canvas. No account is needed, and apart from an optional one-time download for transcription, everything works offline. Your notes are stored in a database on your phone.

WRITE AND CAPTURE
• Text notes with titles, tags, colors and pinning. Changes save as you type.
• Formatting: headings, bold, italic, strikethrough and lists, from a toolbar above the keyboard.
• Templates for a daily journal, meeting notes, a packing list, a recipe or a to-do list.
• Checklists: tap an item to cross it off. Each note card shows your progress, such as "2/4 done".
• Sketches: draw on a full-screen pad with pens, colors and an eraser.
• Voice notes: record audio with a live level meter, then play it back and skip to any point.
• Transcripts: tap Transcribe on a voice note to turn what you said into text in the note, where you can edit and search it. The recording stays attached. Transcription runs on your phone, and you can set it to run on every new recording. The first time, the app asks before downloading the speech model (142 MB).
• Page scanning: take a photo of a page or receipt. The app reads the text on your phone and adds it to a note, where you can edit and search it. The photo is kept with the note.
• Share to Inkleaf: text, links and photos you share from other apps become a new note.
• Home-screen widget: create a note, checklist, voice note or scan in one tap, and see your pinned notes.

ORGANIZE
• Links between notes: type [[ to link to another note. Each note lists the notes it links to and the notes that link back to it.
• Collections: group notes into folders and drag to reorder them. A note can be in more than one collection.
• Canvas: place sticky notes and your own notes on a board, connect them with arrows and draw around them. Pan, zoom, undo and redo.
• Reminders: set a time on any note and get a notification, even when the app is closed. Tap the notification to open the note.

FIND IT AGAIN
• Search across titles, text, transcripts, scanned pages, checklist items and tags (for example #travel). Matches are highlighted, and recent searches are remembered.

KEEP IT SAFE
• App lock: open the app with your fingerprint, face or a PIN. The lock is optional and off by default.
• Backup and restore: export all your notes, recordings and scans as one .zip file. A restore merges the backup into your notebook and never overwrites newer work.
• Trash: deleted notes go to the trash, and every delete can be undone for 3 seconds.

DESIGN
Inkleaf looks like a paper sketchbook, with cream pages, charcoal ink and hand-drawn outlines. A dark theme is available, or the app can follow your system setting. Animations are turned off when your phone's reduce-motion setting is on.

PRIVACY
Inkleaf has no ads and no sign-in. Your notes, recordings and photos are stored only on your phone. Voice transcription runs on your phone, and recordings are never uploaded. The internet is used only to download the speech model, after you agree. The text-recognition component used for page scanning sends anonymous diagnostic data, as described in the privacy policy.
```

## Graphics

- **Screenshots:** real in-app screens only, of features the description
  lists. `docs/screenshots/` has home, editor, collections, canvas, search
  and dark-theme shots. No mockups, no text the app doesn't show, no other
  apps' logos.
- **Feature graphic:** no claims like "#1" or "best", and no other brands'
  logos.

## Not yet in the listing

- Drawing tutorials (`lib/features/tutorials/`): add a bullet under
  WRITE AND CAPTURE once they ship.
