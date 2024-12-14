library mehery_sender;

import 'dart:convert';
import 'dart:io' show Platform;
import 'package:app_set_id/app_set_id.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MeSend {
  final String serverUrl;
  final String companyId;

  MeSend({required this.serverUrl, required this.companyId});

  /// Initializes the SDK and sends the appropriate token (Firebase or APNs).
  Future<void> initializeAndSendToken() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // Request notification permissions (necessary for iOS)
      await messaging.requestPermission();

      if (Platform.isAndroid) {
        // Get Firebase token for Android
        String? firebaseToken = await messaging.getToken();
        print(firebaseToken);
        if (firebaseToken != null) {
          await sendTokenToServer('android', firebaseToken);
        } else {
          throw Exception("Failed to retrieve Firebase token on Android.");
        }
      } else if (Platform.isIOS) {
        // Get APNs token for iOS
        String? apnsToken = await messaging.getAPNSToken();
        if (apnsToken != null) {
          await sendTokenToServer('ios', apnsToken);
        } else {
          throw Exception("Failed to retrieve APNs token on iOS.");
        }
      } else {
        throw UnsupportedError("Unsupported platform.");
      }
    } catch (e) {
      print("Error initializing FirebaseTokenSender: $e");
    }
  }

  /// Sends the token (APNs or Firebase) to the server.
  Future<void> sendTokenToServer(String tokenType, String token) async {
    try {
      var device_id = await getDeviceId();
      final response = await http.post(
        Uri.parse('$serverUrl/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'platform': tokenType, // 'firebase' or 'apns'
          'token': token,
          'device_id' : device_id,
          'company_id' : companyId
        }),
      );

      if (response.statusCode == 200) {
        print("Token sent successfully!");
      } else {
        throw Exception("Failed to send token: ${response.body}");
      }
    } catch (e) {
      print("Error sending token to server: $e");
    }
  }


  /// Sends the token (APNs or Firebase) to the server.
  Future<void> login(String userId) async {
    try {
      var device_id = await getDeviceId();
      final response = await http.post(
        Uri.parse('$serverUrl/api/register/user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'device_id' : device_id,
          'company_id' : companyId
        }),
      );

      if (response.statusCode == 200) {
        print("User registered successfully!");
      } else {
        throw Exception("Failed to register user: ${response.body}");
      }
    } catch (e) {
      print("Error registering user: $e");
    }
  }


  /// Sends the token (APNs or Firebase) to the server.
  Future<void> logout(String userId) async {
    try {
      var device_id = await getDeviceId();
      final response = await http.post(
        Uri.parse('$serverUrl/api/logout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'device_id' : device_id,
          'company_id' : companyId
        }),
      );

      if (response.statusCode == 200) {
        print("User logged out successfully!");
      } else {
        throw Exception("Failed to log out user: ${response.body}");
      }
    } catch (e) {
      print("Error logging out user: $e");
    }
  }

  Future<String?> getDeviceId() async {
    return await AppSetId().getIdentifier();
  }
}

