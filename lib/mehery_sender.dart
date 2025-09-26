library mehery_sender;

import 'dart:convert';
import 'dart:io' show Platform;
import 'package:app_set_id/app_set_id.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';



class MeSend {
  late final String serverUrl;

  List<Map<String, dynamic>> _notificationQueue = [];
  bool _isProcessingQueue = false;

  var mockJson = r'''
{
    "success": true,
    "meta": {},
    "results": [
        {
            "messageId": "aeeec3ef-7245-415c-ac51-c732847bd82a",
            "filterId": "6895739b1ff48f6f5b2f516f",
            "channelId": "demo_1751694691225",
            "contactId": "xyz_77A5BDA7-BFC6-4C6A-8340-FF0E99390AD0",
            "eventId": "6895cbd55e57299cfe3c54b6",
            "event": {
                "event_name": "page_open",
                "event_data": {
                    "page": "login"
                }
            },
            "template": {
                "options": {
                    "buttons": []
                },
                "model": {
                    "data": []
                },
                "_id": "6895739b1ff48f6f5b2f516d",
                "type": "pop-up",
                "subType": "roadblock",
                "desc": "mark 11",
                "code": "mark_11",
                "lang": "en_US",
                "style": {
                    "code": "bottomsheet",
                    "title": "",
                    "message": "",
                    "line_1": "suit mark 11",
                    "line_2": "",
                    "line_3": "",
                    "height": 80,
                    "width": 80,
                    "btn": [
                        {
                            "label": "",
                            "value": "",
                            "desc": ""
                        },
                        {
                            "label": "",
                            "value": "",
                            "desc": ""
                        }
                    ],
                    "image_url": "",
                    "logo_url": "",
                    "button1_url": "",
                    "button2_url": "",
                    "line1_font_size": 18,
                    "line2_font_size": 16,
                    "line3_font_size": null,
                    "line1_font_color": "#F42222",
                    "line2_font_color": "#F42222",
                    "line3_font_color": "",
                    "line1_font_text_styles": [],
                    "line2_font_text_styles": [],
                    "line3_font_text_styles": [],
                    "bg_color": "#BEBDBD",
                    "bg_color_gradient": "#F6F4F4",
                    "bg_color_gradient_dir": "to bottom",
                    "progress_color": "",
                    "align": "center",
                    "line1_text_styles": [
                        "bold"
                    ],
                    "btn_bg_color": "#B8E4BF",
                    "btn_font_color": "#000000",
                    "line2_text_styles": [
                        "underline"
                    ],
                    "vertical_align": "center",
                    "html": "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n  <meta charset=\"UTF-8\">\n  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n  <title>Carousel Roadblock</title>\n  <style>\n    html, body {\n      margin: 0;\n      padding: 0;\n      width: 100%;\n      height: 100%;\n      overflow: hidden;\n      background: #ffffff;\n      font-family: sans-serif;\n    }\n    .carousel-container {\n      display: flex;\n      overflow-x: scroll;\n      scroll-snap-type: x mandatory;\n      width: 100%;\n      height: 100%;\n    }\n    .carousel-page {\n      flex: 0 0 100%;\n      height: 100%;\n      scroll-snap-align: center;\n      display: flex;\n      flex-direction: column;\n      justify-content: center;\n      align-items: center;\n      padding: 20px;\n      box-sizing: border-box;\n    }\n    .carousel-page img {\n      max-width: 80%;\n      height: auto;\n      max-height: 50%;\n      margin-bottom: 20px;\n      object-fit: contain;\n    }\n    .carousel-page h2 {\n      font-size: 2rem;\n      margin: 10px 0;\n      text-align: center;\n    }\n    .carousel-page p {\n      font-size: 1rem;\n      color: #555;\n      text-align: center;\n    }\n    .dots {\n      position: absolute;\n      bottom: 20px;\n      left: 50%;\n      transform: translateX(-50%);\n      display: flex;\n      gap: 8px;\n    }\n    .dot {\n      width: 10px;\n      height: 10px;\n      background: #ccc;\n      border-radius: 50%;\n    }\n    .dot.active {\n      background: #333;\n    }\n  </style>\n</head>\n<body>\n  <div class=\"carousel-container\" id=\"carousel\">\n    <div class=\"carousel-page\">\n      <img src=\"https://fastly.picsum.photos/id/888/200/200.jpg?hmac=k4DxIkJ_O8YKi3TA5I9xxJYJzqpSvx3QmJlgZwHMojo\" alt=\"Welcome\">\n      <h2>Welcome</h2>\n      <p>Discover new features in our app.</p>\n    </div>\n    <div class=\"carousel-page\">\n      <img src=\"https://fastly.picsum.photos/id/1021/200/200.jpg?hmac=5Jzd15OWoPw0fwvsvL05A1BAIN_B543TvjlxqGk1PDU\" alt=\"Stay Updated\">\n      <h2>Stay Updated</h2>\n      <p>Enable notifications to never miss out.</p>\n    </div>\n    <div class=\"carousel-page\">\n      <img src=\"https://fastly.picsum.photos/id/802/200/200.jpg?hmac=alfo3M8Ps4XWmFJGIwuzLUqOrwxqkE5_f65vCtk6_Iw\" alt=\"Explore\">\n      <h2>Explore</h2>\n      <p>Find content tailored just for you.</p>\n    </div>\n  </div>\n  <div class=\"dots\">\n    <div class=\"dot active\" id=\"dot0\"></div>\n    <div class=\"dot\" id=\"dot1\"></div>\n    <div class=\"dot\" id=\"dot2\"></div>\n  </div>\n  <script>\n    const carousel = document.getElementById('carousel');\n    const dots = [document.getElementById('dot0'), document.getElementById('dot1'), document.getElementById('dot2')];\n    carousel.addEventListener('scroll', () => {\n      const index = Math.round(carousel.scrollLeft / window.innerWidth);\n      dots.forEach((dot, i) => dot.classList.toggle('active', i === index));\n    });\n  </script>\n</body>\n</html>"
                },
                "createdAt": "2025-08-08T03:48:43.576Z",
                "updatedAt": "2025-08-08T03:48:43.576Z",
                "__v": 0
            }
        }       
    ]
}
''';

