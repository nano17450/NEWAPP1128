import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class InsertInvoiceScreen extends StatefulWidget {
  @override
  State<InsertInvoiceScreen> createState() => _InsertInvoiceScreenState();
}

class _InsertInvoiceScreenState extends State<InsertInvoiceScreen> {
  String? _selectedProjectId;
  String? _selectedProjectName;
  PlatformFile? _pickedFile;
  bool _uploading = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _pickedFile = result.files.first;
      });
    }
  }

  Future<void> _uploadInvoice() async {
    if (_selectedProjectId == null || _pickedFile == null) return;
    setState(() => _uploading = true);

    final ref = FirebaseStorage.instance
        .ref('invoices/${_selectedProjectId}/${_pickedFile!.name}');
    await ref.putData(_pickedFile!.bytes!);

    final url = await ref.getDownloadURL();

    await FirebaseFirestore.instance
        .collection('projects')
        .doc(_selectedProjectId)
        .collection('invoices')
        .add({
      'fileName': _pickedFile!.name,
      'fileUrl': url,
      'uploadedAt': FieldValue.serverTimestamp(),
    });

    setState(() => _uploading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invoice uploaded!')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Insert Invoice')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Project:', style: TextStyle(fontWeight: FontWeight.bold)),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('projects').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                final projects = snapshot.data!.docs;
                return DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedProjectId,
                  hint: Text('Choose a project'),
                  items: projects.map((doc) {
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(doc['name'] ?? 'No Name'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedProjectId = val;
                      _selectedProjectName = projects
                          .firstWhere((doc) => doc.id == val)['name'];
                    });
                  },
                );
              },
            ),
            SizedBox(height: 24),
            Text('Attach Invoice (PDF or Image):', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickFile,
                  icon: Icon(Icons.attach_file),
                  label: Text('Select File'),
                ),
                SizedBox(width: 12),
                if (_pickedFile != null)
                  Flexible(child: Text(_pickedFile!.name, overflow: TextOverflow.ellipsis)),
              ],
            ),
            Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_selectedProjectId != null && _pickedFile != null && !_uploading)
                    ? _uploadInvoice
                    : null,
                icon: Icon(Icons.cloud_upload),
                label: _uploading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Upload Invoice'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}