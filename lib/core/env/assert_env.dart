import 'package:flutter/material.dart';

import 'app_env.dart';

void assertEnv(BuildContext context, AppEnv env) {
  assert(() {
    if (!env.useMockData && !env.supabaseEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Config error: Supabase vars missing. Running in limited mode.')),
      );
    }
    return true;
  }());
}
