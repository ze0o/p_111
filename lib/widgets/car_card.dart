import 'package:flutter/material.dart';

class CarCard extends StatelessWidget {
  final String model;
  final String registrationNumber;
  final String? insuranceStatus;
  final VoidCallback onInsuranceTap;
  final VoidCallback onEditTap;
  final VoidCallback onAccidentTap;

  const CarCard({
    Key? key,
    required this.model,
    required this.registrationNumber,
    this.insuranceStatus,
    required this.onInsuranceTap,
    required this.onEditTap,
    required this.onAccidentTap,
  }) : super(key: key);

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Paid':
        return Colors.orange;
      case 'Offer Selected':
        return Colors.blueAccent;
      case 'Pending':
        return Colors.grey;
      default:
        return Colors.black54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_car, size: 36, color: Colors.blueGrey),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "Reg No: $registrationNumber",
                        style: TextStyle(color: Colors.grey),
                      ),
                      if (insuranceStatus != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            "Status: $insuranceStatus",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(insuranceStatus!),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    IconButton(
                      onPressed: onInsuranceTap,
                      icon: Icon(Icons.policy, color: Colors.blue),
                    ),
                    Text("Insurance", style: TextStyle(fontSize: 12)),
                  ],
                ),
                Column(
                  children: [
                    IconButton(
                      onPressed: onEditTap,
                      icon: Icon(Icons.edit, color: Colors.teal),
                    ),
                    Text("Edit", style: TextStyle(fontSize: 12)),
                  ],
                ),
                Column(
                  children: [
                    IconButton(
                      onPressed: onAccidentTap,
                      icon: Icon(Icons.report_problem, color: Colors.red),
                    ),
                    Text("Report", style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
