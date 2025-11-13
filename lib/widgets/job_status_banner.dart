import 'package:flutter/material.dart';

class JobStatusBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Aquí debes consultar Firestore para saber si el usuario está clocked in y el tiempo
    // Este es solo un ejemplo visual
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
            Text('Cronómetro: 02:15:30'), // Calcula el tiempo real
          ],
        ),
        trailing: Icon(Icons.warning, color: Colors.red), // Solo si > 8h
      ),
    );
  }
}