import 'package:flutter/material.dart';

class SignupPage extends StatelessWidget {
  const SignupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Navigate to the home page after sign up
            // Navigator.pushReplacement(
            //   context,
            //   MaterialPageRoute(builder: (context) => const Home()),
            // );
          },
          child: const Text('Go to Home'),
        ),
      ),
    );
  }
}
