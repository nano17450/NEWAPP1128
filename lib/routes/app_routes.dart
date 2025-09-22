import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../main.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/': (context) => AuthGate(),
  // otras rutas...
};