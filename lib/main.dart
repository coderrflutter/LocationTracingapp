import 'package:flutter/material.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final viewModel = await bootstrap();
  runApp(LocationTrackerApp(viewModel: viewModel));
}
