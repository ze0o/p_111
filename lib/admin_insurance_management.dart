import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';


class AdminInsuranceManagementPage extends StatefulWidget {
  @override
  _AdminInsuranceManagementPageState createState() =>
      _AdminInsuranceManagementPageState();
}

class _AdminInsuranceManagementPageState
    extends State<AdminInsuranceManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Insurance Management'),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'Pending'),
            Tab(text: 'Offers'),
            Tab(text: 'Approved'),
            Tab(text: 'Paid'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search by vehicle model or registration",
                prefixIcon: Icon(Icons.search, color: AppTheme.textLight),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRequestsList('Pending'),
                _buildRequestsList('Offers Created'),
                _buildRequestsList('Approved'),
                _buildRequestsList('Paid'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('insurance_requests')
              .where('status', isEqualTo: status)
              .orderBy('timestamp', descending: true)
              .snapshots(),
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
                  Icons.hourglass_empty,
                  size: 80,
                  color: AppTheme.textLight.withOpacity(0.5),
                ),
                SizedBox(height: 16),
                Text(
                  'No $status requests found',
                  style: TextStyle(fontSize: 18, color: AppTheme.textLight),
                ),
              ],
            ),
          );
        }

        final filteredDocs =
            snapshot.data!.docs.where((doc) {
              if (_searchQuery.isEmpty) return true;

              // We need to fetch vehicle details to filter by model or registration
              return true; // Initially return all, we'll filter in FutureBuilder
            }).toList();

        return ListView.builder(
          padding: EdgeInsets.only(bottom: 16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final request = filteredDocs[index];
            final data = request.data() as Map<String, dynamic>;

            return FutureBuilder<DocumentSnapshot>(
              future:
                  FirebaseFirestore.instance
                      .collection('vehicles')
                      .doc(data['vehicleId'])
                      .get(),
              builder: (context, vehicleSnapshot) {
                if (!vehicleSnapshot.hasData) {
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text('Loading...'),
                      subtitle: LinearProgressIndicator(),
                    ),
                  );
                }

                final vehicleData =
                    vehicleSnapshot.data!.data() as Map<String, dynamic>?;
                if (vehicleData == null) {
                  return SizedBox();
                }

                final model = vehicleData['model'] as String;
                final regNumber = vehicleData['registrationNumber'] as String;

                // Apply search filter
                if (_searchQuery.isNotEmpty &&
                    !model.toLowerCase().contains(_searchQuery) &&
                    !regNumber.toLowerCase().contains(_searchQuery)) {
                  return SizedBox();
                }

                // Format timestamp
                String formattedDate = 'Unknown date';
                if (data['timestamp'] != null) {
                  final timestamp = data['timestamp'] as Timestamp;
                  formattedDate = DateFormat(
                    'MMM dd, yyyy',
                  ).format(timestamp.toDate());
                }

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    model,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Reg: $regNumber',
                                    style: TextStyle(color: AppTheme.textLight),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: AppTheme.textLight,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Requested: $formattedDate',
                              style: TextStyle(color: AppTheme.textLight),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.attach_money,
                              size: 16,
                              color: AppTheme.textLight,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Current Value: \$${data['currentValue'].toStringAsFixed(2)}',
                              style: TextStyle(color: AppTheme.textLight),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              data['hadAccident'] == true
                                  ? Icons.report_problem
                                  : Icons.verified,
                              size: 16,
                              color:
                                  data['hadAccident'] == true
                                      ? AppTheme.warningOrange
                                      : AppTheme.successGreen,
                            ),
                            SizedBox(width: 4),
                            Text(
                              data['hadAccident'] == true
                                  ? 'Previous Accidents: Yes'
                                  : 'Previous Accidents: No',
                              style: TextStyle(
                                color:
                                    data['hadAccident'] == true
                                        ? AppTheme.warningOrange
                                        : AppTheme.successGreen,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Divider(),
                        SizedBox(height: 8),

                        // Different actions based on status
                        if (status == 'Pending')
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildActionButton(
                                'Create Offers',
                                Icons.local_offer,
                                AppTheme.primaryColor,
                                () => _showCreateOffersDialog(
                                  context,
                                  request.id,
                                  data['currentValue'],
                                  model,
                                  regNumber,
                                  data['hadAccident'] == true,
                                ),
                              ),
                              _buildActionButton(
                                'Reject',
                                Icons.cancel,
                                AppTheme.errorRed,
                                () => _rejectRequest(request.id),
                              ),
                            ],
                          ),

                        if (status == 'Offers Created')
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Offers',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 8),
                              if (data['offers'] != null)
                                ..._buildOffersList(
                                  data['offers'] as Map<String, dynamic>,
                                ),
                              SizedBox(height: 8),
                              if (data['selectedOffer'] != null)
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(
                                      0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: AppTheme.primaryColor,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Customer selected: ${data['selectedOfferType']} (\$${data['selectedOffer'].toStringAsFixed(2)})',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildActionButton(
                                    'Approve',
                                    Icons.check_circle,
                                    AppTheme.successGreen,
                                    data['selectedOffer'] != null
                                        ? () => _approveRequest(
                                          request.id,
                                          model,
                                          regNumber,
                                          data['userId'],
                                        )
                                        : null,
                                  ),
                                  _buildActionButton(
                                    'Reject',
                                    Icons.cancel,
                                    AppTheme.errorRed,
                                    () => _rejectRequest(request.id),
                                  ),
                                ],
                              ),
                            ],
                          ),

                        if (status == 'Approved')
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildActionButton(
                                'Waiting for Payment',
                                Icons.payments,
                                AppTheme.warningOrange,
                                null,
                              ),
                            ],
                          ),

                        if (status == 'Paid')
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildActionButton(
                                'View Policy',
                                Icons.visibility,
                                AppTheme.primaryColor,
                                () => _viewPolicy(request.id),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback? onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  List<Widget> _buildOffersList(Map<String, dynamic> offers) {
    List<Widget> offerWidgets = [];

    offers.forEach((type, amount) {
      offerWidgets.add(
        Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type, style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    _getOfferDescription(type),
                    style: TextStyle(fontSize: 12, color: AppTheme.textLight),
                  ),
                ],
              ),
              Text(
                '\$${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      );
    });

    return offerWidgets;
  }

  String _getOfferDescription(String type) {
    switch (type) {
      case 'Basic':
        return 'Liability coverage only';
      case 'Standard':
        return 'Liability + collision coverage';
      case 'Premium':
        return 'Comprehensive coverage';
      default:
        return '';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.grey;
      case 'Offers Created':
        return AppTheme.accentColor;
      case 'Approved':
        return AppTheme.warningOrange;
      case 'Paid':
        return AppTheme.successGreen;
      default:
        return AppTheme.textLight;
    }
  }

  void _showCreateOffersDialog(
    BuildContext context,
    String requestId,
    double baseValue,
    String vehicleModel,
    String vehicleReg,
    bool hadAccident,
  ) {
    // Calculate initial offers based on vehicle value
    // Basic: 5% of value
    // Standard: 7% of value
    // Premium: 10% of value
    // If vehicle had accidents, increase rates by 20%
    double accidentMultiplier = hadAccident ? 1.2 : 1.0;

    final basicController = TextEditingController(
      text: (baseValue * 0.05 * accidentMultiplier).toStringAsFixed(2),
    );
    final standardController = TextEditingController(
      text: (baseValue * 0.07 * accidentMultiplier).toStringAsFixed(2),
    );
    final premiumController = TextEditingController(
      text: (baseValue * 0.10 * accidentMultiplier).toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Create Insurance Offers'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$vehicleModel ($vehicleReg)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Vehicle Value: \$${baseValue.toStringAsFixed(2)}',
                  style: TextStyle(color: AppTheme.textLight),
                ),
                if (hadAccident)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Note: Rates increased by 20% due to previous accidents',
                      style: TextStyle(
                        color: AppTheme.warningOrange,
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                    ),
                  ),
                SizedBox(height: 16),

                // Basic offer
                _buildOfferInput(
                  'Basic Plan',
                  'Liability coverage only',
                  basicController,
                ),
                SizedBox(height: 16),

                // Standard offer
                _buildOfferInput(
                  'Standard Plan',
                  'Liability + collision coverage',
                  standardController,
                ),
                SizedBox(height: 16),

                // Premium offer
                _buildOfferInput(
                  'Premium Plan',
                  'Comprehensive coverage',
                  premiumController,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _createOffers(
                  requestId,
                  double.parse(basicController.text),
                  double.parse(standardController.text),
                  double.parse(premiumController.text),
                  vehicleModel,
                  vehicleReg,
                );
              },
              child: Text('Send Offers'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOfferInput(
    String title,
    String description,
    TextEditingController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          description,
          style: TextStyle(color: AppTheme.textLight, fontSize: 12),
        ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            prefixText: '\$ ',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Future<void> _createOffers(
    String requestId,
    double basicAmount,
    double standardAmount,
    double premiumAmount,
    String vehicleModel,
    String vehicleReg,
  ) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get the request to find the user ID
      final requestDoc =
          await FirebaseFirestore.instance
              .collection('insurance_requests')
              .doc(requestId)
              .get();

      final requestData = requestDoc.data();
      if (requestData == null) {
        throw Exception('Request data not found');
      }

      final userId = requestData['userId'] as String;

      // Update the request with offers
      await FirebaseFirestore.instance
          .collection('insurance_requests')
          .doc(requestId)
          .update({
            'offers': {
              'Basic': basicAmount,
              'Standard': standardAmount,
              'Premium': premiumAmount,
            },
            'status': 'Offers Created',
            'offersCreatedAt': FieldValue.serverTimestamp(),
          });

      // Send notification to user
      await NotificationService.sendUserNotification(
        userId,
        'Insurance Offers Available',
        'We have prepared insurance offers for your $vehicleModel ($vehicleReg)',
        {'type': 'offers', 'requestId': requestId},
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Offers created and sent to customer'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating offers: ${e.toString()}'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _approveRequest(
    String requestId,
    String vehicleModel,
    String vehicleReg,
    String userId,
  ) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Update the request status
      await FirebaseFirestore.instance
          .collection('insurance_requests')
          .doc(requestId)
          .update({'status': 'Approved'});

      // Send notification to user
      await NotificationService.sendUserNotification(
        userId,
        'Insurance Request Approved',
        'Your insurance request for $vehicleModel ($vehicleReg) has been approved. Please proceed with payment.',
        {'type': 'approval', 'requestId': requestId},
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request approved and notification sent to customer'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving request: ${e.toString()}'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    // Show confirmation dialog
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject Request'),
        content: Text('Are you sure you want to reject this insurance request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Reject'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirm) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get the request to find the user ID and vehicle details
      final requestDoc = await FirebaseFirestore.instance
          .collection('insurance_requests')
          .doc(requestId)
          .get();
    
      final requestData = requestDoc.data();
      if (requestData == null) return;
    
      final userId = requestData['userId'] as String;
      final vehicleId = requestData['vehicleId'] as String;
    
      // Get vehicle details
      final vehicleDoc = await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(vehicleId)
          .get();
    
      final vehicleData = vehicleDoc.data();
      if (vehicleData == null) return;
    
      final vehicleModel = vehicleData['model'] as String;
      final vehicleReg = vehicleData['registrationNumber'] as String;
    
      // Update the request status - Fix: Change 'Rejected' to a status that's handled in the UI
      await FirebaseFirestore.instance
          .collection('insurance_requests')
          .doc(requestId)
          .update({
            'status': 'Rejected', // This is correct, but ensure UI handles this status
            'rejectionDate': FieldValue.serverTimestamp(),
          });
    
      // Send notification to user
      await NotificationService.sendUserNotification(
        userId,
        'Insurance Request Rejected',
        'Your insurance request for $vehicleModel ($vehicleReg) has been rejected. Please contact support for more information.',
        {'type': 'rejection', 'requestId': requestId},
      );
    
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request rejected and notification sent to customer'),
          backgroundColor: AppTheme.warningOrange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rejecting request: ${e.toString()}'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _viewPolicy(String requestId) {
    // Navigate to policy details page
    // This could be implemented in a future update
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Policy viewing feature coming soon'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
    
    // If you want to implement this feature now, you could use:
    /*
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PolicyDetailsPage(requestId: requestId),
      ),
    );
    */
  }
}