  // final String serverUrl = "https://demo.mehery.xyz";

  final String tenant;
  final String channelId;
  bool sandbox = false;
  String userId = "";
  String guestId = "";
  BuildContext? buildContext;

  final MeSendRouteObserver meSendRouteObserver = MeSendRouteObserver();

  final SocketService _socketService = SocketService();

  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  static const _channel = MethodChannel('mehery_channel');


  final Map<String, void Function(List<dynamic>)> _placeholderListeners = {};



  // Updated constructor to handle tenant$channelId format
  MeSend({required String identifier, this.sandbox = false}) :
        tenant = identifier.split('\$')[0],
        channelId = identifier.split('\$').length > 1 ? identifier.split('\$')[1] : '' {
    serverUrl = 'https://$tenant.pushapp.${sandbox ? "co.in" : "com"}';
    // serverUrl = 'https://8e5aebdbe23d.ngrok-free.app';
    if (channelId.isEmpty) {
      throw ArgumentError('Invalid identifier format. Expected format: tenant\$channelId');
    }

    meSendRouteObserver.attachSDK(this);
  }

  void registerPlaceholderListener(String placeholderId, void Function(List<dynamic>) callback) {
    _placeholderListeners[placeholderId] = callback;
  }

  void unregisterPlaceholderListener(String placeholderId) {
    _placeholderListeners.remove(placeholderId);
  }

  void sendWidgetOpen(String placeholderId) {
    sendEvent('widget_open', {'placeholder_id': placeholderId});
  }

  void initPage(String page){
    sdkPrint("in sdk init page");
    sendEvent("page_open", {"page": page});
    Future.delayed(const Duration(seconds: 5), () {
      _pollForNotificationData(userId);
    });
  }

