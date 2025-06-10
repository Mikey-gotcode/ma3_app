import 'package:flutter/material.dart';

class SaccoReportsScreen extends StatelessWidget {
  const SaccoReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pie_chart, size: 80, color: Colors.teal),
          SizedBox(height: 20),
          Text(
            'Sacco Reports',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            'View operational reports and analytics.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
