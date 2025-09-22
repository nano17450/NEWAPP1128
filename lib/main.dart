import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'routes/app_routes.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'widgets/sign_in_screen.dart';
import 'screens/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      routes: appRoutes,
      initialRoute: '/', // Make sure '/' points to AuthGate in appRoutes
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

  void _handleSignIn(String email, String password) async {
    if (email == 'admin@company.com' && password == '1234') {
      setState(() {
        _signedIn = true;
        _activeUser = 'admin';
      });
      return;
    }
    if (email == 'user' && password == '1234') {
      setState(() {
        _signedIn = true;
        _activeUser = 'user';
      });
      return;
    }
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      setState(() {
        _signedIn = true;
        _activeUser = email;
      });
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid credentials')),
      );
    }
  }

  void _handleSignOut() {
    setState(() {
      _signedIn = false;
      _activeUser = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_signedIn) {
      return HomeScreen(
        activeUser: _activeUser,
        onSignOut: _handleSignOut,
      );
    }
    return SignInScreen(onSignIn: _handleSignIn);
  }
}