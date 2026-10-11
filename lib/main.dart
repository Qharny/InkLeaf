import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/storage/app_database.dart';
import 'core/storage/app_prefs.dart';
import 'core/storage/media_store.dart';
import 'features/canvas/data/boards_repository.dart';
import 'features/collections/data/collections_repository.dart';
import 'features/notes/data/notes_repository.dart';
import 'features/reminders/data/reminders.dart';
import 'features/share/data/share_inbox.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPrefs.init();
  await MediaStore.init();
  await AppDatabase.open();
  await AppDatabase.instance.importLegacy(
    await SharedPreferences.getInstance(),
  );
  await NotesRepository.init();
  await BoardsRepository.init();
  await CollectionsRepository.init();
  await ShareInbox.instance.start();
  await Reminders.instance.init(PluginReminderScheduler());
  runApp(const InkleafApp());
}