  /// Initializes the SDK and sends the appropriate token (Firebase or APNs).
  Future<void> initializeAndSendToken() async {
    sdkPrint("Started Load");

    setupMethodChannelHandler();
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('user_id') ?? '';

    // ✅ If user already logged in, do nothing
    if (userId.isNotEmpty) {
      sdkPrint("User already logged in: $userId");
      _setupSocket(userId); // optional: just to reconnect socket
      return;
    }

    // If user not logged in, send token
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      if (Platform.isAndroid) {
        String? firebaseToken = await messaging.getToken();
        if (firebaseToken != null) {
          await sendTokenToServer('android', firebaseToken);
        } else {
          sdkPrint("Failed to retrieve Firebase token on Android.");
        }
      } else if (Platform.isIOS) {
        String? apnsToken = await messaging.getAPNSToken();
        if (apnsToken != null) {
          await sendTokenToServer('ios', apnsToken);
        } else {
          sdkPrint("Failed to retrieve APNs token on iOS.");
        }
      } else {
        sdkPrint("Unsupported platform.");
      }
    } catch (e) {
      sdkPrint("Error initializing FirebaseTokenSender: $e");
    }
  }


  Future<void> sendMessageToStack(String message) async{
    const slackWebhookUrl = "https://hooks.slack.com/services/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";

    final payload = {
      "text": message
    };

    final res = await http.post(
      Uri.parse(slackWebhookUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      sdkPrint("Failed to send message to Slack: ${res.body}");
      throw Exception("Failed to send message to Slack: ${res.body}");
    }
  }


  Future<void> postApiDetailsToSlack({
    required String url,
    required String method,
    required Map<String, String> requestHeaders,
    required dynamic requestBody,
    required http.Response response,
  }) async {
    const slackWebhookUrl = "https://hooks.slack.com/services/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";

    final payload = {
      "text": """
*API Call Details:*
• *URL*: $url
• *Method*: $method
• *Request Headers*: ${jsonEncode(requestHeaders)}
• *Request Body*: ${jsonEncode(requestBody)}
• *Response Status*: ${response.statusCode}
• *Response Body*: ${response.body}
• *Response Headers*: ${jsonEncode(response.headers)}
"""
    };

    final res = await http.post(
      Uri.parse(slackWebhookUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      sdkPrint("Failed to send message to Slack: ${res.body}");
      throw Exception("Failed to send message to Slack: ${res.body}");
    }
  }

  void setupMethodChannelHandler() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'trackNotification') {
        final args = call.arguments as Map;
        final token = args['token'] as String;
        final eventType = args['eventType'] as String;
        await trackNotificationEvent(token, eventType);
      }
    });
  }

  Future<void> trackNotificationEvent(String token, String eventType) async {
    try {
      final response = await http.post(
        Uri.parse('$serverUrl/pushapp/api/v2/notification/track?t=$token&eventType=opened'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        sdkPrint('Notification event tracked successfully.');
      } else {
        sdkPrint('Failed to track event: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      sdkPrint('Error tracking notification event: $e');
    }
  }


  /// Sends the token (APNs or Firebase) to the server and logs details to Slack.
  Future<void> sendTokenToServer(String tokenType, String token) async {
    sdkPrint("sendTokenToServer");
    try {
      final url = '$serverUrl/pushapp/api/register';
      sdkPrint('Server URL : $url');

      var deviceId = await getDeviceId();
      final deviceHeaders = await getDeviceHeaders();
      sdkPrint("ServerDeviceID: $deviceId");

      final requestHeaders = {
        'Content-Type': 'application/json',
        ...deviceHeaders,
      };

      final requestBody = {
        'platform': tokenType, // 'firebase' or 'apns'
        'token': token,
        'device_id': deviceId,
        'channel_id': channelId,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: requestHeaders,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        sdkPrint(response.body);
        if (responseData['device']['user_id'] != null) {
          guestId = responseData['device']['user_id'].toString();
        }
        sdkPrint("guest_id: $guestId");
        sendEvent("app_open", {});
        sdkPrint("Token sent successfully!");
      } else {
        sdkPrint("Failed to send token: ${response.body}");
        throw Exception("Failed to send token: ${response.body}");
      }

      // ✅ Post API details to Slack
      await postApiDetailsToSlack(
        url: url,
        method: "POST",
        requestHeaders: requestHeaders,
        requestBody: requestBody,
        response: response,
      );

    } catch (e) {
      sdkPrint("Error sending token to server: $e");
      // postApiDetailsToSlack(url: '$serverUrl/pushapp/api/register', method: deviceId, requestHeaders: requestHeaders, requestBody: requestBody, response: response);
    }
  }


  /// Acknowledges an in-app notification and logs details to Slack.
  Future<void> ackNotification(String contactId, String messageId) async {
    try {
      final url = '$serverUrl/pushapp/api/v1/notification/in-app/ack';
      final requestHeaders = {
        'Content-Type': 'application/json',
      };
      final requestBody = {
        'contact_id': contactId,
        'messageId': messageId,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: requestHeaders,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        sdkPrint("Notification acknowledged successfully!");
      } else {
        sdkPrint("Failed to acknowledge notification: ${response.body}");
        throw Exception("Failed to acknowledge notification: ${response.body}");
      }

      // ✅ Log API call to Slack
      await postApiDetailsToSlack(
        url: url,
        method: "POST",
        requestHeaders: requestHeaders,
        requestBody: requestBody,
        response: response,
      );

    } catch (e) {
      sdkPrint("Error acknowledging notification: $e");

      // 🔴 Log exception to Slack too
      await postApiDetailsToSlack(
        url: '$serverUrl/pushapp/api/v1/notification/in-app/ack',
        method: "POST",
        requestHeaders: {'Content-Type': 'application/json'},
        requestBody: {
          'contact_id': contactId,
          'messageId': messageId,
        },
        response: http.Response("Exception: $e", 500),
      );
    }
  }



  /// Sends the userId to the server to register user and logs details to Slack.
  Future<void> login(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    var oldUserId = prefs.getString('user_id') ?? '';
    sdkPrint(oldUserId);

    try {
      if (oldUserId != '') {
        sdkPrint("Already Logged in");
        throw Exception("Already Logged in");
      }

      this.userId = userId;
      var deviceId = await getDeviceId();
      final deviceHeaders = await getDeviceHeaders();
      sdkPrint("LoginDeviceID: $deviceId");

      final url = '$serverUrl/pushapp/api/register/user';
      final requestHeaders = {
        'Content-Type': 'application/json',
        ...deviceHeaders,
      };
      final requestBody = {
        'user_id': userId,
        'device_id': deviceId,
        'channel_id': channelId,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: requestHeaders,
        body: jsonEncode(requestBody),
      );

      sdkPrint('URL $url');
      sdkPrint('json ${jsonEncode(requestBody)}');
      sdkPrint('Response : ${response.statusCode}');

      if (response.statusCode == 200) {
        sdkPrint("User registered successfully!");
        _setupSocket(userId);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', userId);
      } else {
        sdkPrint("Failed to register user: ${response.body}");
        throw Exception("Failed to register user: ${response.body}");
      }

      // ✅ Post API details to Slack
      await postApiDetailsToSlack(
        url: url,
        method: "POST",
        requestHeaders: requestHeaders,
        requestBody: requestBody,
        response: response,
      );

    } catch (e) {
      sdkPrint("Error registering user: $e");

      // 🔴 Even if error, still log to Slack for debugging
      await postApiDetailsToSlack(
        url: '$serverUrl/pushapp/api/register/user',
        method: "POST",
        requestHeaders: {'Content-Type': 'application/json'}, // minimal headers if fail before headers
        requestBody: {'user_id': userId, 'device_id': 'unknown', 'channel_id': channelId},
        response: http.Response("Exception: $e", 500), // Fake response for Slack
      );
    }
  }


  void setInAppNotification(BuildContext context){
    if (context is Element && context.mounted) {
      buildContext = context;
      sdkPrint("In-app context set!");
    } else {
      sdkPrint("Context not mounted yet");
    }
    buildContext = context;
  }


  void _setupSocket(String userId) {
    sdkPrint("SocketStarted : $userId");
    _socketService.connect(userId,tenant,sandbox);

    _socketService.notificationStream.listen((notification) {
      sdkPrint("Received notification: $notification");
      _pollForNotificationData(userId);
    });
  }

  void sdkPrint(String? message){
    debugPrint(message);
    if(message != null) {
      sendMessageToStack(message!);
    }
  }

  Future<void> _pollForNotificationData(String userId) async {
    sdkPrint("poll calling");
    try {
      var deviceId = await getDeviceId();
      if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? '';
      }
      final deviceHeaders = await getDeviceHeaders();
      final contactId = "${userId}_$deviceId";
      sdkPrint(contactId);

      final url = '$serverUrl/pushapp/api/v1/notification/in-app/poll';
      final requestHeaders = {
        'Content-Type': 'application/json',
        ...deviceHeaders,
      };
      final requestBody = {
        'contact_id': contactId,
      };

      // Make HTTP request to poll endpoint
      final response = await http.post(
        Uri.parse(url),
        headers: requestHeaders,
        body: jsonEncode(requestBody),
      );

      sdkPrint("Poll response status: ${response.statusCode}");
      sdkPrint("Poll response body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        sdkPrint("Poll response data: $responseData");

        if (responseData['success'] == true) {
          sdkPrint("Result Poll");
          final results = responseData['results'];

          if (results is List && results.isNotEmpty) {
            for (final item in results) {
              _notificationQueue.add(item);
            }
            _processNextFromQueue();
          } else {
            sdkPrint("No new notifications from poll — keeping existing queue.");
          }
        } else {
          sdkPrint("Poll failed: ${responseData['message']}");
        }
      } else {
        sdkPrint("Poll request failed with status: ${response.statusCode}");
        sdkPrint("Response body: ${response.body}");
      }

      // ✅ Log API call details to Slack
      await postApiDetailsToSlack(
        url: url,
        method: "POST",
        requestHeaders: requestHeaders,
        requestBody: requestBody,
        response: response,
      );

    } catch (e) {
      sdkPrint("Error polling for notification data: $e");

      // 🔴 Log error to Slack as well
      await postApiDetailsToSlack(
        url: '$serverUrl/pushapp/api/v1/notification/in-app/poll',
        method: "POST",
        requestHeaders: {'Content-Type': 'application/json'},
        requestBody: {'contact_id': "${userId}_error"},
        response: http.Response("Exception: $e", 500), // Fake response for Slack
      );
    }
  }

  void _onNotificationClosed() {
    _isProcessingQueue = false;
    _processNextFromQueue();
  }

  void _processNextFromQueue() {
    sdkPrint("Queue");
    sdkPrint(' queue data ${_notificationQueue.length}');
    if (_isProcessingQueue || _notificationQueue.isEmpty) {
      return; // Either already showing one, or queue is empty
    }

    _isProcessingQueue = true;

    final nextItem = _notificationQueue.removeAt(0);
    sdkPrint("Showing queued notification: $nextItem");

    _processNotificationData(nextItem);
  }

  String getAlignment(Map<String, dynamic> style) {
    final vertical = (style['vertical_align'] ?? 'flex-end').toString();
    final horizontal = (style['horizontal_align'] ?? 'flex-end').toString();

    String verticalPart;
    switch (vertical) {
      case 'flex-start':
        verticalPart = 'top';
        break;
      case 'center':
        verticalPart = 'center';
        break;
      case 'flex-end':
      default:
        verticalPart = 'bottom';
    }

    String horizontalPart;
    switch (horizontal) {
      case 'flex-start':
        horizontalPart = 'left';
        break;
      case 'center':
        horizontalPart = 'center';
        break;
      case 'flex-end':
      default:
        horizontalPart = 'right';
    }

    return '$verticalPart-$horizontalPart';
  }


// ✅ NEW: Method to process notification data (extracted from existing logic)
  void _processNotificationData(Map<String, dynamic> data) async{
    // Extract type from template.style.code
    final type = data['template']?['style']?['code'] ?? '';

    // Extract content list from template.style.html as a single item list
    final htmlContent = data['template']?['style']?['html'] ?? '';
    final contentList = htmlContent.isNotEmpty ? [htmlContent] : [];

    final style = data['style'] ?? {};

    sdkPrint("Processing notification data - Type: $type");

    // ✅ Get contact_id and messageId for ACK
    final messageId = data['messageId'] ?? '';
    var deviceId = await getDeviceId();
    if (Platform.isIOS) {
      final iosInfo = await _deviceInfoPlugin.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? '';
    }
    final contactId = "${userId}_$deviceId";

    // 🔔 Immediately send ACK for the notification
    if (messageId.isNotEmpty && contactId.isNotEmpty) {
      await ackNotification(contactId, messageId);
    }

    if (type.toLowerCase().contains('popup') ||
        type.toLowerCase().contains('roadblock') ||
        type.toLowerCase().contains('roadblock-image')) {
      sdkPrint("POPUP or ROADBLOCK");
      if (contentList.isNotEmpty && buildContext != null) {
        _showPopupRoadblock(contentList, buildContext!);
      }
    }
    if (type?.toLowerCase().contains('bottomsheet')) {
      sdkPrint("BottomSheet");
      if (contentList.isNotEmpty && buildContext != null) {
        _showBottomSheetBanner(contentList, buildContext!);
      }
    }

    if (type?.toLowerCase().contains('banner')) {
      sdkPrint("BANNER");
      final align = getAlignment(style);
      sdkPrint('$contentList');
      if (contentList.isNotEmpty && buildContext != null) {
        _showBanner(contentList, buildContext!, align: align);
      }
    }
    if (type?.toLowerCase().contains('pip') || type?.toLowerCase().contains('picture-in-picture')) {
      // final align = (style['align'] ?? 'bottom-right').toString();
      final align = getAlignment(style);
      if (contentList.isNotEmpty && buildContext != null) {
        _showPip(contentList, buildContext!, align: align);
      }
    }
    if (type?.toLowerCase().contains('floater')) {
      final align = (style['align'] ?? 'bottom-right').toString();
      if (contentList.isNotEmpty && buildContext != null) {
        _showFloater(contentList, buildContext!, align: align);
      }
    }

    if (type?.toLowerCase().contains('placeholder')) {
      final placeholderId = data['template']?['code'];
      print("PlaceholderId $placeholderId");
      print("contentList $contentList");
      if (placeholderId != null && contentList.isNotEmpty) {
        sdkPrint("Dispatching content to placeholder: $placeholderId");
        _notifyPlaceholder(placeholderId, contentList);
      } else {
        sdkPrint("Placeholder data invalid or content missing.");
      }
    }
  }



  void _notifyPlaceholder(String placeholderId, List<dynamic> contentList) {
    final listener = _placeholderListeners[placeholderId];
    if (listener != null) {
      listener(contentList);
    } else {
      sdkPrint("No listener registered for placeholder: $placeholderId");
    }
  }




  void _showPip(
      List<dynamic> contentList,
      BuildContext context, {
        String align = "bottom-right", // will now include full 9 options
      }) {
    if (contentList.isEmpty || contentList.first is! String) return;

    final htmlContent = contentList.first as String;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(htmlContent);

    // ✅ Supports all 9 alignments
    final alignment = {
      'top-left': Alignment.topLeft,
      'top-center': Alignment.topCenter,
      'top-right': Alignment.topRight,
      'center-left': Alignment.centerLeft,
      'center-center': Alignment.center,
      'center-right': Alignment.centerRight,
      'bottom-left': Alignment.bottomLeft,
      'bottom-center': Alignment.bottomCenter,
      'bottom-right': Alignment.bottomRight,
    }[align] ?? Alignment.bottomRight;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (ctx) => Stack(
        children: [
          Align(
            alignment: alignment,
            child: Container(
              height: 200,
              width: 120,
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    /// WebView Content
                    WebViewWidget(controller: controller),

                    /// Overlay Click Handler
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _showPopupRoadblock([htmlContent], context);
                          },
                        ),
                      ),
                    ),

                    /// ✅ Share Icon on Top-Right
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        height: 32,
                        width: 32,
                        decoration: BoxDecoration(
                          color: Colors.black54, // translucent black
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/images/share.png',
                            height: 18,
                            width: 18,
                            color: Colors.white, // optional: force white tint
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }




  OverlayEntry? _floaterEntry;

  void _showFloater(List<dynamic> contentList, BuildContext context, {String align = "bottom-right"}) {
    if (contentList.isEmpty || contentList.first is! String) return;

    final htmlContent = contentList.first as String;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000)) // ✅ Transparent WebView
      ..loadHtmlString(htmlContent);

    final overlay = Overlay.of(context);
    final alignment = {
      'top-left': Alignment.topLeft,
      'top-right': Alignment.topRight,
      'bottom-left': Alignment.bottomLeft,
      'bottom-right': Alignment.bottomRight,
    }[align] ?? Alignment.bottomRight;

    _floaterEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        bottom: alignment.y == 1.0 ? 20 : null,
        top: alignment.y == -1.0 ? 20 : null,
        left: alignment.x == -1.0 ? 20 : null,
        right: alignment.x == 1.0 ? 20 : null,
        child: IgnorePointer(
          ignoring: false, // ✅ allow taps
          child: Material(
            color: Colors.transparent, // ✅ Fully transparent
            child: SizedBox(
              height: 200,
              width: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: WebViewWidget(controller: controller),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_floaterEntry!);
  }




  void _showBanner(List<dynamic> contentList, BuildContext context, {String align = "top"}) {
    if (contentList.isEmpty || contentList.first is! String) {
      sdkPrint("No banner HTML found.");
      return;
    }

    final htmlContent = (contentList.first as String).replaceAll('[[ALIGN]]', align == 'bottom' ? 'banner-bottom' : 'banner-top');

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(htmlContent);
    sdkPrint("show banner");
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent, // keep background interaction
      builder: (context) => Stack(
        children: [
          Align(
            alignment: align == 'bottom' ? Alignment.bottomCenter : Alignment.topCenter,
            child: Container(
              height: 100,
              width: MediaQuery.of(context).size.width,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: WebViewWidget(controller: controller),
              ),
            ),
          ),
        ],
      ),
    );
  }



  void _showPopupRoadblock(List<dynamic> contentList, BuildContext context) {
    String htmlContent = '';
    String imageUrl = '';

    // Determine if the content is HTML or an image
    for (var item in contentList) {
      if (item is String) {
        if (item.contains('<html')) {
          htmlContent = item;
          break;
        } else if (item.startsWith('http') &&
            (item.endsWith('.png') ||
                item.endsWith('.jpg') ||
                item.endsWith('.jpeg') ||
                item.endsWith('.gif') ||
                item.endsWith('.webp'))) {
          imageUrl = item;
          break;
        }
      }
    }

    if (htmlContent.isEmpty && imageUrl.isEmpty) {
      sdkPrint("No valid content (HTML or image) found.");
      return;
    }

    Widget contentWidget;

    if (htmlContent.isNotEmpty) {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadHtmlString(htmlContent)
        ..setBackgroundColor(const Color(0x00000000));

      // Inject viewport fix for iOS
      if (Platform.isIOS) {
        controller.runJavaScript('''
        if (!document.querySelector('meta[name=viewport]')) {
          var meta = document.createElement('meta');
          meta.name = 'viewport';
          meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
          document.head.appendChild(meta);
        }
      ''');
      }

      contentWidget = WebViewWidget(controller: controller);
    } else {
      contentWidget = Image.network(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
        const Center(child: Text("Failed to load image")),
      );
    }

    // Show dialog with the appropriate content
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Scaffold(
          backgroundColor: const Color.fromRGBO(0, 0, 0, 0.8),
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: contentWidget,
                    ),
                  ),
                ),
                Positioned(
                  top: 20,
                  right: 20,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 20),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _onNotificationClosed();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBottomSheetBanner(List<dynamic> contentList, BuildContext context) {
    String htmlContent = '';
    String imageUrl = '';

    // Determine if the content is HTML or an image
    for (var item in contentList) {
      if (item is String) {
        if (item.contains('<html')) {
          htmlContent = item;
          break;
        } else if (item.startsWith('http') &&
            (item.endsWith('.png') ||
                item.endsWith('.jpg') ||
                item.endsWith('.jpeg') ||
                item.endsWith('.gif') ||
                item.endsWith('.webp'))) {
          imageUrl = item;
          break;
        }
      }
    }

    if (htmlContent.isEmpty && imageUrl.isEmpty) {
      sdkPrint("No valid content (HTML or image) found.");
      return;
    }

    Widget contentWidget;

    if (htmlContent.isNotEmpty) {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadHtmlString(htmlContent);

      contentWidget = WebViewWidget(controller: controller);
    } else {
      contentWidget = Image.network(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
        const Center(child: Text("Failed to load image")),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.all(16),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 40), // Leave space for close button
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: contentWidget,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 20),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _onNotificationClosed();
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }





  Future<void> sendEvent(String eventName, Map<String, dynamic> eventData) async {
    final prefs = await SharedPreferences.getInstance();
    var userId = prefs.getString('user_id') ?? '';

    if (userId == "") {
      userId = guestId;
    }

    try {
      final deviceHeaders = await getDeviceHeaders();
      final url = '$serverUrl/pushapp/api/v1/event';
      final requestHeaders = {
        'Content-Type': 'application/json',
        ...deviceHeaders,
      };
      final requestBody = {
        'user_id': userId,
        'channel_id': channelId,
        'event_name': eventName,
        'event_data': eventData,
      };

      sdkPrint(jsonEncode(requestBody));

      final response = await http.post(
        Uri.parse(url),
        headers: requestHeaders,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        sdkPrint("Event sent successfully!");
      } else {
        sdkPrint("Failed to send event: ${response.body}");
        throw Exception("Failed to send event: ${response.body}");
      }

      // ✅ Log API call to Slack
      await postApiDetailsToSlack(
        url: url,
        method: "POST",
        requestHeaders: requestHeaders,
        requestBody: requestBody,
        response: response,
      );

    } catch (e) {
      sdkPrint("Error sending event: $e");

      // 🔴 Log exception to Slack as well
      await postApiDetailsToSlack(
        url: '$serverUrl/pushapp/api/v1/event',
        method: "POST",
        requestHeaders: {'Content-Type': 'application/json'},
        requestBody: {
          'user_id': userId,
          'channel_id': channelId,
          'event_name': eventName,
          'event_data': eventData,
        },
        response: http.Response("Exception: $e", 500),
      );
    }
  }



  /// Logs out the user and sends API details to Slack.
  Future<void> logout(String userId) async {
    try {
      var deviceId = await getDeviceId();
      final deviceHeaders = await getDeviceHeaders();

      final url = '$serverUrl/pushapp/api/logout';
      final requestHeaders = {
        'Content-Type': 'application/json',
        ...deviceHeaders,
      };
      final requestBody = {
        'user_id': userId,
        'device_id': deviceId,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: requestHeaders,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        sdkPrint("User logged out successfully!");
      } else {
        sdkPrint("Failed to log out user: ${response.body}");
        throw Exception("Failed to log out user: ${response.body}");
      }

      // ✅ Log API call to Slack
      await postApiDetailsToSlack(
        url: url,
        method: "POST",
        requestHeaders: requestHeaders,
        requestBody: requestBody,
        response: response,
      );

    } catch (e) {
      sdkPrint("Error logging out user: $e");

      // 🔴 Log error to Slack too
      await postApiDetailsToSlack(
        url: '$serverUrl/pushapp/api/logout',
        method: "POST",
        requestHeaders: {'Content-Type': 'application/json'},
        requestBody: {
          'user_id': userId,
          'device_id': 'unknown',
        },
        response: http.Response("Exception: $e", 500),
      );
    }
  }


  Future<String?> getDeviceId() async {
    return await AppSetId().getIdentifier();
  }


  Future<Map<String, String>> getDeviceHeaders() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final mediaData = PlatformDispatcher.instance.views.first.physicalSize;
    final orientation = mediaData.width > mediaData.height ? 'Landscape' : 'Portrait';

    final headers = <String, String>{
      'X-App-Version': packageInfo.version,
      'X-SDK-Version': packageInfo.buildNumber,
      'X-Screen-Resolution': '${mediaData.width.toInt()}x${mediaData.height.toInt()}',
      'X-Device-Orientation': orientation,
      'X-Bundle-ID': packageInfo.packageName,
      'X-Timezone': DateTime.now().timeZoneName,
      'X-Locale': Platform.localeName,
    };

    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfoPlugin.androidInfo;
      final deviceId = await getDeviceId();
      headers.addAll({
        'X-Device-Model': androidInfo.model,
        'X-OS-Name': 'ANDROID',
        'X-OS-Version': androidInfo.version.release,
        'X-Manufacturer': androidInfo.manufacturer,
        'X-API-Level': androidInfo.version.sdkInt.toString(),
        'X-Boot-Time': androidInfo.bootloader,
        'X-Device-ID': deviceId ?? '',
        'X-CPU-ABI': androidInfo.supportedAbis.join(', '),
      });

    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfoPlugin.iosInfo;
      headers.addAll({
        'X-Device-Model': iosInfo.model,
        'X-OS-Name': 'IOS',
        'X-OS-Version': iosInfo.systemVersion,
        'X-System-Name': iosInfo.systemName,
        'X-Device-ID': iosInfo.identifierForVendor ?? '',
        'X-Device-Name': iosInfo.name,
      });
    }
    return headers;
  }
}


