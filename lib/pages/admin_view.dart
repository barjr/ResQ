/*
  Created for admin profile landing in the meantime, 
  set up button to access the log.json to read and maybe export among other things.



 */
import 'package:flutter/material.dart';

class AdminViewPage extends StatelessWidget {
  const AdminViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text(
          'Hello Admin',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
