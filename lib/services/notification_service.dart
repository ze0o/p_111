import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Firebase Cloud Messaging server key (you would get this from Firebase console)
  static const String _serverKey =
      'YOUR_FCM_SERVER_KEY'; // Replace with your actual key

  // Channel ID for Android notifications
  static const String _channelId = 'car_insurance_channel';
  static const String _channelName = 'Car Insurance Notifications';

  // Initialize notification services
  static Future<void> initialize() async {
    // Request permission for notifications
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        _handleNotificationTap(response);
      },
    );

    // Create notification channel for Android
    await _createNotificationChannel();

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // Handle notification tap when app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleRemoteMessage(message);
    });

    // Check for initial message (app opened from terminated state)
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleRemoteMessage(initialMessage);
    }

    // Schedule daily check for insurance expiry
    _scheduleExpiryCheck();
  }

  // Create notification channel for Android
  static Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  // Save device token to user's document for targeted notifications
  static Future<void> saveDeviceToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await _firebaseMessaging.getToken();
      if (token == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tokens')
          .doc(token)
          .set({
            'token': token,
            'createdAt': FieldValue.serverTimestamp(),
            'platform': _getPlatform(),
            'lastActive': FieldValue.serverTimestamp(),
          });

      // Subscribe to topics based on user role
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null && userData['role'] == 'Admin') {
          await _firebaseMessaging.subscribeToTopic('admin');
        } else {
          await _firebaseMessaging.subscribeToTopic('customer');
        }
      }

      // Subscribe user to their own user ID topic for direct messaging
      await _firebaseMessaging.subscribeToTopic('user_${user.uid}');
    } catch (e) {
      print('Error saving device token: $e');
    }
  }

  // Get platform name
  static String _getPlatform() {
    // Fix: Don't use Theme.of(null) as it will cause runtime errors
    // Instead, detect platform using dart:io or defaultTargetPlatform

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ios';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'android';
    } else {
      return 'web';
    }
  }

  // Send notification to admin
  static Future<void> sendAdminNotification(
    String title,
    String body,
    Map<String, dynamic> data,
  ) async {
    try {
      // Get admin users
      final adminSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'Admin')
              .get();

      for (final adminDoc in adminSnapshot.docs) {
        // Add notification to admin's notifications collection
        await FirebaseFirestore.instance
            .collection('users')
            .doc(adminDoc.id)
            .collection('notifications')
            .add({
              'title': title,
              'body': body,
              'data': data,
              'read': false,
              'timestamp': FieldValue.serverTimestamp(),
            });

        // Get admin tokens
        final tokensSnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(adminDoc.id)
                .collection('tokens')
                .get();

        for (final tokenDoc in tokensSnapshot.docs) {
          final token = tokenDoc['token'] as String;

          // Send FCM notification to admin's device
          await _sendPushNotification(token, title, body, data);
        }
      }

      // Also send to admin topic
      await _sendTopicNotification('admin', title, body, data);
    } catch (e) {
      print('Error sending admin notification: $e');
    }
  }

  // Send notification to a specific user
  static Future<void> sendUserNotification(
    String userId,
    String title,
    String body,
    Map<String, dynamic> data,
  ) async {
    try {
      // Add notification to user's notifications collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
            'title': title,
            'body': body,
            'data': data,
            'read': false,
            'timestamp': FieldValue.serverTimestamp(),
          });

      // Get user tokens
      final tokensSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('tokens')
              .get();

      for (final tokenDoc in tokensSnapshot.docs) {
        final token = tokenDoc['token'] as String;

        // Send FCM notification to user's device
        await _sendPushNotification(token, title, body, data);
      }

      // Also send to user's topic
      await _sendTopicNotification('user_$userId', title, body, data);
    } catch (e) {
      print('Error sending user notification: $e');
    }
  }

  // Send notification about insurance status changes
  static Future<void> sendInsuranceStatusNotification(
    String userId,
    String vehicleModel,
    String vehicleReg,
    String oldStatus,
    String newStatus,
  ) async {
    String title;
    String body;
    Map<String, dynamic> data = {
      'type': 'insurance_status',
      'vehicleModel': vehicleModel,
      'vehicleReg': vehicleReg,
      'oldStatus': oldStatus,
      'newStatus': newStatus,
    };

    switch (newStatus) {
      case 'Offers Created':
        title = 'Insurance Offers Available';
        body =
            'We have prepared insurance offers for your $vehicleModel ($vehicleReg)';
        break;
      case 'Approved':
        title = 'Insurance Request Approved';
        body =
            'Your insurance request for $vehicleModel ($vehicleReg) has been approved. Please proceed with payment.';
        break;
      case 'Paid':
        title = 'Insurance Payment Confirmed';
        body =
            'Your payment for $vehicleModel ($vehicleReg) insurance has been confirmed. Your policy is now active.';
        break;
      case 'Rejected':
        title = 'Insurance Request Rejected';
        body =
            'Your insurance request for $vehicleModel ($vehicleReg) has been rejected. Please contact support for more information.';
        break;
      default:
        title = 'Insurance Status Update';
        body =
            'Your insurance status for $vehicleModel ($vehicleReg) has changed to $newStatus.';
    }

    await sendUserNotification(userId, title, body, data);
  }

  // Send notification about claim status changes
  static Future<void> sendClaimStatusNotification(
    String userId,
    String vehicleModel,
    String vehicleReg,
    String claimId,
    String newStatus,
  ) async {
    String title;
    String body;
    Map<String, dynamic> data = {
      'type': 'claim_status',
      'vehicleModel': vehicleModel,
      'vehicleReg': vehicleReg,
      'claimId': claimId,
      'status': newStatus,
    };

    switch (newStatus) {
      case 'Under Review':
        title = 'Claim Under Review';
        body =
            'Your claim for $vehicleModel ($vehicleReg) is now under review.';
        break;
      case 'Approved':
        title = 'Claim Approved';
        body =
            'Good news! Your claim for $vehicleModel ($vehicleReg) has been approved.';
        break;
      case 'Rejected':
        title = 'Claim Rejected';
        body =
            'Your claim for $vehicleModel ($vehicleReg) has been rejected. Please contact support for more information.';
        break;
      case 'Paid':
        title = 'Claim Payment Processed';
        body =
            'The payment for your claim on $vehicleModel ($vehicleReg) has been processed.';
        break;
      default:
        title = 'Claim Status Update';
        body =
            'Your claim status for $vehicleModel ($vehicleReg) has changed to $newStatus.';
    }

    await sendUserNotification(userId, title, body, data);
  }

  // Send insurance expiry reminder
  static Future<void> sendExpiryReminder(
    String userId,
    String vehicleModel,
    String vehicleReg,
    DateTime expiryDate,
    int daysRemaining,
  ) async {
    String title = 'Insurance Expiry Reminder';
    String body;

    if (daysRemaining <= 0) {
      body =
          'Your insurance for $vehicleModel ($vehicleReg) has expired. Please renew it as soon as possible.';
    } else if (daysRemaining == 1) {
      body =
          'Your insurance for $vehicleModel ($vehicleReg) will expire tomorrow. Please renew it soon.';
    } else {
      body =
          'Your insurance for $vehicleModel ($vehicleReg) will expire in $daysRemaining days. Please renew it soon.';
    }

    Map<String, dynamic> data = {
      'type': 'expiry_reminder',
      'vehicleModel': vehicleModel,
      'vehicleReg': vehicleReg,
      'expiryDate': expiryDate.millisecondsSinceEpoch,
      'daysRemaining': daysRemaining,
    };

    await sendUserNotification(userId, title, body, data);
  }

  static void _scheduleExpiryCheck() async {
  

    try {
      // Get all active insurance policies
      final now = DateTime.now();
      final in30Days = now.add(Duration(days: 30));
      final in7Days = now.add(Duration(days: 7));
      final in1Day = now.add(Duration(days: 1));

      final policiesSnapshot =
          await FirebaseFirestore.instance
              .collection('insurance_requests')
              .where('status', isEqualTo: 'Paid')
              .get();

      for (final policyDoc in policiesSnapshot.docs) {
        final data = policyDoc.data();

        if (data['expiryDate'] != null) {
          final expiryDate = (data['expiryDate'] as Timestamp).toDate();
          final userId = data['userId'] as String;

          final vehicleDoc =
              await FirebaseFirestore.instance
                  .collection('vehicles')
                  .doc(data['vehicleId'] as String)
                  .get();

          if (vehicleDoc.exists) {
            final vehicleData = vehicleDoc.data()!;
            final vehicleModel = vehicleData['model'] as String;
            final vehicleReg = vehicleData['registrationNumber'] as String;

            final daysRemaining = expiryDate.difference(now).inDays;

            if (daysRemaining <= 0) {
              await sendExpiryReminder(
                userId,
                vehicleModel,
                vehicleReg,
                expiryDate,
                0,
              );
            } else if (daysRemaining <= 1 && expiryDate.isBefore(in1Day)) {
              await sendExpiryReminder(
                userId,
                vehicleModel,
                vehicleReg,
                expiryDate,
                1,
              );
            } else if (daysRemaining <= 7 && expiryDate.isBefore(in7Days)) {
              // Expires in 7 days
              await sendExpiryReminder(
                userId,
                vehicleModel,
                vehicleReg,
                expiryDate,
                7,
              );
            } else if (daysRemaining <= 30 && expiryDate.isBefore(in30Days)) {
              // Expires in 30 days
              await sendExpiryReminder(
                userId,
                vehicleModel,
                vehicleReg,
                expiryDate,
                30,
              );
            }
          }
        }
      }
    } catch (e) {
      print('Error checking insurance expiry: $e');
    }
  }

  static Future<void> _sendPushNotification(
    String token,
    String title,
    String body,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_serverKey',
        },
        body: jsonEncode({
          'notification': {'title': title, 'body': body, 'sound': 'default'},
          'data': data,
          'to': token,
          'priority': 'high',
        }),
      );

      if (response.statusCode != 200) {
        print(
          'Failed to send push notification. Status: ${response.statusCode}',
        );
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('Error sending push notification: $e');
    }
  }

  static Future<void> _sendTopicNotification(
    String topic,
    String title,
    String body,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_serverKey',
        },
        body: jsonEncode({
          'notification': {'title': title, 'body': body, 'sound': 'default'},
          'data': data,
          'to': '/topics/$topic',
          'priority': 'high',
        }),
      );

      if (response.statusCode != 200) {
        print(
          'Failed to send topic notification. Status: ${response.statusCode}',
        );
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('Error sending topic notification: $e');
    }
  }

  static void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      platformChannelSpecifics,
      payload: jsonEncode(message.data),
    );
  }

  static void _handleNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        _navigateBasedOnNotificationType(data);
      } catch (e) {
        print('Error parsing notification payload: $e');
      }
    }
  }

  static void _handleRemoteMessage(RemoteMessage message) {
    _navigateBasedOnNotificationType(message.data);
  }

  static void _navigateBasedOnNotificationType(Map<String, dynamic> data) {
   
    final type = data['type'];

    switch (type) {
      case 'insurance_status':
        print(
          'Navigate to insurance details for vehicle: ${data['vehicleReg']}',
        );
        break;
      case 'claim_status':
        print('Navigate to claim details for claim: ${data['claimId']}');
        break;
      case 'expiry_reminder':
        print(
          'Navigate to insurance renewal for vehicle: ${data['vehicleReg']}',
        );
        break;
      case 'offers':
        print('Navigate to insurance offers for request: ${data['requestId']}');
        break;
      case 'approval':
        print('Navigate to payment for request: ${data['requestId']}');
        break;
      case 'rejection':
        print('Navigate to insurance history');
        break;
      case 'payment':
        print('Navigate to policy details for request: ${data['requestId']}');
        break;
      default:
        print('Navigate to notifications list');
    }
  }

  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  static Stream<int> getUnreadNotificationsCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value(0);
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  static Stream<QuerySnapshot> getUserNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Delete a notification
  static Future<void> deleteNotification(String notificationId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Clear all notifications
  static Future<void> clearAllNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final batch = FirebaseFirestore.instance.batch();
      final notifications =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('notifications')
              .get();

      for (final doc in notifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      print('Error clearing notifications: $e');
    }
  }
}

// Handle background messages
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No need to initialize Firebase here as it's already initialized in main.dart
  print("Handling a background message: ${message.messageId}");

  // You could store the notification in SharedPreferences or a local database
  // to show it when the app is opened next time
}
