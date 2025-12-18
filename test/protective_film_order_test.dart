import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elevate_app_v2/models/protective_film_order.dart';

void main() {
  group('ProtectiveFilmOrder Model Tests', () {
    test('should create a ProtectiveFilmOrder instance', () {
      final order = ProtectiveFilmOrder(
        projectName: 'Test Project',
        projectId: 'proj123',
        filmType: 'Clear',
        quantity: 100.0,
        unit: 'sqm',
        orderedBy: 'test@example.com',
        orderedAt: DateTime(2024, 1, 1),
        notes: 'Test notes',
      );

      expect(order.projectName, 'Test Project');
      expect(order.projectId, 'proj123');
      expect(order.filmType, 'Clear');
      expect(order.quantity, 100.0);
      expect(order.unit, 'sqm');
      expect(order.status, 'pending');
      expect(order.orderedBy, 'test@example.com');
      expect(order.orderedAt, DateTime(2024, 1, 1));
      expect(order.notes, 'Test notes');
    });

    test('should convert ProtectiveFilmOrder to Map', () {
      final order = ProtectiveFilmOrder(
        projectName: 'Test Project',
        projectId: 'proj123',
        filmType: 'Frosted',
        quantity: 50.5,
        unit: 'sqft',
        status: 'approved',
        orderedBy: 'admin@example.com',
        orderedAt: DateTime(2024, 1, 15),
        notes: 'Urgent order',
      );

      final map = order.toMap();

      expect(map['projectName'], 'Test Project');
      expect(map['projectId'], 'proj123');
      expect(map['filmType'], 'Frosted');
      expect(map['quantity'], 50.5);
      expect(map['unit'], 'sqft');
      expect(map['status'], 'approved');
      expect(map['orderedBy'], 'admin@example.com');
      expect(map['orderedAt'], isA<Timestamp>());
      expect(map['notes'], 'Urgent order');
    });

    test('should create ProtectiveFilmOrder from Map', () {
      final map = {
        'projectName': 'Another Project',
        'projectId': 'proj456',
        'filmType': 'Tinted',
        'quantity': 75.0,
        'unit': 'rolls',
        'status': 'ordered',
        'orderedBy': 'user@example.com',
        'orderedAt': Timestamp.fromDate(DateTime(2024, 2, 1)),
        'notes': 'Special requirements',
      };

      final order = ProtectiveFilmOrder.fromMap('order123', map);

      expect(order.id, 'order123');
      expect(order.projectName, 'Another Project');
      expect(order.projectId, 'proj456');
      expect(order.filmType, 'Tinted');
      expect(order.quantity, 75.0);
      expect(order.unit, 'rolls');
      expect(order.status, 'ordered');
      expect(order.orderedBy, 'user@example.com');
      expect(order.orderedAt, DateTime(2024, 2, 1));
      expect(order.notes, 'Special requirements');
    });

    test('should handle missing optional fields when creating from Map', () {
      final map = {
        'projectName': 'Minimal Project',
        'projectId': 'proj789',
        'filmType': 'Security',
        'quantity': 25,
        'unit': 'meters',
        'orderedBy': 'minimal@example.com',
        'orderedAt': Timestamp.fromDate(DateTime(2024, 3, 1)),
        // Missing status and notes
      };

      final order = ProtectiveFilmOrder.fromMap('order456', map);

      expect(order.id, 'order456');
      expect(order.status, 'pending'); // Default value
      expect(order.notes, isNull);
    });

    test('should handle quantity as int or double', () {
      final mapWithInt = {
        'projectName': 'Integer Project',
        'projectId': 'projInt',
        'filmType': 'Clear',
        'quantity': 100, // int
        'unit': 'sqm',
        'orderedBy': 'int@example.com',
        'orderedAt': Timestamp.fromDate(DateTime(2024, 4, 1)),
      };

      final order = ProtectiveFilmOrder.fromMap('orderInt', mapWithInt);
      expect(order.quantity, 100.0);
      expect(order.quantity, isA<double>());
    });

    test('should create order with default status as pending', () {
      final order = ProtectiveFilmOrder(
        projectName: 'Default Status Project',
        projectId: 'projDefault',
        filmType: 'UV Protection',
        quantity: 200.0,
        unit: 'sqm',
        orderedBy: 'default@example.com',
        orderedAt: DateTime.now(),
      );

      expect(order.status, 'pending');
    });

    test('should handle custom status values', () {
      final statuses = ['pending', 'approved', 'ordered', 'delivered'];
      
      for (final status in statuses) {
        final order = ProtectiveFilmOrder(
          projectName: 'Status Test',
          projectId: 'projStatus',
          filmType: 'Clear',
          quantity: 10.0,
          unit: 'sqm',
          status: status,
          orderedBy: 'status@example.com',
          orderedAt: DateTime.now(),
        );

        expect(order.status, status);
      }
    });
  });
}
