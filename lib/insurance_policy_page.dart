import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'theme/app_theme.dart';

class InsurancePolicyPage extends StatefulWidget {
  @override
  _InsurancePolicyPageState createState() => _InsurancePolicyPageState();
}

class _InsurancePolicyPageState extends State<InsurancePolicyPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _selectedYear;
  String? _selectedRegistration;
  bool _isLoading = false;
  List<Map<String, dynamic>> _filteredPolicies = [];
  List<Map<String, dynamic>> _allPolicies = [];

  @override
  void initState() {
    super.initState();
    _loadPolicies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPolicies() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get all insurance requests with relevant statuses
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('insurance_requests')
              .where('userId', isEqualTo: user.uid)
              .where(
                'status',
                whereIn: ['Pending', 'Offers', 'Approved', 'Paid'],
              )
              .orderBy('timestamp', descending: true)
              .get();

      List<Map<String, dynamic>> policies = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();

        // Get vehicle details
        final vehicleDoc =
            await FirebaseFirestore.instance
                .collection('vehicles')
                .doc(data['vehicleId'])
                .get();

        if (vehicleDoc.exists) {
          final vehicleData = vehicleDoc.data()!;

          // Format timestamp
          String formattedDate = 'Unknown date';
          if (data['timestamp'] != null) {
            final timestamp = data['timestamp'] as Timestamp;
            formattedDate = DateFormat(
              'MMM dd, yyyy',
            ).format(timestamp.toDate());
          }

          // Get policy year
          int policyYear = DateTime.now().year;
          if (data['timestamp'] != null) {
            final timestamp = data['timestamp'] as Timestamp;
            policyYear = timestamp.toDate().year;
          }

          policies.add({
            'id': doc.id,
            'vehicleId': data['vehicleId'],
            'model': vehicleData['model'] ?? 'Unknown model',
            'registrationNumber':
                vehicleData['registrationNumber'] ?? 'Unknown',
            'year': vehicleData['year'] ?? 0,
            'policyYear': policyYear,
            'insuranceAmount': data['calculatedAmount'] ?? 0.0,
            'currentValue': data['currentValue'] ?? 0.0,
            'originalPrice': data['originalPrice'] ?? 0.0,
            'status': data['status'] ?? 'Unknown',
            'date': formattedDate,
            'timestamp': data['timestamp'],
          });
        }
      }

      setState(() {
        _allPolicies = policies;
        _filteredPolicies = policies;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading policies: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterPolicies() {
    if (_allPolicies.isEmpty) return;

    setState(() {
      _filteredPolicies =
          _allPolicies.where((policy) {
            // Filter by search query
            bool matchesSearch =
                _searchQuery.isEmpty ||
                policy['model'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                policy['registrationNumber'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );

            // Filter by selected year
            bool matchesYear =
                _selectedYear == null || policy['policyYear'] == _selectedYear;

            // Filter by selected registration
            bool matchesRegistration =
                _selectedRegistration == null ||
                policy['registrationNumber'] == _selectedRegistration;

            return matchesSearch && matchesYear && matchesRegistration;
          }).toList();
    });
  }

  List<int> _getAvailableYears() {
    final Set<int> years = {};
    for (var policy in _allPolicies) {
      years.add(policy['policyYear'] as int);
    }
    return years.toList()..sort((a, b) => b.compareTo(a)); // Sort descending
  }

  List<String> _getAvailableRegistrations() {
    final Set<String> registrations = {};
    for (var policy in _allPolicies) {
      registrations.add(policy['registrationNumber'] as String);
    }
    return registrations.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Insurance Policies'),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
        ),
      ),
      body: Column(
        children: [
          // Search and filter section
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search by model or registration number",
                    prefixIcon: Icon(Icons.search, color: AppTheme.textLight),
                    suffixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                              icon: Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                                _filterPolicies();
                              },
                            )
                            : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    _filterPolicies();
                  },
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        decoration: InputDecoration(
                          labelText: 'Filter by Year',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        value: _selectedYear,
                        items: [
                          DropdownMenuItem<int>(
                            value: null,
                            child: Text('All Years'),
                          ),
                          ..._getAvailableYears().map((year) {
                            return DropdownMenuItem<int>(
                              value: year,
                              child: Text(year.toString()),
                            );
                          }).toList(),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedYear = value;
                          });
                          _filterPolicies();
                        },
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Filter by Registration',
                          prefixIcon: Icon(Icons.app_registration),
                        ),
                        value: _selectedRegistration,
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text('All Vehicles'),
                          ),
                          ..._getAvailableRegistrations().map((reg) {
                            return DropdownMenuItem<String>(
                              value: reg,
                              child: Text(reg),
                            );
                          }).toList(),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedRegistration = value;
                          });
                          _filterPolicies();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Policies list
          Expanded(
            child:
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _filteredPolicies.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.policy_outlined,
                            size: 80,
                            color: AppTheme.textLight.withOpacity(0.5),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No insurance policies found',
                            style: TextStyle(
                              fontSize: 18,
                              color: AppTheme.textLight,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Try changing your search criteria',
                            style: TextStyle(color: AppTheme.textLight),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: EdgeInsets.only(bottom: 16),
                      itemCount: _filteredPolicies.length,
                      itemBuilder: (context, index) {
                        final policy = _filteredPolicies[index];
                        return _buildPolicyCard(policy);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyCard(Map<String, dynamic> policy) {
    return Card(
      margin: EdgeInsets.fromLTRB(16, 16, 16, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showPolicyDetails(policy),
        borderRadius: BorderRadius.circular(12),
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
                      color:
                          policy['status'] == 'Paid'
                              ? AppTheme.successGreen
                              : AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      policy['status'],
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Policy Year: ${policy['policyYear']}',
                    style: TextStyle(color: AppTheme.textLight, fontSize: 14),
                  ),
                  Spacer(),
                  Text(
                    policy['date'],
                    style: TextStyle(color: AppTheme.textLight, fontSize: 14),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                policy['model'],
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Registration: ${policy['registrationNumber']}',
                style: TextStyle(fontSize: 14, color: AppTheme.textDark),
              ),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Insurance Amount',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textLight,
                        ),
                      ),
                      Text(
                        '\$${policy['insuranceAmount'].toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Vehicle Value',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textLight,
                        ),
                      ),
                      Text(
                        '\$${policy['currentValue'].toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPolicyDetails(Map<String, dynamic> policy) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Insurance Policy Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Vehicle details section
              Text(
                'Vehicle Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              SizedBox(height: 12),
              _buildDetailRow('Model', policy['model']),
              _buildDetailRow(
                'Registration Number',
                policy['registrationNumber'],
              ),
              _buildDetailRow('Manufacturing Year', policy['year'].toString()),

              SizedBox(height: 24),

              // Policy details section
              Text(
                'Policy Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              SizedBox(height: 12),
              _buildDetailRow('Policy Year', policy['policyYear'].toString()),
              _buildDetailRow('Issue Date', policy['date']),
              _buildDetailRow('Status', policy['status']),

              SizedBox(height: 24),

              // Financial details section
              Text(
                'Financial Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              SizedBox(height: 12),
              _buildDetailRow(
                'Original Vehicle Price',
                '\$${policy['originalPrice'].toStringAsFixed(2)}',
              ),
              _buildDetailRow(
                'Current Vehicle Value',
                '\$${policy['currentValue'].toStringAsFixed(2)}',
              ),
              _buildDetailRow(
                'Insurance Amount',
                '\$${policy['insuranceAmount'].toStringAsFixed(2)}',
              ),

              SizedBox(height: 32),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      // Download or share policy functionality could be added here
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Policy download feature coming soon'),
                        ),
                      );
                    },
                    icon: Icon(Icons.download),
                    label: Text('Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Print policy functionality could be added here
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Policy print feature coming soon'),
                        ),
                      );
                    },
                    icon: Icon(Icons.print),
                    label: Text('Print'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppTheme.textLight)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
