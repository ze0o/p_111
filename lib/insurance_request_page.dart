import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'payment_page.dart';
import 'theme/app_theme.dart';

class InsuranceRequestPage extends StatefulWidget {
  final String vehicleId;
  final double originalPrice;
  final int year;

  const InsuranceRequestPage({
    Key? key,
    required this.vehicleId,
    required this.originalPrice,
    required this.year,
  }) : super(key: key);

  @override
  _InsuranceRequestPageState createState() => _InsuranceRequestPageState();
}

class _InsuranceRequestPageState extends State<InsuranceRequestPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _hasExistingRequest = false;
  String? _existingRequestId;
  String? _existingRequestStatus;

  // Vehicle data
  String _vehicleModel = '';
  String _vehicleReg = '';
  bool _hadAccident = false;
  double _consumptionRate = 0.10; // Default 10%

  // Calculated values
  double _currentValue = 0.0;
  double _calculatedAmount = 0.0;

  // Offers data
  Map<String, dynamic>? _offers;
  String? _selectedOfferType;
  double? _selectedOfferAmount;

  @override
  void initState() {
    super.initState();
    _loadVehicleData();
    _checkExistingRequest();
    _calculateCurrentValue();
  }

  Future<void> _loadVehicleData() async {
    try {
      final vehicleDoc =
          await FirebaseFirestore.instance
              .collection('vehicles')
              .doc(widget.vehicleId)
              .get();

      if (vehicleDoc.exists) {
        final data = vehicleDoc.data()!;
        setState(() {
          _vehicleModel = data['model'] ?? 'Unknown';
          _vehicleReg = data['registrationNumber'] ?? 'Unknown';
          _hadAccident = data['hadAccident'] ?? false;
          _consumptionRate = data['consumptionRate'] ?? 0.10;
        });
      }
    } catch (e) {
      print('Error loading vehicle data: $e');
    }
  }

  Future<void> _checkExistingRequest() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('insurance_requests')
              .where('userId', isEqualTo: user.uid)
              .where('vehicleId', isEqualTo: widget.vehicleId)
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        final latestRequest = querySnapshot.docs.first;
        final status = latestRequest['status'] as String;

        // Check if there's an active request
        if (status != 'Rejected' && status != 'Expired') {
          setState(() {
            _hasExistingRequest = true;
            _existingRequestId = latestRequest.id;
            _existingRequestStatus = status;

            // If offers are available, load them
            if (status == 'Offers Created' && latestRequest['offers'] != null) {
              _offers = Map<String, dynamic>.from(latestRequest['offers']);
            }

            // If an offer was selected, load it
            if (latestRequest['selectedOfferType'] != null) {
              _selectedOfferType = latestRequest['selectedOfferType'];
              _selectedOfferAmount = latestRequest['selectedOffer'];
            }
          });
        }
      }
    } catch (e) {
      print('Error checking existing request: $e');
    }
  }

  void _calculateCurrentValue() {
    // Calculate current value based on original price, year, and consumption rate
    int age = DateTime.now().year - widget.year;
    double depreciation = 1.0 - (_consumptionRate * age);

    // Ensure value doesn't go below 10% of original price
    depreciation = depreciation.clamp(0.1, 1.0);

    double currentValue = widget.originalPrice * depreciation;
    double calculatedAmount =
        currentValue * 0.05; // Base insurance is 5% of current value

    setState(() {
      _currentValue = currentValue;
      _calculatedAmount = calculatedAmount;
    });
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Create new insurance request
      await FirebaseFirestore.instance.collection('insurance_requests').add({
        'userId': user.uid,
        'vehicleId': widget.vehicleId,
        'originalPrice': widget.originalPrice,
        'currentValue': _currentValue,
        'calculatedAmount': _calculatedAmount,
        'consumptionRate': _consumptionRate,
        'hadAccident': _hadAccident,
        'status': 'Pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insurance request submitted successfully!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectOffer(String offerType, double amount) async {
    if (_existingRequestId == null) return;

    setState(() {
      _isLoading = true;
      _selectedOfferType = offerType;
      _selectedOfferAmount = amount;
    });

    try {
      // Update the request with selected offer
      await FirebaseFirestore.instance
          .collection('insurance_requests')
          .doc(_existingRequestId)
          .update({
            'selectedOfferType': offerType,
            'selectedOffer': amount,
            'status': 'Offer Selected',
          });

      setState(() {
        _existingRequestStatus = 'Offer Selected';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$offerType plan selected successfully!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting offer: ${e.toString()}'),
          backgroundColor: AppTheme.errorRed,
        ),
      );

      setState(() {
        _selectedOfferType = null;
        _selectedOfferAmount = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _proceedToPayment() {
    if (_existingRequestId == null ||
        _selectedOfferType == null ||
        _selectedOfferAmount == null) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => PaymentPage(
              requestId: _existingRequestId!,
              amount: _selectedOfferAmount!,
              planType: _selectedOfferType!,
              vehicleModel: _vehicleModel,
              vehicleReg: _vehicleReg,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Insurance Request'),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vehicle info card
              FadeInUp(
                duration: Duration(seconds: 1),
                curve: Curves.easeIn,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: FadeIn(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vehicle Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Model:'),
                              Text(
                                _vehicleModel,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Registration:'),
                              Text(
                                _vehicleReg,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Year:'),
                              Text(
                                '${widget.year}',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Original Price:'),
                              Text(
                                '\$${widget.originalPrice.toStringAsFixed(2)}',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Current Value:'),
                              Text(
                                '\$${_currentValue.toStringAsFixed(2)}',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Consumption Rate:'),
                              Text(
                                '${(_consumptionRate * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      _hadAccident
                                          ? AppTheme.warningOrange
                                          : null,
                                ),
                              ),
                            ],
                          ),
                          if (_hadAccident)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Note: Consumption rate increased due to previous accidents',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: AppTheme.warningOrange,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24),

              if (_hasExistingRequest)
                _buildExistingRequestSection()
              else
                _buildNewRequestSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewRequestSection() {
    return FadeInUp(
      delay: Duration(milliseconds: 500),
      duration: Duration(seconds: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Insurance Request',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          SizedBox(height: 16),

          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estimated Insurance',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Based on your vehicle\'s current value, we estimate your insurance amount to be:',
                    style: TextStyle(color: AppTheme.textLight),
                  ),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      '\$${_calculatedAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'This is an estimated amount. Our team will review your request and provide you with personalized offers.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                      color: AppTheme.textLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitRequest,
              child:
                  _isLoading
                      ? CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                      : Text(
                        'REQUEST INSURANCE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingRequestSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Insurance Request',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(_existingRequestStatus ?? ''),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _existingRequestStatus ?? 'Unknown',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),

        if (_existingRequestStatus == 'Pending')
          _buildPendingRequestCard()
        else if (_existingRequestStatus == 'Offers Created')
          _buildOffersCard()
        else if (_existingRequestStatus == 'Offer Selected')
          _buildSelectedOfferCard()
        else if (_existingRequestStatus == 'Approved')
          _buildApprovedCard()
        else if (_existingRequestStatus == 'Paid')
          _buildPaidCard()
        else
          _buildGenericStatusCard(),
      ],
    );
  }

  Widget _buildPendingRequestCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hourglass_empty, color: Colors.orange, size: 24),
                SizedBox(width: 8),
                Text(
                  'Request Under Review',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Your insurance request is currently being reviewed by our team. We will provide you with personalized offers soon.',
              style: TextStyle(color: AppTheme.textLight),
            ),
            SizedBox(height: 16),
            LinearProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              backgroundColor: Colors.grey.shade200,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffersCard() {
    if (_offers == null || _offers!.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('No offers available yet')),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select an Insurance Plan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Choose the plan that best fits your needs',
          style: TextStyle(color: AppTheme.textLight),
        ),
        SizedBox(height: 16),

        // Basic plan
        _buildOfferCard(
          'Basic',
          'Liability coverage only',
          'Covers damage to other vehicles and property',
          _offers!['Basic'],
          _selectedOfferType == 'Basic',
        ),
        SizedBox(height: 16),

        // Standard plan
        _buildOfferCard(
          'Standard',
          'Liability + collision coverage',
          'Covers damage to your vehicle and others',
          _offers!['Standard'],
          _selectedOfferType == 'Standard',
        ),
        SizedBox(height: 16),

        // Premium plan
        _buildOfferCard(
          'Premium',
          'Comprehensive coverage',
          'Full coverage including theft, fire, and natural disasters',
          _offers!['Premium'],
          _selectedOfferType == 'Premium',
        ),
      ],
    );
  }

  Widget _buildOfferCard(
    String type,
    String title,
    String description,
    double amount,
    bool isSelected,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.white,
      child: InkWell(
        onTap: _isLoading ? null : () => _selectOffer(type, amount),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$type Plan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color:
                          isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.textDark,
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: AppTheme.primaryColor),
                ],
              ),
              SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textDark,
                ),
              ),
              SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(color: AppTheme.textLight, fontSize: 12),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Premium:', style: TextStyle(color: AppTheme.textLight)),
                  Text(
                    '\$${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color:
                          isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.textDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedOfferCard() {
    if (_selectedOfferType == null || _selectedOfferAmount == null) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('No plan selected')),
        ),
      );
    }

    String description = '';
    switch (_selectedOfferType) {
      case 'Basic':
        description = 'Liability coverage only';
        break;
      case 'Standard':
        description = 'Liability + collision coverage';
        break;
      case 'Premium':
        description = 'Comprehensive coverage';
        break;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppTheme.successGreen,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'Plan Selected',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Selected Plan:'),
                Text(
                  '$_selectedOfferType',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Coverage:'),
                Text(
                  description,
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Premium Amount:'),
                Text(
                  '\$${_selectedOfferAmount!.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Your selected plan is awaiting approval. Once approved, you will be able to proceed with payment.',
              style: TextStyle(color: AppTheme.textLight, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovedCard() {
    if (_selectedOfferType == null || _selectedOfferAmount == null) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('No plan selected')),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified, color: AppTheme.successGreen, size: 24),
                SizedBox(width: 8),
                Text(
                  'Plan Approved',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Your $_selectedOfferType plan has been approved! You can now proceed with payment to activate your insurance coverage.',
              style: TextStyle(color: AppTheme.textLight),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Premium Amount:'),
                Text(
                  '\$${_selectedOfferAmount!.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _proceedToPayment,
                child:
                    _isLoading
                        ? CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        )
                        : Text(
                          'PROCEED TO PAYMENT',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaidCard() {
    if (_selectedOfferType == null || _selectedOfferAmount == null) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('No plan selected')),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppTheme.successGreen.withOpacity(0.1),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified, color: AppTheme.successGreen, size: 24),
                SizedBox(width: 8),
                Text(
                  'Insurance Active',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.successGreen,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Your $_selectedOfferType plan is now active! Your vehicle is fully insured according to your selected coverage.',
              style: TextStyle(color: AppTheme.textLight),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Premium Amount:'),
                Text(
                  '\$${_selectedOfferAmount!.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: Icon(Icons.check_circle),
                label: Text(
                  'DONE',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenericStatusCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request Status: ${_existingRequestStatus ?? "Unknown"}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Your insurance request is being processed. Please check back later for updates.',
              style: TextStyle(color: AppTheme.textLight),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.grey;
      case 'Offers Created':
        return AppTheme.accentColor;
      case 'Offer Selected':
        return AppTheme.primaryColor;
      case 'Approved':
        return AppTheme.warningOrange;
      case 'Paid':
        return AppTheme.successGreen;
      case 'Rejected':
        return AppTheme.errorRed;
      default:
        return AppTheme.textLight;
    }
  }
}
