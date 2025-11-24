import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignInScreen extends StatelessWidget {
  final void Function(String email, String role) onSignIn;
  const SignInScreen({Key? key, required this.onSignIn}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 400),
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Select User',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 32),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('visible', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }
                    final users = snapshot.data!.docs;
                    if (users.isEmpty) {
                      return Center(
                        child: Text('No users available'),
                      );
                    }
                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index].data() as Map<String, dynamic>;
                        final email = user['email'] ?? '';
                        final firstname = user['firstname'] ?? '';
                        final lastname = user['lastname'] ?? '';
                        final role = user['role'] ?? 'user';
                        final position = user['position'] ?? '';

                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                firstname.isNotEmpty ? firstname[0].toUpperCase() : 'U',
                              ),
                            ),
                            title: Text('$firstname $lastname'),
                            subtitle: Text(position.isNotEmpty ? position : email),
                            trailing: Icon(Icons.arrow_forward_ios),
                            onTap: () => onSignIn(email, role),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}