class SocketService {
  WebSocketChannel? _channel;
  String? _userId;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  String? _tenant;
  bool _sandbox = false;
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  // Stream controller for notifications
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;

  // Connect to WebSocket
  void connect(String userId,String tenant,bool sandbox) {
    sdkPrint("Connect Called");
    _userId = userId;
    _tenant = tenant;
    _sandbox = sandbox;
    _connectToSocket();
  }

  void sdkPrint(String? message){
    debugPrint(message);
    if(message != null) {
      sendMessageToStack(message!);
    }
  }

  Future<void> sendMessageToStack(String message) async{
    const slackWebhookUrl = "https://hooks.slack.com/services/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";

    final payload = {
      "text": message
    };

    final res = await http.post(
      Uri.parse(slackWebhookUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      sdkPrint("Failed to send message to Slack: ${res.body}");
      throw Exception("Failed to send message to Slack: ${res.body}");
    }
  }

  void _connectToSocket() {
    sdkPrint("Connect to socket Called");
    try {
      // Replace with your actual WebSocket URL
      final wsUrl = 'wss://$_tenant.pushapp.${_sandbox ? "co.in" : "com"}/pushapp';
      // final wsUrl = 'wss://8e5aebdbe23d.ngrok-free.app/pushapp';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      sdkPrint(wsUrl);

      // Send authentication message
      _sendAuthMessage();

      // Listen for messages
      _channel!.stream.listen(
            (message) {
          _handleMessage(message);
        },
        onError: (error) {
          sdkPrint('Socket error: $error');
          _handleDisconnection();
        },
        onDone: () {
          sdkPrint('Socket connection closed');
          _handleDisconnection();
        },
      );

      _isConnected = true;
    } catch (e) {
      sdkPrint('Error connecting to socket: $e');
      _handleDisconnection();
    }
  }

  void _sendAuthMessage() async{
    if (_channel != null && _userId != null) {
      sdkPrint("Auth Called");
      var deviceId = "";
      if (Platform.isAndroid) {
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? '';
      }
      sdkPrint(_userId!+"_"+deviceId);
      final authMessage = {
        'type': 'auth',
        'userId': _userId!+"_"+deviceId,
      };
      _channel!.sink.add(jsonEncode(authMessage));
    }
  }

  void _handleMessage(dynamic message) {
    try {
      sdkPrint(message);
      final data = jsonDecode(message);
      if (data is Map<String, dynamic>) {
        if(data.containsKey("action")){
          if (data["action"] == "POLL"){
            _notificationController.add(data);
          }
        }
        switch (data['type']) {
          case 'auth':
            if (data['status'] == 'success') {
              sdkPrint('Socket authenticated successfully');
            } else {
              sdkPrint('Socket authentication failed: ${data['message']}');
            }
            break;
          case 'in_app':
            _notificationController.add(data);
            break;
          case 'error':
            sdkPrint('Socket error: ${data['message']}');
            break;
        }
      }
    } catch (e) {
      sdkPrint('Error handling message: $e');
    }
  }

  void _handleDisconnection() {
    _isConnected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected) {
        _connectToSocket();
      }
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _notificationController.close();
  }
}


