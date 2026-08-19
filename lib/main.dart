import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

await Supabase.initialize(
  url: Env.supabaseUrl,
  publishableKey: Env.supabasePublishableKey,
);

  runApp(const HalalFoodApp());
}