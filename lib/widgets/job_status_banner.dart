import 'package:flutter/material.dart';

class JobStatusBanner extends StatelessWidget {
  final bool isAdmin;

  const JobStatusBanner({Key? key, this.isAdmin = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isAdmin) return SizedBox.shrink();
    // Here you should query Firestore to determine if the user is clocked in and the elapsed time
    // This is only a visual example
    return Card(
      color: Colors.yellow[100],
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(Icons.work, color: Colors.orange),
        title: Text('JOB'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: CLOCK IN'),
            Text('Timer: 02:15:30'), // Calculate the real time
          ],
        ),
        trailing: Icon(Icons.warning, color: Colors.red), // Solo si > 8h
      ),
    );
  }
}