class MeSendTooltipWrapper extends StatefulWidget {
  final String placeholderId;
  final Widget child;
  final MeSend meSend;

  const MeSendTooltipWrapper({
    super.key,
    required this.placeholderId,
    required this.child,
    required this.meSend,
  });

  @override
  State<MeSendTooltipWrapper> createState() => _MeSendTooltipWrapperState();
}

class _MeSendTooltipWrapperState extends State<MeSendTooltipWrapper> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _tooltipEntry;
  String? _currentHtml;

  @override
  void initState() {
    super.initState();
    widget.meSend.sendWidgetOpen(widget.placeholderId);
    widget.meSend.registerPlaceholderListener(widget.placeholderId, _onHtmlReceived);
  }

  @override
  void dispose() {
    widget.meSend.unregisterPlaceholderListener(widget.placeholderId);
    _tooltipEntry?.remove();
    super.dispose();
  }

  void _onHtmlReceived(List<dynamic> contentList) {
    if (contentList.isEmpty || contentList.first is! String) return;
    _currentHtml = contentList.first as String;
    _showTooltip();
  }

  void _showTooltip() {
    _tooltipEntry?.remove();

    final overlay = Overlay.of(context);
    if (overlay == null || _currentHtml == null) return;

    final tooltipWidth = 220.0;
    final tooltipHeight = 90.0;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..loadHtmlString(_wrapHtmlWithTransparency(_currentHtml!));

    _tooltipEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: CompositedTransformFollower(
          link: _layerLink,
          offset: Offset(0, -tooltipHeight), // Position above the widget
          showWhenUnlinked: false,
          child: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: tooltipWidth,
              height: tooltipHeight,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: WebViewWidget(controller: controller),
                  ),
                  // Positioned(
                  //   top: 0,
                  //   right: 0,
                  //   child: IconButton(
                  //     icon: const Icon(Icons.close, size: 20, color: Colors.white),
                  //     onPressed: () {
                  //       _tooltipEntry?.remove();
                  //       _tooltipEntry = null;
                  //     },
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_tooltipEntry!);
  }

  String _wrapHtmlWithTransparency(String rawHtml) {
    return '''
  <html>
    <head>
      <style>
        html, body {
          margin: 0;
          padding: 0;
          background: transparent;
          overflow: hidden;
          height: 100%;
          max-height: 100%;
        }
        * {
          box-sizing: border-box;
          margin: 0;
          padding: 0;
        }
        #tooltip-root {
          display: flex;
          flex-direction: column;
          justify-content: flex-start;
          align-items: flex-start;
          height: 100%;
        }
      </style>
      <script>
        document.addEventListener('touchmove', function(e) {
          e.preventDefault();
        }, { passive: false });
      </script>
    </head>
    <body>
      <div id="tooltip-root">
        $rawHtml
      </div>
    </body>
  </html>
  ''';
  }



  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: widget.child,
    );
  }
}




