import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_user_dialog.dart'; // Asegúrate de importar el diálogo

class TeamMembersPanel extends StatefulWidget {
  final double width;
  final bool isAdmin;

  const TeamMembersPanel({Key? key, this.width = 900, this.isAdmin = false}) : super(key: key);

  @override
  State<TeamMembersPanel> createState() => _TeamMembersPanelState();
}

class _TeamMembersPanelState extends State<TeamMembersPanel> {
  Future<void> _toggleVisibility(String userId, bool current) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({'visible': !current});
    setState(() {});
  }

  Future<void> _deleteUser(String userId, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete User'),
        content: Text('Are you sure you want to delete $email? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      margin: const EdgeInsets.only(top: 10, left: 10, bottom: 0),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isAdmin)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: ElevatedButton.icon(
                icon: Icon(Icons.person_add),
                label: Text('Crear usuario'),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => CreateUserDialog(),
                  );
                },
              ),
            ),
          Text('Team Members', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance.collection('users').get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return SizedBox(height: 40, child: Center(child: CircularProgressIndicator()));
              }
              final users = snapshot.data!.docs;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 28,
                  dataRowMinHeight: 24,
                  dataRowMaxHeight: 28,
                  columnSpacing: 70, // <-- más separación entre columnas
                  horizontalMargin: 6,
                  headingRowColor: MaterialStateProperty.all(Colors.grey[200]),
                  columns: [
                    DataColumn(label: Text('First', style: TextStyle(fontSize: 12))),
                    DataColumn(label: Text('Last', style: TextStyle(fontSize: 12))),
                    DataColumn(label: Text('Email', style: TextStyle(fontSize: 12))),
                    DataColumn(label: Text('Phone', style: TextStyle(fontSize: 12))),
                    DataColumn(label: Text('Role', style: TextStyle(fontSize: 12))),
                    DataColumn(label: Text('Visible', style: TextStyle(fontSize: 12))),
                    DataColumn(label: Text('')),
                  ],
                  rows: users.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DataRow(
                      cells: [
                        DataCell(Text(data['firstName'] ?? '-', style: TextStyle(fontSize: 12))),
                        DataCell(Text(data['lastName'] ?? '-', style: TextStyle(fontSize: 12))),
                        DataCell(Text(data['email'] ?? '-', style: TextStyle(fontSize: 12))),
                        DataCell(Text(data['phone'] ?? '-', style: TextStyle(fontSize: 12))),
                        DataCell(Text(data['role'] ?? '-', style: TextStyle(fontSize: 12))),
                        DataCell(
                          Transform.scale(
                            scale: 0.7, // Ajusta este valor para hacerlo más pequeño o más grande
                            child: Switch(
                              value: data['visible'] ?? true,
                              onChanged: (val) => _toggleVisibility(doc.id, data['visible'] ?? true),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                        DataCell(
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, size: 18),
                            padding: EdgeInsets.zero,
                            onSelected: (value) {
                              if (value == 'delete') {
                                _deleteUser(doc.id, data['email'] ?? '');
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}