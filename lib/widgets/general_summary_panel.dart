import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class GeneralSummaryPanel extends StatefulWidget {
  final double width;
  final void Function(String email)? onUserSelected; // <-- nuevo parámetro opcional
  const GeneralSummaryPanel({Key? key, this.width = 900, this.onUserSelected}) : super(key: key);

  @override
  State<GeneralSummaryPanel> createState() => _GeneralSummaryPanelState();
}

class _GeneralSummaryPanelState extends State<GeneralSummaryPanel> {
  late DateTime weekStart;
  late DateTime weekEnd;

  @override
  void initState() {
    super.initState();
    weekStart = _getCurrentWeekStart();
    weekEnd = weekStart.add(Duration(days: 6));
  }

  static DateTime _getCurrentWeekStart([DateTime? from]) {
    final now = from ?? DateTime.now();
    return now.subtract(Duration(days: now.weekday % 7));
  }

  void _pickPayPeriod(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: weekStart,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select a day of the week',
    );
    if (picked != null) {
      final newWeekStart = _getCurrentWeekStart(picked);
      setState(() {
        weekStart = newWeekStart;
        weekEnd = newWeekStart.add(Duration(days: 6));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    return Container(
      width: widget.width,
      margin: const EdgeInsets.only(top: 10, left: 10, bottom: 0),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('General Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _pickPayPeriod(context),
                child: Text('Pay period', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size(0, 0),
                ),
              ),
              SizedBox(width: 8),
              Text(
                '${DateFormat('MMM d').format(weekStart)} - ${DateFormat('d, yyyy').format(weekEnd)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          SizedBox(height: 6),
          FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .where('visible', isEqualTo: true) // <-- solo usuarios visibles
                .get(),
            builder: (context, userSnap) {
              if (!userSnap.hasData) return SizedBox(height: 40, child: Center(child: CircularProgressIndicator()));
              final users = userSnap.data!.docs;
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('work_sessions')
                    .where('date', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(weekStart))
                    .where('date', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(weekEnd))
                    .snapshots(),
                builder: (context, wsSnap) {
                  if (!wsSnap.hasData) return SizedBox(height: 40, child: Center(child: CircularProgressIndicator()));
                  final sessions = wsSnap.data!.docs;

                  final dayLabels = days.map((d) => DateFormat('E').format(d)).toList();

                  Map<String, List<double>> userDayHours = {};
                  Map<String, double> userTotalHours = {};
                  List<double> totalPerDay = List.filled(days.length, 0);
                  double grandTotal = 0;

                  for (var user in users) {
                    final data = user.data() as Map<String, dynamic>;
                    final email = data['email'];
                    List<double> hoursPerDay = [];
                    double total = 0;
                    for (var i = 0; i < days.length; i++) {
                      final dayStr = DateFormat('yyyy-MM-dd').format(days[i]);
                      QueryDocumentSnapshot? session;
                      try {
                        session = sessions.firstWhere(
                          (s) => s['user'] == email && s['date'] == dayStr && s['clockIn'] != null && s['clockOut'] != null,
                        );
                      } catch (_) {
                        session = null;
                      }
                      double h = 0;
                      if (session != null) {
                        final inTime = (session['clockIn'] as Timestamp).toDate();
                        final outTime = (session['clockOut'] as Timestamp).toDate();
                        h = outTime.difference(inTime).inMinutes / 60.0;
                      }
                      hoursPerDay.add(h);
                      total += h;
                      totalPerDay[i] += h;
                      grandTotal += h;
                    }
                    userDayHours[email] = hoursPerDay;
                    userTotalHours[email] = total;
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 35,
                      dataRowMinHeight: 24,
                      dataRowMaxHeight: 28,
                      columnSpacing: 40,
                      horizontalMargin: 6,
                      headingRowColor: MaterialStateProperty.all(Colors.grey[200]),
                      columns: [
                        DataColumn(label: Text('Name', style: TextStyle(fontSize: 12))),
                        DataColumn(label: Text('Email', style: TextStyle(fontSize: 12))),
                        ...List.generate(days.length, (i) {
                          final label = DateFormat('E').format(days[i]);
                          final dayNum = DateFormat('d').format(days[i]);
                          return DataColumn(
                            label: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(label, style: TextStyle(fontSize: 12)),
                                Text(dayNum, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                              ],
                            ),
                          );
                        }),
                        DataColumn(label: Text('Total', style: TextStyle(fontSize: 12))),
                      ],
                      rows: [
                        ...users.map((user) {
                          final data = user.data() as Map<String, dynamic>;
                          final email = data['email'] ?? '-';
                          final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
                          final hoursList = userDayHours[email] ?? List.filled(days.length, 0);
                          final total = userTotalHours[email] ?? 0;
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(name, style: TextStyle(fontSize: 12)),
                                onTap: () {
                                  if (widget.onUserSelected != null) widget.onUserSelected!(email);
                                },
                              ),
                              DataCell(
                                Text(email, style: TextStyle(fontSize: 12)),
                                onTap: () {
                                  if (widget.onUserSelected != null) widget.onUserSelected!(email);
                                },
                              ),
                              ...hoursList.map((h) => DataCell(Text(h > 0 ? h.toStringAsFixed(2) : '-', style: TextStyle(fontSize: 12)))),
                              DataCell(Text(total > 0 ? total.toStringAsFixed(2) : '-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                            ],
                          );
                        }),
                        // Fila de totales
                        DataRow(
                          cells: [
                            DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            DataCell(Text('', style: TextStyle(fontSize: 12))),
                            ...totalPerDay.map((h) => DataCell(Text(h > 0 ? h.toStringAsFixed(2) : '-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                            DataCell(Text(grandTotal > 0 ? grandTotal.toStringAsFixed(2) : '-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}