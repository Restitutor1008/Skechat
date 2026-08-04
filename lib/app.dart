import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/repositories/todo_repository.dart';
import 'providers/repository_provider.dart';
import 'views/home_view.dart';

class SkeChatApp extends StatelessWidget {
  const SkeChatApp({super.key, this.repository});

  final TodoRepository? repository;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        if (repository != null)
          todoRepositoryProvider.overrideWithValue(repository!),
      ],
      child: MaterialApp(
        title: 'SkeChat',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1AA36F)),
          scaffoldBackgroundColor: const Color(0xFFF8F7FC),
          useMaterial3: true,
        ),
        home: const HomeView(),
      ),
    );
  }
}
