import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'routes/app_routes.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'widgets/sign_in_screen.dart';
import 'screens/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/project_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Company App',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      home: AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _signedIn = false;
  String? _activeUser;
  String? _role;

  void _handleSignIn(String email, String role) {
    setState(() {
      _signedIn = true;
      _activeUser = email;
      _role = role;
    });
  }

  void _handleSignOut() {
    setState(() {
      _signedIn = false;
      _activeUser = null;
      _role = null;
    });
  }

 @override
  Widget build(BuildContext context) {
    // Ignora el login y entra directo al HomeScreen
    return HomeScreen(
      activeUser: 'yurikm.elevate@gmail.com', // o cualquier valor de prueba
      role: 'user',                // o 'admin'
      onSignOut: () {},
    );
  }
}