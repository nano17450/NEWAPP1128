import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/projects_card.dart';
import '../widgets/updates_card.dart';
import '../widgets/create_project_dialog.dart';
import 'insert_invoice_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? activeUser;
  final VoidCallback? onSignOut;

  const HomeScreen({Key? key, this.activeUser, this.onSignOut}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String? _userRole;
  bool _loadingRole = true;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() {
        _userRole = doc.data()?['role'] ?? 'user';
        _loadingRole = false;
      });
    } else {
      setState(() {
        _userRole = 'user';
        _loadingRole = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // You can add navigation logic here if you add more pages
  }

  void _showCreateProjectDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateProjectDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final displayUser = widget.activeUser ??
        (firebaseUser != null ? firebaseUser.email : 'Unknown');

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Text(
                'ELEVATE CONSTRUCTION SERVICES LLC APP',
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
                if (widget.onSignOut != null) {
                  widget.onSignOut!();
                } else {
                  Navigator.of(context).pushReplacementNamed('/');
                }
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UpdatesCard(),
              ProjectsCard(),
            ],
          ),
        ),
      ),
      floatingActionButton: _loadingRole
          ? null
          : Stack(
              children: [
                if (_userRole == 'admin')
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 80.0, right: 16.0),
                      child: FloatingActionButton(
                        heroTag: 'create_project',
                        onPressed: _showCreateProjectDialog,
                        backgroundColor: Colors.blue,
                        child: Icon(Icons.add),
                        tooltip: 'Crear Proyecto',
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0, right: 16.0),
                    child: FloatingActionButton(
                      heroTag: 'invoice',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => InsertInvoiceScreen()),
                        );
                      },
                      backgroundColor: Colors.green[700],
                      child: Icon(Icons.attach_money, size: 32),
                      tooltip: 'Insertar Factura',
                    ),
                  ),
                ),
              ],
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