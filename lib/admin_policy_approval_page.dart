import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminInsuranceRequestsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Insurance Requests")),
      body: StreamBuilder(
        stream:
            FirebaseFirestore.instance
                .collection('insurance_requests')
                .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());

          final requests = snapshot.data!.docs;

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final vehicleId = request['vehicleId'];
              final depreciatedValue = request['depreciatedValue'];
              final offers = request['offers'] ?? {};
              final selectedOffer = request['selectedOffer'];
              final status = request['status'];

              return FutureBuilder<DocumentSnapshot>(
                future:
                    FirebaseFirestore.instance
                        .collection('vehicles')
                        .doc(vehicleId)
                        .get(),
                builder: (context, vehicleSnapshot) {
                  if (!vehicleSnapshot.hasData)
                    return ListTile(title: Text("Loading..."));

                  if (!vehicleSnapshot.data!.exists) {
                    return ListTile(title: Text("Vehicle info not found"));
                  }

                  final vehicleData =
                      vehicleSnapshot.data!.data() as Map<String, dynamic>;
                  final model = vehicleData['model'] ?? 'Unknown';
                  final regNo = vehicleData['registrationNumber'] ?? 'N/A';

                  return ListTile(
                    title: Text("Vehicle: $model (Reg No: $regNo)"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Depreciated Value: \$${depreciatedValue.toStringAsFixed(2)}",
                        ),
                        if (selectedOffer != null)
                          Text("Selected Offer: $selectedOffer"),
                        if (status != null) Text("Status: $status"),
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: () {
                        _showOfferDialog(context, request.id, depreciatedValue);
                      },
                      child: Text("Create Offers"),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showOfferDialog(
    BuildContext context,
    String requestId,
    double baseValue,
  ) {
    final basic = baseValue * 1.1;
    final standard = baseValue * 1.2;
    final premium = baseValue * 1.5;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Confirm Offer Creation"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Basic: \$${basic.toStringAsFixed(2)}"),
                Text("Standard: \$${standard.toStringAsFixed(2)}"),
                Text("Premium: \$${premium.toStringAsFixed(2)}"),
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
                          'Basic': basic,
                          'Standard': standard,
                          'Premium': premium,
                        },
                        'status': 'Offers Created',
                      });
                  Navigator.pop(context);
                },
                child: Text("Confirm"),
              ),
            ],
          ),
    );
  }
}
