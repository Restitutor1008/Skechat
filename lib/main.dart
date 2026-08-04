import 'package:flutter/material.dart';

import 'app.dart';
import 'core/startup_profiler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  StartupProfiler.start();
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => StartupProfiler.mark('first_flutter_frame'),
  );
  runApp(const SkeChatApp());
}
