import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/storage/app_prefs.dart';
import 'features/canvas/data/boards_repository.dart';
import 'features/notes/data/notes_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPrefs.init();
  await NotesRepository.init();
  await BoardsRepository.init();
  runApp(const InkleafApp());
}
