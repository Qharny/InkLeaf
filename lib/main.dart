import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/storage/app_prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPrefs.init();
  runApp(const InkleafApp());
}
