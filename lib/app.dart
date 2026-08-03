import 'package:flutter/material.dart';

import 'data/repositories/todo_repository.dart';
import 'data/services/api_service.dart';
import 'viewmodels/home_view_model.dart';
import 'views/home_view.dart';

class SkeChatApp extends StatelessWidget {
  const SkeChatApp({super.key, this.repository});

  final TodoRepository? repository;

  @override
  Widget build(BuildContext context) {
    final todoRepository = repository ?? TodoRepository(ApiService());
    return MaterialApp(
      title: 'SkeChat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1AA36F)),
        scaffoldBackgroundColor: const Color(0xFFF8F7FC),
        useMaterial3: true,
      ),
      home: HomeView(viewModel: HomeViewModel(todoRepository)),
    );
  }
}
