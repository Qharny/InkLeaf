import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/storage/app_prefs.dart';
import 'core/storage/audio_store.dart';
import 'features/canvas/data/boards_repository.dart';
import 'features/collections/data/collections_repository.dart';
import 'features/notes/data/notes_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPrefs.init();
  await AudioStore.init();
  await NotesRepository.init();
  await BoardsRepository.init();
  await CollectionsRepository.init();
  runApp(const InkleafApp());
}
