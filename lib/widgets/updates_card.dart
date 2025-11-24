import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class UpdatesCard extends StatefulWidget {
  final bool isAdmin;
  final String? userEmail;
  const UpdatesCard({super.key, required this.isAdmin, this.userEmail});

  @override
  State<UpdatesCard> createState() => _UpdatesCardState();
}

class _UpdatesCardState extends State<UpdatesCard> {
  final Map<String, TextEditingController> _controllers = {};
  final TextEditingController _newAlertController = TextEditingController();
  bool _expanded = false;
  bool _showNewAlertForm = false;

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    _newAlertController.dispose();
    super.dispose();
  }

  Future<void> _createAlert() async {
    if (_newAlertController.text.trim().isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('alerts').add({
        'message': _newAlertController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
        'readBy': <String>[],
        'active': true,
      });

      _newAlertController.clear();
      setState(() {
        _showNewAlertForm = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ Alert created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating alert: $e')),
        );
      }
    }
  }

  Future<void> _markAsRead(String alertId) async {
    final userEmail = widget.userEmail ?? FirebaseAuth.instance.currentUser?.email;
    if (userEmail == null) return;

    try {
      await FirebaseFirestore.instance.collection('alerts').doc(alertId).update({
        'readBy': FieldValue.arrayUnion([userEmail]),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✓ Marked as read'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  Future<void> _deleteAlert(String alertId) async {
    try {
      await FirebaseFirestore.instance.collection('alerts').doc(alertId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Alert deleted'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      print('Error deleting alert: $e');
    }
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
        child: SizedBox(
          width: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 9.0),
                      child: Text(
                        'LATEST NEWS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: Theme.of(context).primaryColor,
                          height: 1.0,
                        ),
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
                // Sección de alertas importantes
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('alerts')
                      .where('active', isEqualTo: true)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, alertSnapshot) {
                    final userEmail = widget.userEmail ?? FirebaseAuth.instance.currentUser?.email;
                    
                    if (alertSnapshot.hasData && alertSnapshot.data!.docs.isNotEmpty) {
                      final alerts = alertSnapshot.data!.docs;
                      final unreadAlerts = alerts.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final readBy = List<String>.from(data['readBy'] ?? []);
                        return !readBy.contains(userEmail);
                      }).toList();

                      if (!widget.isAdmin && unreadAlerts.isEmpty) {
                        return SizedBox.shrink();
                      }

                      return Container(
                        padding: EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'IMPORTANT ALERTS',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[800],
                                  ),
                                ),
                                if (!widget.isAdmin && unreadAlerts.isNotEmpty)
                                  Container(
                                    margin: EdgeInsets.only(left: 8),
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${unreadAlerts.length}',
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                if (widget.isAdmin) ...[
                                  Spacer(),
                                  IconButton(
                                    icon: Icon(Icons.add_alert, size: 18),
                                    tooltip: 'Create new alert',
                                    onPressed: () {
                                      setState(() {
                                        _showNewAlertForm = !_showNewAlertForm;
                                      });
                                    },
                                  ),
                                ],
                              ],
                            ),
                            if (widget.isAdmin && _showNewAlertForm) ...[
                              SizedBox(height: 8),
                              Card(
                                color: Colors.orange[50],
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      TextField(
                                        controller: _newAlertController,
                                        decoration: InputDecoration(
                                          labelText: 'New Alert Message',
                                          hintText: 'Enter important message for all users...',
                                          border: OutlineInputBorder(),
                                          prefixIcon: Icon(Icons.warning_amber_rounded),
                                        ),
                                        maxLines: 3,
                                      ),
                                      SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () {
                                              _newAlertController.clear();
                                              setState(() {
                                                _showNewAlertForm = false;
                                              });
                                            },
                                            child: Text('Cancel'),
                                          ),
                                          SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            onPressed: _createAlert,
                                            icon: Icon(Icons.send, size: 16),
                                            label: Text('Send Alert'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            SizedBox(height: 8),
                            ...alerts.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final readBy = List<String>.from(data['readBy'] ?? []);
                              final isRead = userEmail != null && readBy.contains(userEmail);
                              final createdAt = data['createdAt'] as Timestamp?;
                              final dateStr = createdAt != null
                                  ? DateFormat('MMM d, h:mm a').format(createdAt.toDate())
                                  : 'Just now';
                              final createdBy = data['createdBy'] ?? 'admin';

                              // Si no es admin y ya lo leyó, no mostrar
                              if (!widget.isAdmin && isRead) {
                                return SizedBox.shrink();
                              }

                              return Card(
                                color: isRead ? Colors.grey[100] : Colors.orange[50],
                                margin: EdgeInsets.only(bottom: 8),
                                elevation: isRead ? 0 : 2,
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isRead ? Icons.check_circle : Icons.notification_important,
                                            color: isRead ? Colors.grey : Colors.orange[700],
                                            size: 18,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              data['message'] ?? '',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                                decoration: isRead ? TextDecoration.lineThrough : null,
                                                color: isRead ? Colors.grey[600] : Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Text(
                                            dateStr,
                                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'by $createdBy',
                                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                          ),
                                          if (widget.isAdmin) ...[
                                            SizedBox(width: 8),
                                            Text(
                                              '${readBy.length} read',
                                              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                            ),
                                          ],
                                          Spacer(),
                                          if (!isRead && !widget.isAdmin)
                                            ElevatedButton(
                                              onPressed: () => _markAsRead(doc.id),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                minimumSize: Size(0, 0),
                                              ),
                                              child: Text('Mark as Read', style: TextStyle(fontSize: 11)),
                                            ),
                                          if (widget.isAdmin)
                                            IconButton(
                                              icon: Icon(Icons.delete_outline, size: 16, color: Colors.red[400]),
                                              padding: EdgeInsets.zero,
                                              constraints: BoxConstraints(),
                                              onPressed: () => _deleteAlert(doc.id),
                                              tooltip: 'Delete alert',
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                            Divider(thickness: 2),
                          ],
                        ),
                      );
                    }
                    return SizedBox.shrink();
                  },
                ),
                // Sección de noticias generales
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.newspaper, color: Colors.blue[700], size: 18),
                      SizedBox(width: 8),
                      Text(
                        'GENERAL NEWS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 4),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('summary').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text('No updates found.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final id = doc.id;
                        _controllers.putIfAbsent(id, () => TextEditingController(text: data['text'] ?? ''));

                        return ListTile(
                          dense: true,
                          title: widget.isAdmin
                              ? TextFormField(
                                  controller: _controllers[id],
                                  decoration: InputDecoration(
                                    labelText: 'Update',
                                    border: OutlineInputBorder(),
                                  ),
                                  style: TextStyle(fontSize: 12),
                                  maxLines: null,
                                )
                              : Text(data['text'] ?? '', style: TextStyle(fontSize: 12)),
                          trailing: widget.isAdmin
                              ? IconButton(
                                  icon: Icon(Icons.save, size: 18),
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('summary')
                                        .doc(id)
                                        .update({'text': _controllers[id]!.text});
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Update saved')),
                                      );
                                    }
                                  },
                                )
                              : null,
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

