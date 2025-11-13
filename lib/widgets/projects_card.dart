import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'project_details_dialog.dart';
import '../screens/project_screen.dart';

class ProjectsCard extends StatefulWidget {
  final bool isAdmin;
  const ProjectsCard({super.key, required this.isAdmin});

  @override
  State<ProjectsCard> createState() => _ProjectsCardState();
}

class _ProjectsCardState extends State<ProjectsCard> {
  bool _expanded = false;

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
        color: Colors.white,
        elevation: 3,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        'PROJECTS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: Theme.of(context).primaryColor,
                         height: 1.0,
                        )
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 20),
                    tooltip: _expanded ? 'Minimizar' : 'Expandir',
                    onPressed: () {
                      setState(() {
                        _expanded = !_expanded;
                      });
                    },
                  ),
                ],
              ),
              if (_expanded) ...[
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
                    final docs = widget.isAdmin
                        ? snapshot.data!.docs
                        : snapshot.data!.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return data['visible'] ?? true;
                          }).toList();

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final isVisible = data['visible'] ?? true;
                        data['id'] = doc.id;

                        return ListTile(
                          title: Text(data['name'] ?? ''),
                          trailing: widget.isAdmin
                              ? Switch(
                                  value: isVisible,
                                  onChanged: (val) {
                                    FirebaseFirestore.instance
                                        .collection('projects')
                                        .doc(doc.id)
                                        .update({'visible': val});
                                  },
                                  activeColor: Theme.of(context).primaryColor,
                                  inactiveThumbColor: Colors.grey,
                                )
                              : null,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProjectScreen(
                                  projectData: data,
                                  isAdmin: widget.isAdmin,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}