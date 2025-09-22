import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UpdatesCard extends StatelessWidget {
  const UpdatesCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'UPDATES',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: Theme.of(context).primaryColor,
                height: 1.0,
              ),
            ),
            SizedBox(height: 8),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('summary')
                  .doc('2i2PEmS1VYiu9D7Fkq4y')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Text(
                    'No summary available.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  );
                }
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                final summaryText = data?['main'] ?? 'No summary available.';
                return Text(
                  summaryText,
                  style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.2),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}