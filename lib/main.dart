import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/storage/app_database.dart';
import 'core/storage/app_prefs.dart';
import 'core/storage/media_store.dart';
import 'features/canvas/data/boards_repository.dart';
import 'features/collections/data/collections_repository.dart';
import 'features/lock/data/app_lock.dart';
import 'features/notes/data/notes_repository.dart';
import 'features/reminders/data/reminders.dart';
import 'features/share/data/share_inbox.dart';
import 'features/widget/home_screen_widget.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The fonts ship with the app (assets/google_fonts), so never fetch them.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    for (final (family, file) in [
      ('Kalam', 'Kalam-OFL.txt'),
      ('Patrick Hand', 'PatrickHand-OFL.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString('assets/google_fonts/$file'));
    }
  });
  await AppPrefs.init();
  AppLock.instance.init();
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
  await HomeScreenWidget.instance.start();
  runApp(const InkleafApp());
}
