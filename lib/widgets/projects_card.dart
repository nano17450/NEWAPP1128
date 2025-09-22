import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'project_details_dialog.dart';

class ProjectsCard extends StatelessWidget {
  const ProjectsCard({super.key});

  void _showProjectInfo(BuildContext context, Map<String, dynamic> project) {
    showDialog(
      context: context,
      builder: (context) => ProjectDetailsDialog(project: project),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PROJECTS',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: Theme.of(context).primaryColor,
                  height: 1.0,
                ),
              ),
              SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('projects')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text('No projects found.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: snapshot.data!.docs.length,
                    separatorBuilder: (context, index) => SizedBox.shrink(),
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['name'] ?? '';
                      final timestamp = data['createdAt'] as Timestamp?;
                      final date = timestamp != null
                          ? DateTime.fromMillisecondsSinceEpoch(timestamp.millisecondsSinceEpoch)
                          : null;
                      final formattedDate = date != null
                          ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
                          : 'Unknown date';
                      return Card(
                        elevation: 1,
                        margin: EdgeInsets.symmetric(vertical: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    alignment: Alignment.centerLeft,
                                    padding: EdgeInsets.zero,
                                    foregroundColor: Theme.of(context).primaryColor,
                                    textStyle: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      height: 0.9,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                  onPressed: () => _showProjectInfo(context, data),
                                  child: Text(name, overflow: TextOverflow.ellipsis),
                                ),
                              ),
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                  height: 0.9,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}