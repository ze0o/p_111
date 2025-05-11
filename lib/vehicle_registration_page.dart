import 'dart:io';
import 'dart:typed_data';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cross_file/cross_file.dart';
import 'theme/app_theme.dart';

class VehicleRegistrationPage extends StatefulWidget {
  @override
  _VehicleRegistrationPageState createState() =>
      _VehicleRegistrationPageState();
}

class _VehicleRegistrationPageState extends State<VehicleRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _modelController = TextEditingController();
  final _chassisController = TextEditingController();
  final _regNumberController = TextEditingController();
  final _yearController = TextEditingController();
  final _passengersController = TextEditingController();
  final _driverAgeController = TextEditingController();
  final _priceController = TextEditingController();

  bool _hadAccident = false;
  bool _isLoading = false;
  List<File> _vehicleImages = [];
  final ImagePicker _picker = ImagePicker();
  double _calculatedInsuranceAmount = 0.0;
  double _currentCarValue = 0.0;
  int _currentYear = DateTime.now().year;

  @override
  void dispose() {
    _modelController.dispose();
    _chassisController.dispose();
    _regNumberController.dispose();
    _yearController.dispose();
    _passengersController.dispose();
    _driverAgeController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile>? images = await _picker.pickMultiImage();
      if (images != null) {
        setState(() {
          _vehicleImages.addAll(
            images.map((xFile) => File(xFile.path)).toList(),
          );
        });
      }
    } catch (e) {
      print('Error picking images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking images: ${e.toString()}'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _vehicleImages.removeAt(index);
    });
  }

  void _calculateInsurance() {
    if (_priceController.text.isEmpty || _yearController.text.isEmpty) {
      return;
    }

    double originalPrice = double.parse(_priceController.text);
    int manufacturingYear = int.parse(_yearController.text);
    int yearsDifference = _currentYear - manufacturingYear;

    // Calculate current car value with 10% depreciation per year
    double currentValue = originalPrice;
    for (int i = 0; i < yearsDifference; i++) {
      currentValue = currentValue * 0.9; // 10% depreciation
    }

    // Basic insurance calculation (5% of current value)
    double insuranceAmount = currentValue * 0.05;

    setState(() {
      _currentCarValue = currentValue;
      _calculatedInsuranceAmount = insuranceAmount;
    });
  }

  Future<void> _checkForRenewal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Simplify the query to avoid requiring a complex index
      final previousInsurance =
          await FirebaseFirestore.instance
              .collection('insurance_requests')
              .where('userId', isEqualTo: user.uid)
              .where('registrationNumber', isEqualTo: _regNumberController.text)
              .get();

      if (previousInsurance.docs.isNotEmpty) {
        // Sort the results manually if needed
        final sortedDocs =
            previousInsurance.docs
                .where((doc) => doc.data().containsKey('timestamp'))
                .toList()
              ..sort((a, b) {
                final aTimestamp = a.data()['timestamp'] as Timestamp?;
                final bTimestamp = b.data()['timestamp'] as Timestamp?;
                if (aTimestamp == null || bTimestamp == null) return 0;
                return bTimestamp.compareTo(aTimestamp); // Descending order
              });

        if (sortedDocs.isNotEmpty) {
          // This is a renewal
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'This vehicle has been insured before. Processing as renewal.',
              ),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        }
      }
    } catch (e) {
      print('Error checking for renewal: $e');
      // Don't throw an exception here, just log it and continue
    }
  }

  Future<void> _submitVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    if (_vehicleImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add at least one vehicle image'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Calculate insurance before submission
      _calculateInsurance();

      // Check if this is a renewal - using a simplified approach
      try {
        final previousInsurance =
            await FirebaseFirestore.instance
                .collection('insurance_requests')
                .where('userId', isEqualTo: user.uid)
                .where(
                  'registrationNumber',
                  isEqualTo: _regNumberController.text,
                )
                .get();

        if (previousInsurance.docs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'This vehicle has been insured before. Processing as renewal.',
              ),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        }
      } catch (e) {
        print('Error checking for renewal: $e');
        // Continue with registration even if renewal check fails
      }

      // Upload images to Firebase Storage
      List<String> imageUrls = [];

      for (var i = 0; i < _vehicleImages.length; i++) {
        final fileName =
            'vehicle_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('vehicle_images')
            .child(fileName);

        UploadTask uploadTask;

        if (kIsWeb) {
          // For web platform, convert File to Uint8List
          final imageFile = _vehicleImages[i];
          final imageBytes = await imageFile.readAsBytes();
          uploadTask = storageRef.putData(
            imageBytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );
        } else {
          // For mobile platforms
          uploadTask = storageRef.putFile(
            _vehicleImages[i],
            SettableMetadata(contentType: 'image/jpeg'),
          );
        }

        // Show upload progress
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          print(
            'Upload progress for image $i: ${(progress * 100).toStringAsFixed(2)}%',
          );
        });

        // Wait for upload to complete
        await uploadTask;

        // Get download URL
        final downloadUrl = await storageRef.getDownloadURL();
        imageUrls.add(downloadUrl);
      }

      // Save vehicle data to Firestore
      final vehicleRef = await FirebaseFirestore.instance
          .collection('vehicles')
          .add({
            'userId': user.uid,
            'model': _modelController.text,
            'chassisNumber': _chassisController.text,
            'registrationNumber': _regNumberController.text,
            'year': int.parse(_yearController.text),
            'passengers': int.parse(_passengersController.text),
            'driverAge': int.parse(_driverAgeController.text),
            'price': double.parse(_priceController.text),
            'currentValue': _currentCarValue,
            'hadAccident': _hadAccident,
            'imageUrls': imageUrls,
            'timestamp': FieldValue.serverTimestamp(),
          });

      // Create insurance request
      await FirebaseFirestore.instance.collection('insurance_requests').add({
        'userId': user.uid,
        'vehicleId': vehicleRef.id,
        'registrationNumber': _regNumberController.text,
        'calculatedAmount': _calculatedInsuranceAmount,
        'currentValue': _currentCarValue,
        'originalPrice': double.parse(_priceController.text),
        'status': 'Pending',
        'timestamp': FieldValue.serverTimestamp(),
        'hadAccident': _hadAccident,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vehicle registered successfully!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      print('Error during vehicle registration: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Register Vehicle'),
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
              Text(
                'Vehicle Information',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ).fadeIn(duration: Duration(milliseconds: 600)),
              SizedBox(height: 16),

              Column(
                children: [
                  TextFormField(
                    controller: _modelController,
                    decoration: InputDecoration(
                      labelText: 'Car Model',
                      prefixIcon: Icon(Icons.directions_car),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter car model';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 12),

                  TextFormField(
                    controller: _chassisController,
                    decoration: InputDecoration(
                      labelText: 'Chassis Number',
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter chassis number';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 12),

                  TextFormField(
                    controller: _regNumberController,
                    decoration: InputDecoration(
                      labelText: 'Registration Number',
                      prefixIcon: Icon(Icons.app_registration),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter registration number';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 12),

                  TextFormField(
                    controller: _yearController,
                    decoration: InputDecoration(
                      labelText: 'Manufacturing Year',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter manufacturing year';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Please enter a valid year';
                      }
                      if (int.parse(value) > _currentYear) {
                        return 'Year cannot be in the future';
                      }
                      return null;
                    },
                    onChanged: (_) => _calculateInsurance(),
                  ),
                  SizedBox(height: 12),

                  TextFormField(
                    controller: _passengersController,
                    decoration: InputDecoration(
                      labelText: 'Number of Passengers',
                      prefixIcon: Icon(Icons.people),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter number of passengers';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 12),

                  TextFormField(
                    controller: _driverAgeController,
                    decoration: InputDecoration(
                      labelText: 'Driver Age',
                      prefixIcon: Icon(Icons.person),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter driver age';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Please enter a valid age';
                      }
                      if (int.parse(value) < 18) {
                        return 'Driver must be at least 18 years old';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 12),

                  TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: 'Original Car Price',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter original car price';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid price';
                      }
                      return null;
                    },
                    onChanged: (_) => _calculateInsurance(),
                  ),
                ],
              ).fadeInDown(
                duration: Duration(milliseconds: 500),
                delay: Duration(milliseconds: 300),
                from: 30,
              ),
              SizedBox(height: 16),

              SwitchListTile(
                title: Text('Has the car been in an accident?'),
                value: _hadAccident,
                activeColor: AppTheme.primaryColor,
                onChanged: (value) {
                  setState(() {
                    _hadAccident = value;
                  });
                },
              ).fadeInLeft(
                duration: Duration(milliseconds: 600),
                delay: Duration(milliseconds: 300),
                from: 30,
              ),
              SizedBox(height: 24),

              Column(
                children: [
                  Text(
                    'Vehicle Photos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  SizedBox(height: 8),

                  ElevatedButton.icon(
                    onPressed: _pickImages,
                    icon: Icon(Icons.add_a_photo),
                    label: Text('Add Photos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                    ),
                  ),
                ],
              ).fadeIn(
                duration: Duration(milliseconds: 500),
                delay: Duration(milliseconds: 300),
              ),
              SizedBox(height: 16),

              if (_vehicleImages.isNotEmpty)
                Container(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _vehicleImages.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Container(
                            margin: EdgeInsets.only(right: 8),
                            width: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: FileImage(_vehicleImages[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 5,
                            right: 13,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              SizedBox(height: 24),

              if (_currentCarValue > 0 && _calculatedInsuranceAmount > 0)
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
                          'Insurance Calculation',
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
                            Text('Original Price:'),
                            Text(
                              '\$${double.parse(_priceController.text).toStringAsFixed(2)}',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Current Value (after depreciation):'),
                            Text(
                              '\$${_currentCarValue.toStringAsFixed(2)}',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Estimated Insurance Amount:'),
                            Text(
                              '\$${_calculatedInsuranceAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Note: Final insurance amount may vary based on admin review.',
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
                  onPressed: _isLoading ? null : _submitVehicle,
                  child:
                      _isLoading
                          ? CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          )
                          : Text(
                            'REGISTER VEHICLE',
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
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
