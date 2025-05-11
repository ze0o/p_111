import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'theme/app_theme.dart';

class AdminAccidentReportsPage extends StatefulWidget {
  @override
  _AdminAccidentReportsPageState createState() =>
      _AdminAccidentReportsPageState();
}

class _AdminAccidentReportsPageState extends State<AdminAccidentReportsPage> {
  String _searchQuery = '';
  bool _showHeavyDamageOnly = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Accident Reports'),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showHeavyDamageOnly
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined,
            ),
            onPressed: () {
              setState(() {
                _showHeavyDamageOnly = !_showHeavyDamageOnly;
              });
            },
            tooltip: 'Filter Heavy Damage',
          ),
        ],
      ),
      body: Column(
        children: [_buildSearchBar(), Expanded(child: _buildReportsList())],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: "Search by vehicle registration",
          prefixIcon: Icon(Icons.search, color: AppTheme.textLight),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value.toLowerCase());
        },
      ),
    );
  }

  Widget _buildReportsList() {
    Query query = FirebaseFirestore.instance
        .collection('accident_reports')
        .orderBy('timestamp', descending: true);

    if (_showHeavyDamageOnly) {
      query = query.where('heavyDamage', isEqualTo: true);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.report_problem_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                SizedBox(height: 16),
                Text(
                  'No accident reports found',
                  style: TextStyle(fontSize: 18, color: AppTheme.textLight),
                ),
              ],
            ),
          );
        }

        final reports = snapshot.data!.docs;

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            final reportData = report.data() as Map<String, dynamic>;
            final vehicleId = reportData['vehicleId'] as String;

            return FutureBuilder<DocumentSnapshot>(
              future:
                  FirebaseFirestore.instance
                      .collection('vehicles')
                      .doc(vehicleId)
                      .get(),
              builder: (context, vehicleSnapshot) {
                if (!vehicleSnapshot.hasData) {
                  return Card(
                    margin: EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      title: Text('Loading vehicle details...'),
                      subtitle: LinearProgressIndicator(),
                    ),
                  );
                }

                final vehicleData =
                    vehicleSnapshot.data!.data() as Map<String, dynamic>?;
                if (vehicleData == null) {
                  return SizedBox(); // Skip if vehicle data not found
                }

                final regNumber = vehicleData['registrationNumber'] as String;
                final model = vehicleData['model'] as String;

                // Apply search filter
                if (_searchQuery.isNotEmpty &&
                    !regNumber.toLowerCase().contains(_searchQuery) &&
                    !model.toLowerCase().contains(_searchQuery)) {
                  return SizedBox(); // Skip if doesn't match search
                }

                return _buildReportCard(
                  report.id,
                  reportData,
                  vehicleData,
                ).slideInLeft();
              },
            );
          },
        );
      },
    );
  }

  Widget _buildReportCard(
    String reportId,
    Map<String, dynamic> report,
    Map<String, dynamic> vehicle,
  ) {
    final regNumber = vehicle['registrationNumber'] as String;
    final model = vehicle['model'] as String;
    final description = report['description'] as String;
    final damageCost = report['damageCost'] as double? ?? 0.0;
    final isHeavy = report['heavyDamage'] as bool? ?? false;

    // Format timestamp
    String formattedDate = 'N/A';
    if (report['timestamp'] != null) {
      final timestamp = report['timestamp'] as Timestamp;
      formattedDate = DateFormat('dd/MM/yyyy').format(timestamp.toDate());
    }

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHeavy ? AppTheme.errorRed : AppTheme.warningOrange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isHeavy ? 'Heavy Damage' : 'Minor Damage',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Reported: $formattedDate',
                  style: TextStyle(color: AppTheme.textLight, fontSize: 14),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              '$model (Reg: $regNumber)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Damage Cost: \$${damageCost.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isHeavy ? AppTheme.errorRed : AppTheme.textDark,
              ),
            ),
            SizedBox(height: 16),
            Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(description),

            // Show user information
            FutureBuilder<DocumentSnapshot>(
              future:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(vehicle['userId'])
                      .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return SizedBox(height: 8);
                }

                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>?;
                if (userData == null) {
                  return SizedBox(height: 8);
                }

                final email = userData['email'] as String;

                return Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      Icon(Icons.person, size: 16, color: AppTheme.textLight),
                      SizedBox(width: 4),
                      Text(
                        'Reported by: $email',
                        style: TextStyle(
                          color: AppTheme.textLight,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: Icon(Icons.check_circle),
                  label: Text('Mark as Reviewed'),
                  onPressed: () {
                    FirebaseFirestore.instance
                        .collection('accident_reports')
                        .doc(reportId)
                        .update({
                          'reviewed': true,
                          'reviewedAt': FieldValue.serverTimestamp(),
                        });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Report marked as reviewed'),
                        backgroundColor: AppTheme.successGreen,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
