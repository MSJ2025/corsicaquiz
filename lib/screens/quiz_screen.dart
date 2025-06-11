import 'package:flutter/material.dart';

class QuizScreen extends StatelessWidget {
  final String category;

  QuizScreen({required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Quiz - $category")),
      body: Center(
        child: Text(
          "Quiz de $category en préparation...",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
