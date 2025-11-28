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

    // Black border for strong outline
    final borderColor = Colors.black;

    Widget innerAvatar;
    if (photo != null && photo.isNotEmpty) {
      innerAvatar = CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(photo),
        backgroundColor: Colors.transparent,
      );
    } else {
      innerAvatar = CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Text(
          initials.isNotEmpty ? initials : 'U',
          style: TextStyle(
            color: Colors.white,
            fontSize: radius / 1.8,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // Outer circle with slightly thicker border
    return Container(
      width: radius * 2 + 6,
      height: radius * 2 + 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: 3,
        ),
      ),
      alignment: Alignment.center,
      child: innerAvatar,
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
                      double avatarRadius = 40;
                      if (width < 600) {
                        cross = 2;
                      } else if (width < 900) {
                        cross = 3;
                      }

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cross,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.9,
                        ),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final doc = users[index];
                          final user =
                              (doc.data() ?? {}) as Map<String, dynamic>;
                          final email = (user['email'] ?? '') as String;
                          final firstName = (user['firstname'] ?? '') as String;
                          final lastName = (user['lastname'] ?? '') as String;
                          final fullName =
                              ('$firstName $lastName').trim().isNotEmpty
                                  ? ('$firstName $lastName').trim()
                                  : email;
                          final role = (user['position'] ?? user['role'] ?? '')
                              as String;

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(
                                    avatarRadius + 8), // circle area only
                                onTap: () => onSignIn(
                                    email, (user['role'] ?? 'user') as String),
                                child: _avatarFor(user, context, avatarRadius),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                fullName,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (role.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  role,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
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
