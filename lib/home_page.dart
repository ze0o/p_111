// home_page.dart - Final version with insurance status and UI enhancements
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'vehicle_registration_page.dart';
import 'edit_vehicle_page.dart';
import 'login_page.dart';
import 'insurance_request_page.dart';
import 'insurance_policy_page.dart';
import 'accident_report_page.dart';
import 'theme/app_theme.dart';
import 'widgets/car_card.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  String searchQuery = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehicles =
        FirebaseFirestore.instance
            .collection('vehicles')
            .where('userId', isEqualTo: user!.uid)
            .snapshots();

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 180.0,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  "My Vehicles",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -50,
                        bottom: -20,
                        child: Opacity(
                          opacity: 0.2,
                          child: Icon(
                            Icons.directions_car,
                            size: 200,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.receipt_long),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InsurancePolicyPage(),
                      ),
                    );
                  },
                  tooltip: "Insurance Policies",
                ),
                IconButton(
                  icon: Icon(Icons.exit_to_app),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => LoginPage()),
                      (route) => false,
                    );
                  },
                  tooltip: "Logout",
                ),
              ],
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(48),
                child: Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppTheme.primaryColor,
                    labelColor: AppTheme.primaryColor,
                    unselectedLabelColor: AppTheme.textLight,
                    tabs: [
                      Tab(
                        text: "All Vehicles",
                        icon: Icon(Icons.directions_car),
                      ),
                      Tab(text: "Insured", icon: Icon(Icons.verified)),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Search by model or registration number",
                    prefixIcon: Icon(Icons.search, color: AppTheme.textLight),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 15),
                  ),
                  onChanged: (value) {
                    setState(() => searchQuery = value.toLowerCase());
                  },
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  StreamBuilder(
                    stream: vehicles,
                    builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                      if (!snapshot.hasData) {
                        return Center(child: CircularProgressIndicator());
                      }

                      final docs =
                          snapshot.data!.docs.where((doc) {
                            final model = doc['model'].toString().toLowerCase();
                            final reg =
                                doc['registrationNumber']
                                    .toString()
                                    .toLowerCase();
                            return model.contains(searchQuery) ||
                                reg.contains(searchQuery);
                          }).toList();

                      if (docs.isEmpty) {
                        return Center(child: Text("No vehicles found"));
                      }

                      return AnimationLimiter(
                        child: ListView.builder(
                          padding: EdgeInsets.only(bottom: 80),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final vehicle = docs[index];

                            return FutureBuilder<QuerySnapshot>(
                              future:
                                  FirebaseFirestore.instance
                                      .collection('insurance_requests')
                                      .where('vehicleId', isEqualTo: vehicle.id)
                                      .where('userId', isEqualTo: user!.uid)
                                      .get(),
                              builder: (context, insuranceSnapshot) {
                                String? insuranceStatus;
                                if (insuranceSnapshot.hasData &&
                                    insuranceSnapshot.data!.docs.isNotEmpty) {
                                  insuranceStatus =
                                      insuranceSnapshot
                                          .data!
                                          .docs
                                          .first['status'];
                                }

                                return AnimationConfiguration.staggeredList(
                                  position: index,
                                  duration: const Duration(milliseconds: 375),
                                  child: SlideAnimation(
                                    verticalOffset: 50.0,
                                    child: FadeInAnimation(
                                      child: CarCard(
                                        model: vehicle['model'],
                                        registrationNumber:
                                            vehicle['registrationNumber'],
                                        insuranceStatus: insuranceStatus,
                                        onInsuranceTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (
                                                    context,
                                                  ) => InsuranceRequestPage(
                                                    vehicleId: vehicle.id,
                                                    originalPrice:
                                                        vehicle['price'] ?? 0,
                                                    year:
                                                        vehicle['year'] ?? 2020,
                                                  ),
                                            ),
                                          );
                                        },
                                        onEditTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) => EditVehiclePage(
                                                    vehicleId: vehicle.id,
                                                    initialData: vehicle,
                                                  ),
                                            ),
                                          );
                                        },
                                        onAccidentTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) =>
                                                      AccidentReportPage(
                                                        vehicleId: vehicle.id,
                                                      ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                  StreamBuilder(
                    stream:
                        FirebaseFirestore.instance
                            .collection('insurance_requests')
                            .where('userId', isEqualTo: user!.uid)
                            .where('status', whereIn: ['Paid', 'Approved'])
                            .snapshots(),
                    builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                      if (!snapshot.hasData) {
                        return Center(child: CircularProgressIndicator());
                      }

                      final insuredVehicleIds =
                          snapshot.data!.docs
                              .map((doc) => doc['vehicleId'] as String)
                              .toList();

                      if (insuredVehicleIds.isEmpty) {
                        return Center(child: Text("No insured vehicles found"));
                      }

                      return StreamBuilder(
                        stream:
                            FirebaseFirestore.instance
                                .collection('vehicles')
                                .where(
                                  FieldPath.documentId,
                                  whereIn: insuredVehicleIds,
                                )
                                .snapshots(),
                        builder: (
                          context,
                          AsyncSnapshot<QuerySnapshot> vehicleSnapshot,
                        ) {
                          if (!vehicleSnapshot.hasData) {
                            return Center(child: CircularProgressIndicator());
                          }

                          final insuredVehicles = vehicleSnapshot.data!.docs;

                          return AnimationLimiter(
                            child: ListView.builder(
                              padding: EdgeInsets.only(bottom: 80),
                              itemCount: insuredVehicles.length,
                              itemBuilder: (context, index) {
                                final vehicle = insuredVehicles[index];

                                return FutureBuilder<QuerySnapshot>(
                                  future:
                                      FirebaseFirestore.instance
                                          .collection('insurance_requests')
                                          .where(
                                            'vehicleId',
                                            isEqualTo: vehicle.id,
                                          )
                                          .where('userId', isEqualTo: user!.uid)
                                          .get(),
                                  builder: (context, insuranceSnapshot) {
                                    String? insuranceStatus;
                                    if (insuranceSnapshot.hasData &&
                                        insuranceSnapshot
                                            .data!
                                            .docs
                                            .isNotEmpty) {
                                      insuranceStatus =
                                          insuranceSnapshot
                                              .data!
                                              .docs
                                              .first['status'];
                                    }

                                    return AnimationConfiguration.staggeredList(
                                      position: index,
                                      duration: const Duration(
                                        milliseconds: 375,
                                      ),
                                      child: SlideAnimation(
                                        verticalOffset: 50.0,
                                        child: FadeInAnimation(
                                          child: CarCard(
                                            model: vehicle['model'],
                                            registrationNumber:
                                                vehicle['registrationNumber'],
                                            insuranceStatus: insuranceStatus,
                                            onInsuranceTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (
                                                        context,
                                                      ) => InsuranceRequestPage(
                                                        vehicleId: vehicle.id,
                                                        originalPrice:
                                                            vehicle['price'] ??
                                                            0,
                                                        year:
                                                            vehicle['year'] ??
                                                            2020,
                                                      ),
                                                ),
                                              );
                                            },
                                            onEditTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (
                                                        context,
                                                      ) => EditVehiclePage(
                                                        vehicleId: vehicle.id,
                                                        initialData: vehicle,
                                                      ),
                                                ),
                                              );
                                            },
                                            onAccidentTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) =>
                                                          AccidentReportPage(
                                                            vehicleId:
                                                                vehicle.id,
                                                          ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => VehicleRegistrationPage()),
          );
        },
        label: Text("Add Vehicle"),
        icon: Icon(Icons.add),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }
}
