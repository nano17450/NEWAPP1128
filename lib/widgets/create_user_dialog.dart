import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateUserDialog extends StatefulWidget {
  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  String? email;
  String? firstname;
  String? lastname;
  String? phone;

  bool loading = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Create User'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Email'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                onSaved: (v) => email = v,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'First Name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                onSaved: (v) => firstname = v,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Last Name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                onSaved: (v) => lastname = v,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Phone'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                onSaved: (v) => phone = v,
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(error!, style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: loading
              ? null
              : () async {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    setState(() {
                      loading = true;
                      error = null;
                    });
                    try {
                      // 1. Create user in Firebase Auth
                      UserCredential userCredential = await FirebaseAuth
                          .instance
                          .createUserWithEmailAndPassword(
                        email: email!,
                        password: '123456',
                      );

                      // 2. Save user data in Firestore with role "user"
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(userCredential.user!.uid)
                          .set({
                        'email': email,
                        'firstname': firstname,
                        'lastname': lastname,
                        'phone': phone,
                        'role': 'user',
                        'visible': true,
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      // 3. Send welcome email (Firebase sends verification by default)
                      await userCredential.user!.sendEmailVerification();

                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text('User created and welcome email sent.')),
                      );
                    } on FirebaseAuthException catch (e) {
                      setState(() {
                        error = e.message;
                        loading = false;
                      });
                    } catch (e) {
                      setState(() {
                        error = 'Error: $e';
                        loading = false;
                      });
                    }
                  }
                },
          child: loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text('Create'),
        ),
      ],
    );
  }
}
