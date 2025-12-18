import 'package:cloud_firestore/cloud_firestore.dart';

class ProtectiveFilmOrder {
  final String? id;
  final String projectName;
  final String projectId;
  final String filmType;
  final double quantity;
  final String unit;
  final String status; // pending, approved, ordered, delivered
  final String orderedBy;
  final DateTime orderedAt;
  final String? notes;

  ProtectiveFilmOrder({
    this.id,
    required this.projectName,
    required this.projectId,
    required this.filmType,
    required this.quantity,
    required this.unit,
    this.status = 'pending',
    required this.orderedBy,
    required this.orderedAt,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'projectName': projectName,
      'projectId': projectId,
      'filmType': filmType,
      'quantity': quantity,
      'unit': unit,
      'status': status,
      'orderedBy': orderedBy,
      'orderedAt': Timestamp.fromDate(orderedAt),
      'notes': notes,
    };
  }

  factory ProtectiveFilmOrder.fromMap(String id, Map<String, dynamic> map) {
    return ProtectiveFilmOrder(
      id: id,
      projectName: map['projectName'] ?? '',
      projectId: map['projectId'] ?? '',
      filmType: map['filmType'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      unit: map['unit'] ?? 'sqm',
      status: map['status'] ?? 'pending',
      orderedBy: map['orderedBy'] ?? '',
      orderedAt: (map['orderedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: map['notes'],
    );
  }
}
