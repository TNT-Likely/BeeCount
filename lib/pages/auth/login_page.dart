import 'package:flutter/material.dart';
import '../../presentation/v4/bindings/cloud_login_controls.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});
  @override
  Widget build(BuildContext context) => const CloudLoginControls();
}

/// Public login route. Registration remains in the existing help guide.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) => const AuthPage();
}
