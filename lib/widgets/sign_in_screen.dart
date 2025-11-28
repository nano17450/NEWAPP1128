import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// SignInScreen: smaller logo + Firestore-backed circular avatars-only grid
class SignInScreen extends StatelessWidget {
  final void Function(String email, String role) onSignIn;
  const SignInScreen({Key? key, required this.onSignIn}) : super(key: key);

  Widget _avatarFor(
      Map<String, dynamic> user, BuildContext context, double radius) {
    final photo = (user['photoUrl'] ?? user['photo']) as String?;
    final first = (user['firstname'] ?? '') as String;
    final last = (user['lastname'] ?? '') as String;
    final initials =
        ((first.isNotEmpty ? first[0] : '') + (last.isNotEmpty ? last[0] : ''))
            .toUpperCase();

    if (photo != null && photo.isNotEmpty) {
      return CircleAvatar(
          radius: radius,
          backgroundImage: NetworkImage(photo),
          backgroundColor: Colors.transparent);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: Text(
        initials.isNotEmpty ? initials : 'U',
        style: TextStyle(
            color: Colors.white,
            fontSize: radius / 1.8,
            fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              children: [
                // Smaller Elevate logo
                Image.asset(
                  'assets/logo.png',
                  height: 140,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => Text('ELEVATE',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                ),

                SizedBox(height: 10),
                Text("Who's using Elevate?",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                SizedBox(height: 12),

                // Users grid from Firestore (avatars-only)
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('visible', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError)
                      return Center(child: Text('Error loading users'));
                    if (!snapshot.hasData)
                      return Center(child: CircularProgressIndicator());
                    final users = snapshot.data!.docs;
                    if (users.isEmpty)
                      return Center(child: Text('No users available'));

                    return LayoutBuilder(builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      int cross = 4;
                      double avatarRadius = 32;
                      if (width < 600) {
                        cross = 2;
                        avatarRadius = 28;
                      } else if (width < 900) {
                        cross = 3;
                        avatarRadius = 30;
                      }

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cross,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1,
                        ),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final doc = users[index];
                          final user =
                              (doc.data() ?? {}) as Map<String, dynamic>;
                          final email = (user['email'] ?? '') as String;

                          final first = (user['firstname'] ?? '') as String;
                          final last = (user['lastname'] ?? '') as String;
                          final fullName = ((first + ' ' + last).trim()).isNotEmpty
                              ? (first + ' ' + last).trim()
                              : (user['displayName'] ?? user['name'] ?? 'User');
                          final position = (user['position'] ?? '') as String;

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: () => onSignIn(
                                    email, (user['role'] ?? 'user') as String),
                                child: _avatarFor(user, context, avatarRadius),
                              ),
                              SizedBox(height: 8),
                              ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: avatarRadius * 4),
                                child: Column(
                                  children: [
                                    Text(
                                      fullName,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (position.isNotEmpty) ...[
                                      SizedBox(height: 2),
                                      Text(
                                        position,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600]),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ]
                                  ],
                                ),
                              )
                            ],
                          );
                        },
                      );
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
