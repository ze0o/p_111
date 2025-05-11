import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'login_page.dart';
import 'admin_accident_reports_page.dart';
import 'admin_insurance_management.dart';
import 'theme/app_theme.dart';

class AdminHomePage extends StatefulWidget {
  @override
  _AdminHomePageState createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey();
  final TextEditingController _newAdminEmailController =
      TextEditingController();
  final TextEditingController _newAdminPasswordController =
      TextEditingController();
  int _selectedIndex = 0;

  void logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
      (route) => false,
    );
  }

  Future<void> _createNewAdmin(BuildContext context) async {
    final email = _newAdminEmailController.text.trim();
    final password = _newAdminPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter both email and password.")),
      );
      return;
    }

    const apiKey = 'AIzaSyBrPvKdNX28B85l9ynlecMYrHRYskFjHGc';

    final url = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey',
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'returnSecureToken': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final uid = data['localId'];

        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'email': email,
          'role': 'Admin',
        });

        _showSuccessDialog(email);
      } else {
        final error = jsonDecode(response.body)['error']['message'];
        _showErrorDialog("Failed to create user: $error");
      }
    } catch (e) {
      _showErrorDialog("An error occurred: ${e.toString()}");
    }
  }

  void _showSuccessDialog(String email) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text("✅ Success"),
            content: Text("Admin '$email' created successfully."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("OK"),
              ),
            ],
          ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text("❌ Error"),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("OK"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Admin Dashboard"),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add),
            tooltip: "Add Admin",
            onPressed: () => _showCreateAdminDialog(),
          ),
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () => logout(context),
          ),
        ],
      ),
      body: _getSelectedScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.textLight,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.policy), label: 'Insurance'),
          BottomNavigationBarItem(
            icon: Icon(Icons.report_problem),
            label: 'Accidents',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }

  Widget _getSelectedScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return AdminInsuranceManagementPage();
      case 2:
        return AdminAccidentReportsPage();
      case 3:
        return _buildAnalytics();
      default:
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Admin Dashboard',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          SizedBox(height: 24),

          // Stats cards
          Row(
            children: [
              _buildStatCard(
                'Pending Requests',
                _buildPendingRequestsCount(),
                Icons.hourglass_empty,
                Colors.orange,
              ),
              SizedBox(width: 16),
              _buildStatCard(
                'Active Policies',
                _buildActivePoliciesCount(),
                Icons.verified,
                Colors.green,
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard(
                'Accident Reports',
                _buildAccidentReportsCount(),
                Icons.report_problem,
                Colors.red,
              ),
              SizedBox(width: 16),
              _buildStatCard(
                'Total Vehicles',
                _buildTotalVehiclesCount(),
                Icons.directions_car,
                Colors.blue,
              ),
            ],
          ),

          SizedBox(height: 32),
          Text(
            'Recent Insurance Requests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          SizedBox(height: 16),
          _buildRecentRequests(),

          SizedBox(height: 32),
          Text(
            'Recent Accident Reports',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          SizedBox(height: 16),
          _buildRecentAccidents(),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    Widget countWidget,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(color: AppTheme.textLight, fontSize: 14),
                  ),
                ],
              ),
              SizedBox(height: 12),
              countWidget,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingRequestsCount() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('insurance_requests')
              .where('status', isEqualTo: 'Pending')
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Text(
            '...',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          );
        }

        return Text(
          '${snapshot.data!.docs.length}',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        );
      },
    );
  }

  Widget _buildActivePoliciesCount() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('insurance_requests')
              .where('status', isEqualTo: 'Approved')
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Text(
            '...',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          );
        }

        return Text(
          '${snapshot.data!.docs.length}',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        );
      },
    );
  }

  Widget _buildAccidentReportsCount() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance.collection('accident_reports').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Text(
            '...',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          );
        }

        return Text(
          '${snapshot.data!.docs.length}',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        );
      },
    );
  }

  Widget _buildTotalVehiclesCount() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('vehicles').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Text(
            '...',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          );
        }

        return Text(
          '${snapshot.data!.docs.length}',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        );
      },
    );
  }

  Widget _buildRecentRequests() {
    return Container(
      height: 200,
      child: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('insurance_requests')
                .orderBy('timestamp', descending: true)
                .limit(5)
                .snapshots(),
        builder: (context, snapshot) {
          print('Snapshot data: ${snapshot.data}');
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final requests = snapshot.data!.docs;

          if (requests.isEmpty) {
            return Center(child: Text('No insurance requests found'));
          }

          return ListView.builder(
            physics: NeverScrollableScrollPhysics(),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final data = request.data() as Map<String, dynamic>;
              final status = data['status'] as String;

              return FutureBuilder<DocumentSnapshot>(
                future:
                    FirebaseFirestore.instance
                        .collection('vehicles')
                        .doc(data['vehicleId'])
                        .get(),
                builder: (context, vehicleSnapshot) {
                  if (!vehicleSnapshot.hasData) {
                    return ListTile(
                      title: Text('Loading...'),
                      subtitle: LinearProgressIndicator(),
                    );
                  }

                  final vehicleData =
                      vehicleSnapshot.data!.data() as Map<String, dynamic>?;
                  if (vehicleData == null) {
                    return SizedBox();
                  }

                  final model = vehicleData['model'] as String;
                  final regNumber = vehicleData['registrationNumber'] as String;

                  return ListTile(
                    leading: Icon(Icons.directions_car),
                    title: Text('$model ($regNumber)'),
                    subtitle: Text('Status: $status'),
                    trailing: Icon(Icons.chevron_right),
                    onTap: () {
                      setState(() {
                        _selectedIndex = 1; // Switch to Insurance tab
                      });
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRecentAccidents() {
    return Container(
      height: 200,
      child: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('accident_reports')
                .orderBy('timestamp', descending: true)
                .limit(5)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final reports = snapshot.data!.docs;

          if (reports.isEmpty) {
            return Center(child: Text('No accident reports found'));
          }

          return ListView.builder(
            physics: NeverScrollableScrollPhysics(),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              final data = report.data() as Map<String, dynamic>;
              final damageCost = data['damageCost'] as double;
              final isHeavy = data['heavyDamage'] as bool? ?? false;

              return FutureBuilder<DocumentSnapshot>(
                future:
                    FirebaseFirestore.instance
                        .collection('vehicles')
                        .doc(data['vehicleId'])
                        .get(),
                builder: (context, vehicleSnapshot) {
                  if (!vehicleSnapshot.hasData) {
                    return ListTile(
                      title: Text('Loading...'),
                      subtitle: LinearProgressIndicator(),
                    );
                  }

                  final vehicleData =
                      vehicleSnapshot.data!.data() as Map<String, dynamic>?;
                  if (vehicleData == null) {
                    return SizedBox();
                  }

                  final model = vehicleData['model'] as String;
                  final regNumber = vehicleData['registrationNumber'] as String;

                  return ListTile(
                    leading: Icon(
                      Icons.report_problem,
                      color: isHeavy ? Colors.red : Colors.orange,
                    ),
                    title: Text('$model ($regNumber)'),
                    subtitle: Text(
                      'Damage: \$${damageCost.toStringAsFixed(2)}',
                    ),
                    trailing: Icon(Icons.chevron_right),
                    onTap: () {
                      setState(() {
                        _selectedIndex = 2; // Switch to Accidents tab
                      });
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAnalytics() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics,
            size: 80,
            color: AppTheme.primaryColor.withOpacity(0.5),
          ),
          SizedBox(height: 16),
          Text(
            'Analytics Dashboard',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Coming soon in a future update',
            style: TextStyle(color: AppTheme.textLight, fontSize: 16),
          ),
          SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('This feature is under development')),
              );
            },
            child: Text('Generate Reports'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateAdminDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Create New Admin"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _newAdminEmailController,
                decoration: InputDecoration(labelText: "Admin Email"),
              ),
              TextField(
                controller: _newAdminPasswordController,
                decoration: InputDecoration(labelText: "Admin Password"),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: Text("Create"),
              onPressed: () async {
                Navigator.pop(context);
                await _createNewAdmin(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _showOfferDialog(
    BuildContext context,
    String requestId,
    double baseValue,
  ) {
    final offer1Controller = TextEditingController(
      text: (baseValue * 1.0).toStringAsFixed(2),
    );
    final offer2Controller = TextEditingController(
      text: (baseValue * 1.1).toStringAsFixed(2),
    );
    final offer3Controller = TextEditingController(
      text: (baseValue * 1.2).toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Create 3 Offers"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: offer1Controller,
                decoration: InputDecoration(labelText: "Basic Offer"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: offer2Controller,
                decoration: InputDecoration(labelText: "Standard Offer"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: offer3Controller,
                decoration: InputDecoration(labelText: "Premium Offer"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('insurance_requests')
                    .doc(requestId)
                    .update({
                      'offers': {
                        'Basic': double.parse(offer1Controller.text),
                        'Standard': double.parse(offer2Controller.text),
                        'Premium': double.parse(offer3Controller.text),
                      },
                      'status': 'Offers Created',
                    });
                Navigator.pop(context);
              },
              child: Text("Save Offers"),
            ),
          ],
        );
      },
    );
  }
}
