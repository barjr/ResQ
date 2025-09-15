import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text("RESQ", style: TextStyle(color: Colors.white)),
        ),
        backgroundColor: Color(0xFFFC3B3C),
      ),
    );
  }
}
