import 'package:flutter/material.dart';

class QuizScreen extends StatelessWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: const Center(
        child: Text(
          'Quiz Screen - En construction',
          style: TextStyle(
            fontSize: 24,
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.w600,
            color: Color(0xFF344356),
          ),
        ),
      ),
    );
  }
} 