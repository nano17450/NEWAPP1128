import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/protective_film_order.dart';

class ProtectiveFilmScreen extends StatefulWidget {
  final bool isAdmin;
  final String activeUser;

  const ProtectiveFilmScreen({
    Key? key,
    required this.isAdmin,
    required this.activeUser,
  }) : super(key: key);

  @override
  State<ProtectiveFilmScreen> createState() => _ProtectiveFilmScreenState();
}

class _ProtectiveFilmScreenState extends State<ProtectiveFilmScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  
  String? _selectedProjectId;
  String? _selectedProjectName;
  String _selectedFilmType = 'Clear';
  String _selectedUnit = 'sqm';
  String _filterStatus = 'all';

  final List<String> _filmTypes = [
    'Clear',
    'Frosted',
    'Tinted',
    'Security',
    'Anti-Glare',
    'UV Protection',
  ];

  final List<String> _units = ['sqm', 'sqft', 'rolls', 'meters'];
  final List<String> _statusOptions = ['all', 'pending', 'approved', 'ordered', 'delivered'];

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _getProjects() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('projects').get();
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'name': doc.data()['name'] as String? ?? 'No Name',
        };
      }).where((project) => project['name'] != 'No Name').toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate() || _selectedProjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    try {
      final order = ProtectiveFilmOrder(
        projectName: _selectedProjectName!,
        projectId: _selectedProjectId!,
        filmType: _selectedFilmType,
        quantity: double.parse(_quantityController.text),
        unit: _selectedUnit,
        orderedBy: widget.activeUser,
        orderedAt: DateTime.now(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('protective_film_orders')
          .add(order.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Order submitted successfully')),
        );
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    }
  }

  void _resetForm() {
    setState(() {
      _selectedProjectId = null;
      _selectedProjectName = null;
      _selectedFilmType = 'Clear';
      _selectedUnit = 'sqm';
      _quantityController.clear();
      _notesController.clear();
    });
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('protective_film_orders')
          .doc(orderId)
          .update({'status': newStatus});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Status updated to $newStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'ordered':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildOrderForm() {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📦 New Protective Film Order',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              
              // Project Selection
              Text('Project *', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _getProjects(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return CircularProgressIndicator();
                  }
                  final projects = snapshot.data!;
                  return DropdownButtonFormField<String>(
                    value: _selectedProjectId,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    hint: Text('Select a project'),
                    items: projects.map((project) {
                      return DropdownMenuItem<String>(
                        value: project['id'],
                        child: Text(project['name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedProjectId = value;
                        _selectedProjectName = projects.firstWhere(
                          (p) => p['id'] == value,
                          orElse: () => {'name': 'Unknown'},
                        )['name'];
                      });
                    },
                    validator: (value) => value == null ? 'Please select a project' : null,
                  );
                },
              ),
              SizedBox(height: 16),
              
              // Film Type
              Text('Film Type *', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedFilmType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _filmTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedFilmType = value!;
                  });
                },
              ),
              SizedBox(height: 16),
              
              // Quantity and Unit
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quantity *', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _quantityController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            if (double.tryParse(value) == null || double.parse(value) <= 0) {
                              return 'Enter valid quantity';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Unit *', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedUnit,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: _units.map((unit) {
                            return DropdownMenuItem<String>(
                              value: unit,
                              child: Text(unit),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedUnit = value!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              
              // Notes
              Text('Notes (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  hintText: 'Additional information about the order',
                ),
                maxLines: 3,
              ),
              SizedBox(height: 16),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitOrder,
                  icon: Icon(Icons.send),
                  label: Text('Submit Order'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('protective_film_orders')
          .orderBy('orderedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No protective film orders yet',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ),
          );
        }

        var orders = snapshot.data!.docs.map((doc) {
          return ProtectiveFilmOrder.fromMap(doc.id, doc.data() as Map<String, dynamic>);
        }).toList();

        // Apply status filter
        if (_filterStatus != 'all') {
          orders = orders.where((order) => order.status == _filterStatus).toList();
        }

        return Column(
          children: [
            // Filter
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text('Filter by status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _filterStatus,
                      isExpanded: true,
                      items: _statusOptions.map((status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(status.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _filterStatus = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            // Orders List
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(
                        '${order.filmType} - ${order.quantity} ${order.unit}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 4),
                          Text('Project: ${order.projectName}'),
                          Text('Ordered by: ${order.orderedBy}'),
                          Text('Date: ${DateFormat('MMM dd, yyyy HH:mm').format(order.orderedAt)}'),
                          if (order.notes != null && order.notes!.isNotEmpty)
                            Text('Notes: ${order.notes}', style: TextStyle(fontStyle: FontStyle.italic)),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(order.status),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              order.status.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (widget.isAdmin && order.status != 'delivered')
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, size: 16),
                              onSelected: (newStatus) {
                                _updateOrderStatus(order.id!, newStatus);
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(value: 'pending', child: Text('Pending')),
                                PopupMenuItem(value: 'approved', child: Text('Approved')),
                                PopupMenuItem(value: 'ordered', child: Text('Ordered')),
                                PopupMenuItem(value: 'delivered', child: Text('Delivered')),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final displayUser = widget.activeUser ?? (firebaseUser?.email ?? 'Unknown');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'Protective Film Orders',
              style: TextStyle(color: Colors.white),
            ),
            Spacer(),
            Text(
              displayUser,
              style: TextStyle(fontSize: 14, color: Colors.white),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildOrderForm(),
            Expanded(child: _buildOrdersList()),
          ],
        ),
      ),
    );
  }
}