class MeSendWidget extends StatefulWidget {
  final String placeholderId;
  final double height;
  final double width;
  final MeSend meSend;

  const MeSendWidget({
    Key? key,
    required this.placeholderId,
    this.height = 200,
    this.width = double.infinity,
    required this.meSend
  }) : super(key: key);

  @override
  State<MeSendWidget> createState() => _MeSendWidgetState();
}

class _MeSendWidgetState extends State<MeSendWidget> {
  WebViewController? _controller;
  String? _htmlContent;

  @override
  void initState() {
    super.initState();

    // 🔔 1. Send widget open event
    widget.meSend.sendEvent('widget_open', {
      'placeholder_id': widget.placeholderId,
    });

    // 🧠 2. Register listener for placeholder content
    widget.meSend.registerPlaceholderListener(widget.placeholderId, _onContentReceived);
  }

  // 📥 Called when SDK receives content for this placeholder
  void _onContentReceived(List<dynamic> contentList) {
    if (contentList.isEmpty || contentList.first is! String) return;
    final html = contentList.first as String;

    setState(() {
      _htmlContent = html;
    });

    if (_controller != null) {
      _controller!.loadHtmlString(html);
    }
  }

  @override
  void dispose() {
    widget.meSend.unregisterPlaceholderListener(widget.placeholderId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black12)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _htmlContent != null
            ? WebViewWidget(
          controller: _controller ??= WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..loadHtmlString(_htmlContent!),
        )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}



class MeSendRouteObserver extends NavigatorObserver {
  static final MeSendRouteObserver _instance = MeSendRouteObserver._internal();
  factory MeSendRouteObserver() => _instance;
  MeSendRouteObserver._internal();

