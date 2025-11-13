import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignInScreen extends StatefulWidget {
  final void Function(String email, String role) onSignIn;
  const SignInScreen({Key? key, required this.onSignIn}) : super(key: key);

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _loading = true);
      await _handleSignIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      setState(() => _loading = false);
    }
  }

  Future<void> _handleSignIn(String email, String password) async {
    try {
      // Autenticación con Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Consulta el rol en Firestore
      final doc = await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).get();
      final role = doc.data()?['role'] ?? 'user';
      widget.onSignIn(email, role);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid credentials')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 32),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(labelText: 'Email'),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Enter your email' : null,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Enter your password' : null,
                    ),
                    SizedBox(height: 24),
                    _loading
                        ? CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _submit,
                            child: Text('Sign In'),
                          ),
                  ],
                ),
              ),
            ),
          ),
        
          Positioned(
            right: 16,
            bottom: 12,
            child: Text(
              'ELEVATE CONSTRUCTION SERVICES LLC v.1',
              style: TextStyle(
                fontSize: 10,
                color: Colors.black,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.1,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}