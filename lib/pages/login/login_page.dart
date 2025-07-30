import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    final TextEditingController _phoneController = TextEditingController();
    bool isLoading = false;
    int? _resendToken;
    bool checked = true;
    bool isCheckUserEnableTwoStepVerification = false;
    String? customerLastUid;
    return Scaffold();
  }
}