  MeSend? _meSend;

  void attachSDK(MeSend sdkInstance) {
    _meSend = sdkInstance;
  }

  @override
  void didPush(Route route, Route? previousRoute) async{
    if(_meSend != null) {
      final pageName = route.settings.name ?? route.toString();
      if (previousRoute != null) {
        final previousPageName = previousRoute.settings.name ??
            previousRoute.toString();
        _meSend!.sendEvent("page_closed", {"page": previousPageName});
      }
      // sdkPrint("SDK: Page Opened -> $pageName");
      await Future.delayed(Duration(seconds: 5));
      _meSend!.sendEvent("page_open", {"page": "login"});
    }

    // Send this info to analytics/logging server if needed
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if(_meSend != null) {
      final pageName = route.settings.name ?? route.toString();
      // sdkPrint("SDK: Page Closed -> $pageName");
      _meSend!.sendEvent("page_closed", {"page": pageName});
    }
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if(_meSend != null) {
      if (newRoute != null) {
        final pageName = newRoute.settings.name ?? newRoute.toString();
        // sdkPrint("SDK: Page Replaced -> $pageName");
        // _meSend!.sendEvent("page_open", {"page": "login"});
      }
      if (oldRoute != null) {
        final previousPageName = oldRoute.settings.name ??
            oldRoute.toString();
        _meSend!.sendEvent("page_closed", {"page": previousPageName});
      }


    }
  }
}

