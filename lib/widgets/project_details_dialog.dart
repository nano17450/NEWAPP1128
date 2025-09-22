import 'package:flutter/material.dart';

class ProjectDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> project;

  const ProjectDetailsDialog({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(project['name'] ?? 'Project Details'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (project['code'] != null) Text('Code: ${project['code']}'),
            if (project['street'] != null || project['number'] != null)
              Text('Address: ${project['street'] ?? ''} ${project['number'] ?? ''}'),
            if (project['city'] != null) Text('City: ${project['city']}'),
            if (project['state'] != null) Text('State: ${project['state']}'),
            if (project['zip'] != null) Text('ZIP: ${project['zip']}'),
            if (project['country'] != null) Text('Country: ${project['country']}'),
            if (project['manager'] != null) Text('Manager: ${project['manager']}'),
            if (project['createdAt'] != null)
              Text('Created: ${project['createdAt'].toDate().toString().split(' ').first}'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'),
        ),
      ],
    );
  }
}