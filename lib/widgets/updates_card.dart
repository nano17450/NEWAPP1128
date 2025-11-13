import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UpdatesCard extends StatefulWidget {
  final bool isAdmin;
  const UpdatesCard({super.key, required this.isAdmin});

  @override
  State<UpdatesCard> createState() => _UpdatesCardState();
}

class _UpdatesCardState extends State<UpdatesCard> {
  final Map<String, TextEditingController> _controllers = {};
  bool _expanded = false;

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
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
                          title: widget.isAdmin
                              ? TextFormField(
                                  controller: _controllers[id],
                                  decoration: InputDecoration(
                                    labelText: 'Update',
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: null,
                                )
                              : Text(data['text'] ?? ''),
                          trailing: widget.isAdmin
                              ? IconButton(
                                  icon: Icon(Icons.save),
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('summary')
                                        .doc(id)
                                        .update({'text': _controllers[id]!.text});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Update saved')),
                                    );
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

