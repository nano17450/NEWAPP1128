import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProjectScreen extends StatefulWidget {
  final Map<String, dynamic> projectData;
  final bool isAdmin;

  const ProjectScreen({Key? key, required this.projectData, required this.isAdmin}) : super(key: key);

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  late Map<String, dynamic> _projectData;
  bool _editing = false;
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _projectData = Map<String, dynamic>.from(widget.projectData);
    for (var key in [
      'name', 'code', 'street', 'number', 'city', 'state', 'zip', 'country', 'manager'
    ]) {
      _controllers[key] = TextEditingController(text: _projectData[key]?.toString() ?? '');
    }
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      final updatedData = {
        for (var key in _controllers.keys) key: _controllers[key]!.text,
      };
      final docId = _projectData['id'];
      if (docId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: No project ID found.')),
        );
        return;
      }
      try {
        // Obtén el documento más reciente antes de actualizar
        final docRef = FirebaseFirestore.instance.collection('projects').doc(docId);
        final docSnap = await docRef.get();
        if (!docSnap.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: El proyecto ya no existe en la base de datos.')),
          );
          return;
        }
        // Actualiza solo si existe
        await docRef.update(updatedData);
        setState(() {
          _editing = false;
          _projectData.addAll(updatedData);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Proyecto actualizado')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e')),
        );
      }
    }
  }

  Widget _buildField(String label, String key, {bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
            ),
          ),
          Expanded(
            child: _editing && key != 'createdAt'
                ? TextFormField(
                    controller: _controllers[key],
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  )
                : Text(
                    key == 'createdAt'
                        ? (_projectData['createdAt'] != null
                            ? (_projectData['createdAt'] is DateTime
                                ? (_projectData['createdAt'] as DateTime).toString().split(' ').first
                                : (_projectData['createdAt'] as Timestamp).toDate().toString().split(' ').first)
                            : '')
                        : (_projectData[key]?.toString() ?? ''),
                    style: TextStyle(fontSize: 15),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final displayUser = firebaseUser?.email ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                'ELEVATE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                displayUser,
                style: TextStyle(fontSize: 14, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 8),
            TextButton(
              onPressed: () {
                if (firebaseUser != null) {
                  FirebaseAuth.instance.signOut();
                }
                Navigator.of(context).pop();
              },
              child: Text(
                'Sign Out',
                style: TextStyle(color: Colors.white),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
                padding: EdgeInsets.zero,
                minimumSize: Size(0, 0),
              ),
            ),
            SizedBox(width: 12),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagen o placeholder
                Container(
                  width: 120,
                  height: 120,
                  margin: EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.image, size: 50, color: Colors.grey[400]),
                ),
                _buildField('Name', 'name'),
                _buildField('Code', 'code'),
                _buildField('Street', 'street'),
                _buildField('Number', 'number'),
                _buildField('City', 'city'),
                _buildField('State', 'state'),
                _buildField('ZIP', 'zip'),
                _buildField('Country', 'country'),
                _buildField('Manager', 'manager'),
                _buildField('Created', 'createdAt', readOnly: true),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: widget.isAdmin
          ? (_editing
              ? FloatingActionButton.extended(
                  onPressed: _saveChanges,
                  icon: Icon(Icons.save),
                  label: Text('Guardar'),
                  backgroundColor: Colors.blue,
                )
              : FloatingActionButton.extended(
                  onPressed: () async {
                    // Recarga el documento más reciente antes de editar
                    final docId = _projectData['id'];
                    if (docId != null) {
                      final docSnap = await FirebaseFirestore.instance.collection('projects').doc(docId).get();
                      if (docSnap.exists) {
                        setState(() {
                          _projectData.addAll(docSnap.data()!);
                          for (var key in _controllers.keys) {
                            _controllers[key]?.text = _projectData[key]?.toString() ?? '';
                          }
                          _editing = true;
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('El proyecto ya no existe en la base de datos.')),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: No project ID found.')),
                      );
                    }
                  },
                  icon: Icon(Icons.edit),
                  label: Text('Editar'),
                  backgroundColor: Colors.blue,
                ))
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomNavigationBar: BottomAppBar(
        shape: CircularNotchedRectangle(),
        notchMargin: 10.0,
        child: SizedBox(height: 48),
      ),
    );
  }
}