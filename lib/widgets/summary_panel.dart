import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SummaryPanel extends StatefulWidget {
  final double width;
  final DateTime? initialWeekStart;
  final String activeUser;
  final bool isEditable;

  const SummaryPanel({
    Key? key,
    this.width = 900,
    this.initialWeekStart,
    required this.activeUser,
    this.isEditable = false,
  }) : super(key: key);

  @override
  State<SummaryPanel> createState() => _SummaryPanelState();
}

class _SummaryPanelState extends State<SummaryPanel> {
  late DateTime weekStart;
  late DateTime weekEnd;
  int? editingRowIndex;
  Map<int, Map<String, dynamic>> editedRows =
      {}; // rowIdx -> {clockIn, clockOut, dayTotal, notes}

  @override
  void initState() {
    super.initState();
    weekStart = widget.initialWeekStart ?? _getCurrentWeekStart();
    weekEnd = weekStart.add(Duration(days: 6));
  }

  static DateTime _getCurrentWeekStart([DateTime? from]) {
    final now = from ?? DateTime.now();
    // Sunday as start of week
    return now.subtract(Duration(days: now.weekday % 7));
  }

  double _roundToHalf(double value) {
    return (value * 2).round() / 2.0;
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

  void _previousWeek() {
    setState(() {
      weekStart = weekStart.subtract(Duration(days: 7));
      weekEnd = weekStart.add(Duration(days: 6));
    });
  }

  void _nextWeek() {
    setState(() {
      weekStart = weekStart.add(Duration(days: 7));
      weekEnd = weekStart.add(Duration(days: 6));
    });
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    return LayoutBuilder(
      builder: (context, constraints) {
        final double panelWidth = widget.width > constraints.maxWidth
            ? constraints.maxWidth
            : widget.width;

        return Container(
          width: panelWidth,
          margin: const EdgeInsets.only(top: 8, left: 8, bottom: 0),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Summary',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Spacer(),
                  if (widget.isEditable && editedRows.isNotEmpty)
                    ElevatedButton(
                      onPressed: () async {
                        for (final entry in editedRows.entries) {
                          final rowIdx = entry.key;
                          final data = entry.value;
                          final dayKey =
                              DateFormat('yyyy-MM-dd').format(days[rowIdx]);
                          final session = await FirebaseFirestore.instance
                              .collection('work_sessions')
                              .where('user', isEqualTo: widget.activeUser)
                              .where('date', isEqualTo: dayKey)
                              .get();
                          if (session.docs.isNotEmpty) {
                            final sessionId = session.docs.first.id;
                            await FirebaseFirestore.instance
                                .collection('work_sessions')
                                .doc(sessionId)
                                .update({
                              'clockIn': data['clockIn'],
                              'clockOut': data['clockOut'],
                              'payrollNotes': data['notes'],
                            });
                            await FirebaseFirestore.instance
                                .collection('work_sessions_edits')
                                .add({
                              'sessionId': sessionId,
                              'editedBy': widget.activeUser,
                              'editType': 'adminEdit',
                              'newClockIn': data['clockIn'],
                              'newClockOut': data['clockOut'],
                              'newTotalHours': data['dayTotal'],
                              'newPayrollNotes': data['notes'],
                              'date': dayKey,
                              'timestamp': FieldValue.serverTimestamp(),
                            });
                          }
                        }
                        editedRows.clear();
                        setState(() {
                          editingRowIndex = null;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        textStyle: TextStyle(fontSize: 12),
                      ),
                      child: Text('Guardar'),
                    ),
                  if (widget.isEditable) SizedBox(width: 6),
                  if (widget.isEditable)
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          editingRowIndex = null;
                          editedRows.clear();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        textStyle: TextStyle(fontSize: 12),
                      ),
                      child: Text('Editar'),
                    ),
                  // Agrega este espacio extra para separar el botón Editar del botón X
                  if (widget.isEditable) SizedBox(width: 32),
                ],
              ),
              SizedBox(height: 4),
              if (widget.isEditable)
                Text('Usuario: ${widget.activeUser}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: weekStart,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        helpText: 'Select a day of the week',
                      );
                      if (picked != null) {
                        final newWeekStart =
                            picked.subtract(Duration(days: picked.weekday % 7));
                        setState(() {
                          weekStart = newWeekStart;
                          weekEnd = newWeekStart.add(Duration(days: 6));
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      textStyle: TextStyle(fontSize: 12),
                    ),
                    child: Text('Pay period'),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '${DateFormat('MMM d').format(weekStart)} - ${DateFormat('d, yyyy').format(weekEnd)}',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                  ),
                ],
              ),
              SizedBox(height: 8),
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('work_sessions')
                    .where('user', isEqualTo: widget.activeUser)
                    .where('date',
                        whereIn: days
                            .map((d) => DateFormat('yyyy-MM-dd').format(d))
                            .toList())
                    .get(),
                builder: (context, snapshot) {
                  Map<String, dynamic> sessionsByDate = {};
                  if (snapshot.hasData) {
                    for (var doc in snapshot.data!.docs) {
                      sessionsByDate[doc['date']] = {
                        ...doc.data() as Map<String, dynamic>,
                        'id': doc.id
                      };
                    }
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowHeight: 28,
                      dataRowMinHeight: 18,
                      dataRowMaxHeight: 24,
                      columnSpacing: 100,
                      horizontalMargin: 6,
                      headingRowColor:
                          WidgetStateProperty.all(Colors.grey[200]),
                      columns: [
                        DataColumn(
                            label:
                                Text('Date', style: TextStyle(fontSize: 12))),
                        DataColumn(
                            label: Text('Project',
                                style: TextStyle(fontSize: 12))),
                        DataColumn(
                            label: Text('Clock In',
                                style: TextStyle(fontSize: 12))),
                        DataColumn(
                            label: Text('Clock Out',
                                style: TextStyle(fontSize: 12))),
                        DataColumn(
                            label: Text('Day Total',
                                style: TextStyle(fontSize: 12))),
                        DataColumn(
                            label: Text('Payroll Notes',
                                style: TextStyle(fontSize: 12))),
                      ],
                      rows: [
                        for (int rowIdx = 0; rowIdx < days.length; rowIdx++)
                          (() {
                            final dayKey =
                                DateFormat('yyyy-MM-dd').format(days[rowIdx]);
                            final session = sessionsByDate[dayKey];
                            final clockIn = session?['clockIn'] != null
                                ? (session['clockIn'] as Timestamp).toDate()
                                : null;
                            final clockOut = session?['clockOut'] != null
                                ? (session['clockOut'] as Timestamp).toDate()
                                : null;
                            final payrollNotes = session?['payrollNotes'] ?? '';
                            double dayTotal = (clockIn != null &&
                                    clockOut != null)
                                ? clockOut.difference(clockIn).inMinutes / 60.0
                                : 0.0;

                            TextEditingController clockInCtrl =
                                TextEditingController(
                              text: editedRows[rowIdx]?['clockIn'] != null
                                  ? DateFormat('HH:mm').format(
                                      (editedRows[rowIdx]!['clockIn']
                                          as DateTime))
                                  : (clockIn != null
                                      ? DateFormat('HH:mm').format(clockIn)
                                      : ''),
                            );
                            TextEditingController clockOutCtrl =
                                TextEditingController(
                              text: editedRows[rowIdx]?['clockOut'] != null
                                  ? DateFormat('HH:mm').format(
                                      (editedRows[rowIdx]!['clockOut']
                                          as DateTime))
                                  : (clockOut != null
                                      ? DateFormat('HH:mm').format(clockOut)
                                      : ''),
                            );
                            TextEditingController dayTotalCtrl =
                                TextEditingController(
                              text: editedRows[rowIdx]?['dayTotal'] != null
                                  ? editedRows[rowIdx]!['dayTotal']
                                      .toStringAsFixed(2)
                                  : (dayTotal > 0
                                      ? dayTotal.toStringAsFixed(2)
                                      : ''),
                            );
                            TextEditingController notesCtrl =
                                TextEditingController(
                              text:
                                  editedRows[rowIdx]?['notes'] ?? payrollNotes,
                            );

                            return DataRow(
                              cells: [
                                DataCell(Text(DateFormat('E, MMM d')
                                    .format(days[rowIdx]))),
                                DataCell(Text(session?['project'] ?? '-')),
                                if (widget.isEditable &&
                                    editingRowIndex == rowIdx)
                                  DataCell(
                                    SizedBox(
                                      width: 70,
                                      child: TextFormField(
                                        controller: clockInCtrl,
                                        decoration:
                                            InputDecoration(hintText: 'HH:mm'),
                                        onChanged: (value) {
                                          final parts = value.split(':');
                                          if (parts.length == 2) {
                                            final hour =
                                                int.tryParse(parts[0]) ?? 8;
                                            final minute =
                                                int.tryParse(parts[1]) ?? 0;
                                            final newClockIn = DateTime(
                                                days[rowIdx].year,
                                                days[rowIdx].month,
                                                days[rowIdx].day,
                                                hour,
                                                minute);
                                            DateTime? newClockOut =
                                                editedRows[rowIdx]
                                                        ?['clockOut'] ??
                                                    clockOut;
                                            double newDayTotal = 0.0;
                                            if (newClockOut != null &&
                                                newClockIn
                                                    .isBefore(newClockOut)) {
                                              newDayTotal = _roundToHalf(
                                                  newClockOut
                                                          .difference(
                                                              newClockIn)
                                                          .inMinutes /
                                                      60.0);
                                            }
                                            setState(() {
                                              editedRows[rowIdx] = {
                                                ...?editedRows[rowIdx],
                                                'clockIn': newClockIn,
                                                'clockOut': newClockOut,
                                                'dayTotal': newDayTotal,
                                                'notes': notesCtrl.text,
                                              };
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  )
                                else
                                  DataCell(Text(clockIn != null
                                      ? DateFormat('HH:mm').format(clockIn)
                                      : '-')),
                                if (widget.isEditable &&
                                    editingRowIndex == rowIdx)
                                  DataCell(
                                    SizedBox(
                                      width: 70,
                                      child: TextFormField(
                                        controller: clockOutCtrl,
                                        decoration:
                                            InputDecoration(hintText: 'HH:mm'),
                                        onChanged: (value) {
                                          final parts = value.split(':');
                                          if (parts.length == 2) {
                                            final hour =
                                                int.tryParse(parts[0]) ?? 16;
                                            final minute =
                                                int.tryParse(parts[1]) ?? 0;
                                            final newClockOut = DateTime(
                                                days[rowIdx].year,
                                                days[rowIdx].month,
                                                days[rowIdx].day,
                                                hour,
                                                minute);
                                            DateTime? newClockIn =
                                                editedRows[rowIdx]
                                                        ?['clockIn'] ??
                                                    clockIn ??
                                                    DateTime(
                                                        days[rowIdx].year,
                                                        days[rowIdx].month,
                                                        days[rowIdx].day,
                                                        8,
                                                        0);
                                            double newDayTotal = 0.0;
                                            if (newClockIn != null &&
                                                newClockOut
                                                    .isAfter(newClockIn)) {
                                              newDayTotal = _roundToHalf(
                                                  newClockOut
                                                          .difference(
                                                              newClockIn)
                                                          .inMinutes /
                                                      60.0);
                                            }
                                            setState(() {
                                              editedRows[rowIdx] = {
                                                ...?editedRows[rowIdx],
                                                'clockIn': newClockIn,
                                                'clockOut': newClockOut,
                                                'dayTotal': newDayTotal,
                                                'notes': notesCtrl.text,
                                              };
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  )
                                else
                                  DataCell(Text(clockOut != null
                                      ? DateFormat('HH:mm').format(clockOut)
                                      : '-')),
                                if (widget.isEditable &&
                                    editingRowIndex == rowIdx)
                                  DataCell(
                                    SizedBox(
                                      width: 60,
                                      child: TextFormField(
                                        controller: dayTotalCtrl,
                                        keyboardType:
                                            TextInputType.numberWithOptions(
                                                decimal: true),
                                        decoration:
                                            InputDecoration(hintText: 'Horas'),
                                        onChanged: (value) {
                                          double hours =
                                              double.tryParse(value) ?? 0.0;
                                          hours = _roundToHalf(hours);
                                          DateTime newClockIn =
                                              editedRows[rowIdx]?['clockIn'] ??
                                                  clockIn ??
                                                  DateTime(
                                                      days[rowIdx].year,
                                                      days[rowIdx].month,
                                                      days[rowIdx].day,
                                                      8,
                                                      0);
                                          DateTime newClockOut = newClockIn.add(
                                              Duration(
                                                  minutes:
                                                      (hours * 60).round()));
                                          setState(() {
                                            editedRows[rowIdx] = {
                                              ...?editedRows[rowIdx],
                                              'clockIn': newClockIn,
                                              'clockOut': newClockOut,
                                              'dayTotal': hours,
                                              'notes': notesCtrl.text,
                                            };
                                          });
                                        },
                                      ),
                                    ),
                                  )
                                else
                                  DataCell(Text(dayTotal > 0
                                      ? '${dayTotal.toStringAsFixed(2)} h'
                                      : '-')),
                                if (widget.isEditable &&
                                    editingRowIndex == rowIdx)
                                  DataCell(
                                    TextFormField(
                                      controller: notesCtrl,
                                      onChanged: (value) {
                                        setState(() {
                                          editedRows[rowIdx] = {
                                            ...?editedRows[rowIdx],
                                            'clockIn': editedRows[rowIdx]
                                                    ?['clockIn'] ??
                                                clockIn,
                                            'clockOut': editedRows[rowIdx]
                                                    ?['clockOut'] ??
                                                clockOut,
                                            'dayTotal': editedRows[rowIdx]
                                                    ?['dayTotal'] ??
                                                dayTotal,
                                            'notes': value,
                                          };
                                        });
                                      },
                                    ),
                                  )
                                else
                                  DataCell(Text(payrollNotes)),
                              ],
                              onSelectChanged: widget.isEditable
                                  ? (selected) {
                                      setState(() {
                                        editingRowIndex = rowIdx;
                                      });
                                    }
                                  : null,
                            );
                          })(),
                        DataRow(
                          cells: [
                            DataCell(Text('Total',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Container()),
                            DataCell(Container()),
                            DataCell(Container()),
                            DataCell(
                              Text(
                                (() {
                                  double total = 0;
                                  for (final day in days) {
                                    final session = sessionsByDate[
                                        DateFormat('yyyy-MM-dd').format(day)];
                                    if (session != null &&
                                        session['clockIn'] != null &&
                                        session['clockOut'] != null) {
                                      final clockIn =
                                          (session['clockIn'] as Timestamp)
                                              .toDate();
                                      final clockOut =
                                          (session['clockOut'] as Timestamp)
                                              .toDate();
                                      total += clockOut
                                              .difference(clockIn)
                                              .inMinutes /
                                          60.0;
                                    }
                                  }
                                  for (final data in editedRows.values) {
                                    if (data['dayTotal'] != null)
                                      total += data['dayTotal'];
                                  }
                                  return '${total.toStringAsFixed(2)} h';
                                })(),
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataCell(Container()),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
