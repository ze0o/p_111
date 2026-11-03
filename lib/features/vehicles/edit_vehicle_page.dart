import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditVehiclePage extends StatefulWidget {
  final String vehicleId;
  final DocumentSnapshot initialData;

  EditVehiclePage({required this.vehicleId, required this.initialData});

  @override
  _EditVehiclePageState createState() => _EditVehiclePageState();
}

class _EditVehiclePageState extends State<EditVehiclePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController modelController;
  late TextEditingController priceController;
  late TextEditingController regController;

  @override
  void initState() {
    modelController = TextEditingController(text: widget.initialData['model']);
    priceController = TextEditingController(
      text: widget.initialData['price'].toString(),
    );
    regController = TextEditingController(
      text: widget.initialData['registrationNumber'],
    );
    super.initState();
  }

  Future<void> updateVehicle() async {
    await FirebaseFirestore.instance
        .collection('vehicles')
        .doc(widget.vehicleId)
        .update({
          'model': modelController.text,
          'price': double.tryParse(priceController.text) ?? 0,
          'registrationNumber': regController.text,
        });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Edit Vehicle")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FadeInUp(
          duration: Duration(milliseconds: 500),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: modelController,
                  decoration: InputDecoration(labelText: "Model"),
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: priceController,
                  decoration: InputDecoration(labelText: "Price"),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 20),

                TextFormField(
                  controller: regController,
                  decoration: InputDecoration(labelText: "Registration Number"),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: updateVehicle,
                  child: Text("Save Changes"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
