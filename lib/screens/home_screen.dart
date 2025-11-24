import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import '../widgets/projects_card.dart';
import '../widgets/create_project_dialog.dart';
import 'insert_invoice_screen.dart';
import '../widgets/updates_card.dart';
import '../widgets/summary_panel.dart';
import '../widgets/job_status_banner.dart';
import '../widgets/team_members_panel.dart';
import '../widgets/general_summary_panel.dart';

class HomeScreen extends StatefulWidget {
  final String activeUser;
  final String role;
  final VoidCallback onSignOut;

  const HomeScreen({
    Key? key,
    required this.activeUser,
    required this.role,
    required this.onSignOut,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? selectedUserEmail;

  Future<void> exportProjectsToCSV() async {
    final snapshot = await FirebaseFirestore.instance.collection('projects').get();
    List<List<dynamic>> rows = [];
    rows.add(['Name', 'Code', 'Manager', 'City', 'State', 'Country']);

    for (var doc in snapshot.docs) {
      final data = doc.data();
      rows.add([
        data['name'] ?? '',
        data['code'] ?? '',
        data['manager'] ?? '',
        data['city'] ?? '',
        data['state'] ?? '',
        data['country'] ?? '',
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'projects.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.role == 'admin';
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final displayUser = widget.activeUser ?? (firebaseUser != null ? firebaseUser.email : 'Unknown');

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Text(
                'ELEVATE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
            Spacer(),
            Text(
              displayUser ?? '',
              style: TextStyle(fontSize: 14, color: Colors.white),
            ),
            SizedBox(width: 8),
            TextButton(
              onPressed: () {
                if (firebaseUser != null) {
                  FirebaseAuth.instance.signOut();
                }
                widget.onSignOut();
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            const double summaryWidth = 900;
            const double cardsWidth = 400;
            const double gap = 24;

            if (constraints.maxWidth >= summaryWidth + gap + cardsWidth) {
              // Pantalla grande: todo en un SingleChildScrollView vertical
              return SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: cardsWidth),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            UpdatesCard(isAdmin: isAdmin),
                            SizedBox(height: 0),
                            ProjectsCard(isAdmin: isAdmin),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: gap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isAdmin) ...[
                            TeamMembersPanel(
                              width: summaryWidth,
                              isAdmin: isAdmin,
                            ),
                            GeneralSummaryPanel(
                              width: summaryWidth,
                              onUserSelected: (email) {
                                setState(() {
                                  selectedUserEmail = email;
                                });
                              },
                            ),
                            if (selectedUserEmail != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: Stack(
                                  children: [
                                    SummaryPanel(
                                      width: summaryWidth,
                                      activeUser: selectedUserEmail!,
                                      isEditable: true, // <-- solo para admin
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: IconButton(
                                        icon: Icon(Icons.close),
                                        tooltip: 'Cerrar',
                                        onPressed: () {
                                          setState(() {
                                            selectedUserEmail = null;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ] else ...[
                            SummaryPanel(
                              width: summaryWidth,
                              activeUser: widget.activeUser,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            } else {
              // Pantalla pequeña: todo en un SingleChildScrollView vertical
              final double summaryPanelWidth = constraints.maxWidth < cardsWidth
                  ? constraints.maxWidth
                  : cardsWidth;
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UpdatesCard(isAdmin: isAdmin),
                    SizedBox(height: 0),
                    ProjectsCard(isAdmin: isAdmin),
                    JobStatusBanner(),
                    SizedBox(height: 0),
                    if (isAdmin) ...[
                      TeamMembersPanel(
                        width: summaryPanelWidth,
                        isAdmin: isAdmin,
                      ),
                      GeneralSummaryPanel(
                        width: summaryPanelWidth,
                        onUserSelected: (email) {
                          setState(() {
                            selectedUserEmail = email;
                          });
                        },
                      ),
                      if (selectedUserEmail != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Stack(
                            children: [
                              SummaryPanel(
                                width: summaryPanelWidth,
                                activeUser: selectedUserEmail!,
                                isEditable: true, // <-- solo para admin
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  icon: Icon(Icons.close),
                                  tooltip: 'Cerrar',
                                  onPressed: () {
                                    setState(() {
                                      selectedUserEmail = null;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                    ] else ...[
                      SummaryPanel(
                        width: summaryPanelWidth,
                        activeUser: widget.activeUser,
                      ),
                    ],
                  ],
                ),
              );
            }
          },
        ),
      ),
      floatingActionButton: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 16.0, bottom: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isAdmin) ...[
                FloatingActionButton(
                  heroTag: 'export_projects',
                  onPressed: exportProjectsToCSV,
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.download, size: 28),
                  tooltip: 'Exportar Proyectos',
                ),
                SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'create_project',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => CreateProjectDialog(),
                    );
                  },
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.add),
                  tooltip: 'Crear Proyecto',
                ),
                SizedBox(height: 16),
                SizedBox(height: 16),
              ],
              SizedBox(height: 16),
              FloatingActionButton(
                heroTag: 'invoice',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => InsertInvoiceScreen()),
                  );
                },
                backgroundColor: Colors.blue[800],
                child: Icon(Icons.attach_money, size: 32),
                tooltip: 'Insertar Factura',
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomNavigationBar: BottomAppBar(
        shape: CircularNotchedRectangle(),
        notchMargin: 10.0,
        child: SizedBox(height: 48),
      ),
    );
  }
}