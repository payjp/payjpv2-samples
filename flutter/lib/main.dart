import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const PayjpCheckoutApp());
}

class PayjpCheckoutApp extends StatelessWidget {
  const PayjpCheckoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PAY.JP Checkout V2',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const HomeScreen(),
    );
  }
}
