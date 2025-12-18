import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async' show Timer; // NEW: import Timer explicitly
import '../widgets/projects_card.dart';
import '../widgets/create_project_dialog.dart';
import 'insert_invoice_screen.dart';
import '../widgets/updates_card.dart';
import '../widgets/summary_panel.dart';
import '../widgets/job_status_banner.dart';
import '../widgets/team_members_panel.dart';
import '../widgets/general_summary_panel.dart';
import 'protective_film_screen.dart';

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
  String currentTime = '';
  Position? currentLocation;
  bool isClockingIn = false;
  bool hasActiveSession = false;
  String? activeProject;
  DateTime? sessionStartTime;
  Map<String, dynamic>? lastSessionSummary;
  final _payrollNotesController = TextEditingController(); // NUEVO

  // Break state
  int breaksUsed = 0; // NEW: number of breaks taken today
  bool onBreak = false; // NEW: currently on a break
  DateTime? breakEndTime; // NEW: end time for current break
  String breakRemaining = ''; // NEW: remaining countdown mm:ss
  Timer? _breakTimer; // NEW: ticker

  // Unique key for the signed-in account (UID → email → provided label)
  String get _loggedInUserKey =>
      FirebaseAuth.instance.currentUser?.uid ??
      FirebaseAuth.instance.currentUser?.email ??
      widget.activeUser;

  // Use selectedUserEmail only when admin explicitly targets someone; otherwise isolate by logged account
  String get _viewUserKey => (widget.role == 'admin' &&
          selectedUserEmail != null &&
          selectedUserEmail!.isNotEmpty)
      ? selectedUserEmail!
      : _loggedInUserKey;

  String get _activeSessionKey => 'active_session_$_viewUserKey';
  String get _lastSessionSummaryKey => 'last_session_summary_$_viewUserKey';
  String get _attendanceRecordsKey => 'attendance_records_$_viewUserKey';

  CollectionReference<Map<String, dynamic>> get _userAttendance =>
      FirebaseFirestore.instance
          .collection('attendance')
          .doc(_viewUserKey)
          .collection('records');

  DocumentReference<Map<String, dynamic>> get _activeSessionDoc =>
      FirebaseFirestore.instance
          .collection('active_sessions')
          .doc(_viewUserKey);

  // NEW: per-user locations audit trail
  CollectionReference<Map<String, dynamic>> get _userLocations =>
      FirebaseFirestore.instance
          .collection('locations')
          .doc(_viewUserKey)
          .collection('records');

  // Breaks record
  String get _breaksUsedKey =>
      'breaks_used_${_viewUserKey}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}'; // FIX: use ${_viewUserKey}

  @override
  void initState() {
    super.initState();
    _updateTime();
    _getCurrentLocation();
    _migrateKeysIfNeeded(); // migrate old global keys once
    _checkActiveSession();
    _restoreBreaksCount(); // NEW: restore breaks used for today
    Stream.periodic(Duration(seconds: 1)).listen((_) {
      if (mounted) _updateTime();
    });
  }

  @override
  void dispose() {
    _payrollNotesController.dispose(); // NUEVO
    _breakTimer?.cancel(); // NEW
    super.dispose();
  }

  void _updateTime() {
    if (mounted) {
      setState(() {
        currentTime = DateFormat('HH:mm:ss').format(DateTime.now());
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          currentLocation = position;
        });
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<void> _migrateKeysIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    // Migrate global keys to per-user keys if they exist (one-time best-effort)
    final globalActive = prefs.getString('active_session');
    if (globalActive != null && prefs.getString(_activeSessionKey) == null) {
      await prefs.setString(_activeSessionKey, globalActive);
      await prefs.remove('active_session');
    }
    final globalSummary = prefs.getString('last_session_summary');
    if (globalSummary != null &&
        prefs.getString(_lastSessionSummaryKey) == null) {
      await prefs.setString(_lastSessionSummaryKey, globalSummary);
      await prefs.remove('last_session_summary');
    }
    final globalRecords = prefs.getStringList('attendance_records');
    if (globalRecords != null &&
        prefs.getStringList(_attendanceRecordsKey) == null) {
      await prefs.setStringList(_attendanceRecordsKey, globalRecords);
      await prefs.remove('attendance_records');
    }
  }

  Future<void> _checkActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final activeSessionStr = prefs.getString(_activeSessionKey);
    final lastSessionStr = prefs.getString(_lastSessionSummaryKey);

    if (activeSessionStr != null) {
      final session = json.decode(activeSessionStr);
      final sessionDate = DateTime.parse(session['timestamp']);
      final today = DateTime.now();

      if (sessionDate.year == today.year &&
          sessionDate.month == today.month &&
          sessionDate.day == today.day &&
          session['user'] == _viewUserKey) {
        setState(() {
          hasActiveSession = true;
          activeProject = session['project'];
          sessionStartTime = sessionDate;
        });
      } else {
        await prefs.remove(_activeSessionKey);
      }
    } else {
      // Optional: check Firestore active session as fallback (e.g., device switch)
      final doc = await _activeSessionDoc.get();
      if (doc.exists) {
        final data = doc.data()!;
        final ts = DateTime.tryParse(data['timestamp'] ?? '');
        if (ts != null) {
          setState(() {
            hasActiveSession = true;
            activeProject = data['project'] as String?;
            sessionStartTime = ts;
          });
        }
      }
    }

    if (lastSessionStr != null) {
      final summary = json.decode(lastSessionStr);
      if (summary['project'] != null) {
        setState(() {
          lastSessionSummary = summary;
        });
      }
    }
  }

  Future<List<String>> _getProjects() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('projects').get();
      return snapshot.docs
          .map((doc) => doc.data()['name'] as String? ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<String?> _showProjectSelectionDialog() async {
    final projects = await _getProjects();
    if (projects.isEmpty) {
      _showSnackBar('No projects available', Colors.orange);
      return null;
    }

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Project'),
        content: Container(
          width: double.minPositive,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: projects.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(projects[index]),
                onTap: () => Navigator.pop(context, projects[index]),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _clockIn() async {
    if (isClockingIn || hasActiveSession) return;
    final project = await _showProjectSelectionDialog();
    if (project == null) return;

    setState(() => isClockingIn = true);
    try {
      await _getCurrentLocation();
      final now = DateTime.now();
      final record = {
        'type': 'check_in',
        'timestamp': now.toIso8601String(),
        'user': _viewUserKey, // CHANGED: per-user
        'project': project,
        'location': currentLocation != null
            ? {
                'latitude': currentLocation!.latitude,
                'longitude': currentLocation!.longitude,
                'accuracy': currentLocation!.accuracy,
              }
            : null,
      };

      // Local per-user cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeSessionKey, json.encode(record));
      final records = prefs.getStringList(_attendanceRecordsKey) ?? [];
      records.add(json.encode(record));
      await prefs.setStringList(_attendanceRecordsKey, records);

      // Firestore: per-user records and active session doc
      await _userAttendance.add(record);
      await _activeSessionDoc.set({
        'user': _viewUserKey, // CHANGED: per-user
        'project': project,
        'timestamp': now.toIso8601String(),
        'location': record['location'],
      });

      // NEW: store raw geolocation audit
      if (currentLocation != null) {
        await _userLocations.add({
          'type': 'check_in',
          'timestamp': now.toIso8601String(),
          'project': project,
          'latitude': currentLocation!.latitude,
          'longitude': currentLocation!.longitude,
          'accuracy': currentLocation!.accuracy,
        });
      }

      setState(() {
        hasActiveSession = true;
        activeProject = project;
        sessionStartTime = now;
        lastSessionSummary = null;
        breaksUsed = 0; // NEW: reset breaks on new session
        onBreak = false; // NEW
        breakEndTime = null; // NEW
        breakRemaining = ''; // NEW
      });
      await _saveBreaksCount(); // NEW

      _showSnackBar('✅ Clock In on $project', Colors.green);
    } catch (e) {
      _showSnackBar('❌ Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => isClockingIn = false);
    }
  }

  Future<void> _clockOut() async {
    if (isClockingIn || !hasActiveSession) return;
    setState(() => isClockingIn = true);

    try {
      final notes = await _askPayrollNotes();
      await _getCurrentLocation();

      final now = DateTime.now();
      final duration = sessionStartTime != null
          ? now.difference(sessionStartTime!)
          : Duration.zero;

      final record = {
        'type': 'check_out',
        'timestamp': now.toIso8601String(),
        'user': _viewUserKey, // CHANGED: per-user
        'project': activeProject,
        'duration_minutes': duration.inMinutes,
        'notes': notes,
        'location': currentLocation != null
            ? {
                'latitude': currentLocation!.latitude,
                'longitude': currentLocation!.longitude,
                'accuracy': currentLocation!.accuracy,
              }
            : null,
      };

      // Local per-user cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeSessionKey);
      final records = prefs.getStringList(_attendanceRecordsKey) ?? [];
      records.add(json.encode(record));
      await prefs.setStringList(_attendanceRecordsKey, records);

      // Firestore: per-user records and clear active session
      await _userAttendance.add(record);
      await _activeSessionDoc.delete();

      // NEW: store raw geolocation audit
      if (currentLocation != null) {
        await _userLocations.add({
          'type': 'check_out',
          'timestamp': now.toIso8601String(),
          'project': activeProject,
          'latitude': currentLocation!.latitude,
          'longitude': currentLocation!.longitude,
          'accuracy': currentLocation!.accuracy,
          'duration_minutes': duration.inMinutes,
          'notes': notes,
        });
      }

      final summary = {
        'project': activeProject,
        'start_time': sessionStartTime?.toIso8601String(),
        'end_time': now.toIso8601String(),
        'duration_minutes': duration.inMinutes,
        'duration_hours': (duration.inMinutes / 60).toStringAsFixed(1),
        'notes': notes,
      };
      await prefs.setString(_lastSessionSummaryKey, json.encode(summary));

      setState(() {
        hasActiveSession = false;
        lastSessionSummary = summary;
        activeProject = null;
        sessionStartTime = null;
        onBreak = false; // NEW: ensure break cleared
        breakEndTime = null; // NEW
        breakRemaining = ''; // NEW
      });

      _showSnackBar(
        '✅ Clock Out completed - ${duration.inHours}h ${duration.inMinutes % 60}m',
        Colors.green,
      );
    } catch (e) {
      _showSnackBar('❌ Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => isClockingIn = false);
    }
  }

  // Dialog para capturar Payroll Notes
  Future<String?> _askPayrollNotes() async {
    _payrollNotesController.text = '';
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Payroll Notes (Observations)'),
          content: TextField(
            controller: _payrollNotesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Write any note (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.pop(context, ''),
            ),
            ElevatedButton(
              child: Text('Save'),
              onPressed: () =>
                  Navigator.pop(context, _payrollNotesController.text.trim()),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: Duration(seconds: 3)),
    );
  }

  // Start a 15-minute break
  Future<void> _startBreak() async {
    if (!hasActiveSession || onBreak || breaksUsed >= 2) return;
    try {
      await _getCurrentLocation();
      final now = DateTime.now();
      breakEndTime = now.add(Duration(minutes: 15));
      onBreak = true;
      _updateBreakRemaining();
      _breakTimer?.cancel();
      _breakTimer = Timer.periodic(
        // FIX: correct Timer.periodic
        Duration(seconds: 1),
        (_) => _updateBreakRemaining(),
      );

      // Record break start (local & Firestore)
      final record = {
        'type': 'break_start',
        'timestamp': now.toIso8601String(),
        'user': _viewUserKey, // already per-user
        'project': activeProject,
        'duration_minutes': 15,
        'location': currentLocation != null
            ? {
                'latitude': currentLocation!.latitude,
                'longitude': currentLocation!.longitude,
                'accuracy': currentLocation!.accuracy,
              }
            : null,
      };

      final prefs = await SharedPreferences.getInstance();
      final records = prefs.getStringList(_attendanceRecordsKey) ?? [];
      records.add(json.encode(record));
      await prefs.setStringList(_attendanceRecordsKey, records);

      await _userAttendance.add(record);
      if (currentLocation != null) {
        await _userLocations.add({
          'type': 'break_start',
          'timestamp': now.toIso8601String(),
          'project': activeProject,
          'latitude': currentLocation!.latitude,
          'longitude': currentLocation!.longitude,
          'accuracy': currentLocation!.accuracy,
          'duration_minutes': 15,
        });
      }

      setState(() {});
      _showSnackBar('☕ Break started (15m)', Colors.orange);
    } catch (e) {
      _showSnackBar('❌ Error: $e', Colors.red);
    }
  }

  // Tick the countdown; auto-end when finished
  void _updateBreakRemaining() {
    if (breakEndTime == null) return;
    final now = DateTime.now();
    if (now.isAfter(breakEndTime!)) {
      _endBreak();
      return;
    }
    final remaining = breakEndTime!.difference(now);
    String two(int n) => n.toString().padLeft(2, '0');
    breakRemaining =
        '${two(remaining.inMinutes)}:${two(remaining.inSeconds % 60)}';
    if (mounted) setState(() {});
  }

  // End break, increment used, store record
  Future<void> _endBreak() async {
    _breakTimer?.cancel();
    breakEndTime = null;
    onBreak = false;
    breakRemaining = '';
    breaksUsed = (breaksUsed + 1).clamp(0, 2);
    await _saveBreaksCount();

    try {
      await _getCurrentLocation();
      final now = DateTime.now();

      final record = {
        'type': 'break_end',
        'timestamp': now.toIso8601String(),
        'user': _viewUserKey, // already per-user
        'project': activeProject,
        'breaks_used': breaksUsed,
        'location': currentLocation != null
            ? {
                'latitude': currentLocation!.latitude,
                'longitude': currentLocation!.longitude,
                'accuracy': currentLocation!.accuracy,
              }
            : null,
      };

      final prefs = await SharedPreferences.getInstance();
      final records = prefs.getStringList(_attendanceRecordsKey) ?? [];
      records.add(json.encode(record));
      await prefs.setStringList(_attendanceRecordsKey, records);

      await _userAttendance.add(record);
      if (currentLocation != null) {
        await _userLocations.add({
          'type': 'break_end',
          'timestamp': now.toIso8601String(),
          'project': activeProject,
          'latitude': currentLocation!.latitude,
          'longitude': currentLocation!.longitude,
          'accuracy': currentLocation!.accuracy,
          'breaks_used': breaksUsed,
        });
      }

      if (mounted) setState(() {});
      _showSnackBar('☕ Break ended (${breaksUsed}/2 used)', Colors.orange);
    } catch (e) {
      _showSnackBar('❌ Error: $e', Colors.red);
    }
  }

  Future<void> _restoreBreaksCount() async {
    final prefs = await SharedPreferences.getInstance();
    breaksUsed = prefs.getInt(_breaksUsedKey) ?? 0;
    setState(() {});
  }

  Future<void> _saveBreaksCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_breaksUsedKey, breaksUsed);
  }

  // Get today's records from local per-user cache
  Future<List<Map<String, dynamic>>> _getTodayRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_attendanceRecordsKey) ?? [];
    final List<Map<String, dynamic>> all = raw
        .map((s) {
          try {
            return json.decode(s) as Map<String, dynamic>;
          } catch (_) {
            return <String, dynamic>{};
          }
        })
        .where((m) => m.isNotEmpty)
        .toList();

    final today = DateTime.now();
    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    return all.where((m) {
      final ts = DateTime.tryParse(m['timestamp'] ?? '');
      return ts != null && isSameDay(ts, today);
    }).toList()
      ..sort((a, b) => (DateTime.parse(a['timestamp']))
          .compareTo(DateTime.parse(b['timestamp'])));
  }

  // Render a compact list of today's records
  Widget _todayRecordsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getTodayRecords(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(
              height: 28,
              child: Center(
                  child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))));
        }
        final records = snapshot.data ?? [];
        if (records.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Text('No records for today.',
                style: TextStyle(color: Colors.white70, fontSize: 11)),
          );
        }
        String labelFor(String t) {
          switch (t) {
            case 'check_in':
              return 'Clock In';
            case 'break_start':
              return 'Break Start';
            case 'break_end':
              return 'Break End';
            case 'check_out':
              return 'Clock Out';
            default:
              return t;
          }
        }

        return Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: records.map((r) {
              final timeStr = () {
                final dt = DateTime.tryParse(r['timestamp'] ?? '');
                return dt != null ? DateFormat('HH:mm').format(dt) : '--:--';
              }();
              final type = labelFor(r['type'] ?? '');
              return Text(
                '$timeStr • $type${r['notes'] != null && (r['notes'] as String).isNotEmpty ? ' • Notes: ${r['notes']}' : ''}',
                style: TextStyle(color: Colors.white70, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildClockBanner() {
    final bool isAdmin = widget.role == 'admin';
    final bool adminViewingUser =
        isAdmin && selectedUserEmail != null && selectedUserEmail!.isNotEmpty;

    // Admin without selected user: neutral banner, buttons disabled
    if (isAdmin && !adminViewingUser) {
      return Container(
        height: 120, // expanded to show records
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[600]!, Colors.blue[800]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: Offset(0, -2))
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(currentTime,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      Text(
                        currentLocation != null
                            ? '📍 ${currentLocation!.latitude.toStringAsFixed(2)}, ${currentLocation!.longitude.toStringAsFixed(2)}'
                            : '📍 Getting location...',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                        onPressed: null,
                        icon: Icon(Icons.play_arrow,
                            color: Colors.white, size: 18),
                        label: Text('Clock In',
                            style:
                                TextStyle(color: Colors.white, fontSize: 13))),
                    SizedBox(width: 8),
                    ElevatedButton.icon(
                        onPressed: null,
                        icon: Icon(Icons.stop, color: Colors.white, size: 18),
                        label: Text('Clock Out',
                            style:
                                TextStyle(color: Colors.white, fontSize: 13))),
                  ],
                ),
              ],
            ),
            _todayRecordsList(), // show today records
          ],
        ),
      );
    }

    if (lastSessionSummary != null && !hasActiveSession) {
      return Container(
        height: 130, // expanded to show records
        decoration: BoxDecoration(
          color: Colors.grey[400],
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: Offset(0, -2))
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                          'Last session: ${lastSessionSummary!['project'] ?? '-'}',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis),
                      Text(
                          'Duration: ${lastSessionSummary!['duration_hours']} hours',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
                      if ((lastSessionSummary!['notes'] ?? '')
                          .toString()
                          .isNotEmpty)
                        Text('Notes: ${lastSessionSummary!['notes']}',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Icon(Icons.check_circle, color: Colors.white, size: 32),
              ],
            ),
            _todayRecordsList(), // show today records
          ],
        ),
      );
    }

    // Active/inactive session banner
    String elapsed = '';
    if (hasActiveSession && sessionStartTime != null) {
      final diff = DateTime.now().difference(sessionStartTime!);
      String two(int n) => n.toString().padLeft(2, '0');
      elapsed =
          '${two(diff.inHours)}:${two(diff.inMinutes % 60)}:${two(diff.inSeconds % 60)}';
    }

    return Container(
      height: 140, // expanded to show records
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasActiveSession
              ? [Colors.orange[600]!, Colors.orange[800]!]
              : [Colors.blue[600]!, Colors.blue[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: Offset(0, -2))
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                        hasActiveSession
                            ? 'Working on: $activeProject'
                            : currentTime,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: hasActiveSession ? 14 : 18,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis),
                    if (hasActiveSession && sessionStartTime != null)
                      Text(
                          'Since: ${DateFormat('HH:mm').format(sessionStartTime!)} • Elapsed: $elapsed',
                          style: TextStyle(color: Colors.white70, fontSize: 12))
                    else
                      Text(
                          currentLocation != null
                              ? '📍 ${currentLocation!.latitude.toStringAsFixed(2)}, ${currentLocation!.longitude.toStringAsFixed(2)}'
                              : '📍 Getting location...',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
              if (hasActiveSession) ...[
                if (onBreak)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.orange[700],
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('Break: $breakRemaining',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  )
                else
                  ElevatedButton.icon(
                    onPressed:
                        (isClockingIn || breaksUsed >= 2) ? null : _startBreak,
                    icon: Icon(Icons.free_breakfast,
                        color: Colors.white, size: 18),
                    label: Text('Break (15m)',
                        style: TextStyle(color: Colors.white, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[600],
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20))),
                  ),
                SizedBox(width: 8),
              ],
              hasActiveSession
                  ? ElevatedButton.icon(
                      onPressed: isClockingIn ? null : _clockOut,
                      icon: isClockingIn
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Icon(Icons.stop, color: Colors.white, size: 18),
                      label: Text('Clock Out',
                          style: TextStyle(color: Colors.white, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20))),
                    )
                  : ElevatedButton.icon(
                      onPressed: isClockingIn ? null : _clockIn,
                      icon: isClockingIn
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Icon(Icons.play_arrow,
                              color: Colors.white, size: 18),
                      label: Text('Clock In',
                          style: TextStyle(color: Colors.white, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20))),
                    ),
            ], // <-- use closing bracket for the Row children list
          ), // <-- close Row properly
          _todayRecordsList(),
        ],
      ),
    );
  }

  Future<void> exportProjectsToCSV() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('projects').get();
    List<List<dynamic>> rows = [
      ['Name', 'Code', 'Manager', 'City', 'State', 'Country']
    ];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      rows.add([
        data['name'] ?? '',
        data['code'] ?? '',
        data['manager'] ?? '',
        data['city'] ?? '',
        data['state'] ?? '',
        data['country'] ?? ''
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

  void _openInvoiceScript() {
    html.window.open(
      'https://script.google.com/macros/s/AKfycby-V_zQUC1RTU78cusemDseT1pMAYEjwQqhouJ_LZCvbZ55EGlptKptlGm3gPJPi5Mp/exec',
      '_blank',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.role == 'admin';
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final displayUser = widget.activeUser ?? (firebaseUser?.email ?? 'Unknown');

    final bool adminViewingUser =
        isAdmin && selectedUserEmail != null && selectedUserEmail!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            Padding(
                padding: EdgeInsets.only(left: 16),
                child: Text('ELEVATE',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                        letterSpacing: 1))),
            Spacer(),
            Text(displayUser,
                style: TextStyle(fontSize: 14, color: Colors.white)),
            SizedBox(width: 8),
            TextButton(
              onPressed: () {
                if (firebaseUser != null) {
                  FirebaseAuth.instance.signOut();
                }
                widget.onSignOut();
              },
              child: Text('Sign Out', style: TextStyle(color: Colors.white)),
              style: TextButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  minimumSize: Size(0, 0)),
            ),
            SizedBox(width: 12),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    UpdatesCard(isAdmin: isAdmin),
                    ProjectsCard(isAdmin: isAdmin),
                    if (isAdmin) TeamMembersPanel(width: 900, isAdmin: isAdmin),
                    SummaryPanel(width: 900, activeUser: widget.activeUser),
                  ],
                ),
              ),
            ),
            // Only show the bottom banner for non-admin, or admin when viewing a specific user
            if (!isAdmin || adminViewingUser) _buildClockBanner(),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 16.0, bottom: 80.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: 'protective_film',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProtectiveFilmScreen(
                      isAdmin: isAdmin,
                      activeUser: widget.activeUser,
                    ),
                  ),
                );
              },
              backgroundColor: Colors.teal,
              child: Icon(Icons.layers, size: 32),
              tooltip: 'Protective Film Orders',
            ),
            SizedBox(width: 16),
            FloatingActionButton(
              heroTag: 'invoice',
              onPressed: _openInvoiceScript,
              backgroundColor: Colors.blue[800],
              child: Icon(Icons.attach_money, size: 32),
              tooltip: 'Add Invoice',
            ),
            if (isAdmin) ...[
              SizedBox(width: 16),
              FloatingActionButton(
                heroTag: 'create',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => CreateProjectDialog(),
                  );
                },
                backgroundColor: Colors.blue,
                child: Icon(Icons.add),
                tooltip: 'Create Project',
              ),
              SizedBox(width: 16),
              FloatingActionButton(
                heroTag: 'export',
                onPressed: exportProjectsToCSV,
                backgroundColor: Colors.orange,
                child: Icon(Icons.download),
                tooltip: 'Export Projects',
              ),
            ],
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

extension on Object? {
  void let(Function(Object) block) {
    if (this != null) block(this!);
  }
}
