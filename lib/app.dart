import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:car_insurance_app/core/services/notification_service.dart';
import 'package:car_insurance_app/core/theme/app_theme.dart';
import 'package:car_insurance_app/features/admin/admin_accident_reports_page.dart';
import 'package:car_insurance_app/features/admin/admin_home_page.dart';
import 'package:car_insurance_app/features/admin/admin_insurance_management_page.dart';
import 'package:car_insurance_app/features/auth/login_page.dart';
import 'package:car_insurance_app/features/home/home_page.dart';
import 'package:car_insurance_app/features/vehicles/vehicle_registration_page.dart';

/// Named routes used across the app.
class AppRoutes {
  AppRoutes._();

  static const adminAccidentReports = '/admin_accident_reports';
  static const adminInsuranceManagement = '/admin_insurance_management';
  static const vehicleRegistration = '/vehicle_registration';
}

class CarInsuranceApp extends StatelessWidget {
  const CarInsuranceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Insurance App',
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
      routes: {
        AppRoutes.adminAccidentReports: (context) => AdminAccidentReportsPage(),
        AppRoutes.adminInsuranceManagement:
            (context) => AdminInsuranceManagementPage(),
        AppRoutes.vehicleRegistration: (context) => VehicleRegistrationPage(),
      },
    );
  }
}

/// Chooses the first screen from the Firebase Auth state and the user's role:
/// signed-out users see [LoginPage], admins see [AdminHomePage], and everyone
/// else sees the customer [HomePage].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen(showLogo: true);
        }

        final user = snapshot.data;
        if (user == null) return LoginPage();

        NotificationService.saveDeviceToken();

        return FutureBuilder<DocumentSnapshot>(
          future:
              FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) return const _LoadingScreen();

            final userData = userSnapshot.data!;
            final isAdmin = userData.exists && userData['role'] == 'Admin';
            return ZoomIn(child: isAdmin ? AdminHomePage() : HomePage());
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({this.showLogo = false});

  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showLogo) ...[
                const Icon(Icons.directions_car, size: 120, color: Colors.white),
                const SizedBox(height: 24),
              ],
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
