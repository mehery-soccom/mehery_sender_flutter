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
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:super_tooltip/super_tooltip.dart';
import 'package:url_launcher/url_launcher.dart';




class MeSend {
  late final String serverUrl;

  List<Map<String, dynamic>> _notificationQueue = [];
  bool _isProcessingQueue = false;

  var mockJson = r'''
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

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _controller.stream;

  // MeSend._internal();



  // Updated constructor to handle tenant$channelId format
  MeSend({required String identifier, this.sandbox = false}) :
        tenant = identifier.split('\$')[0],
        channelId = identifier.split('\$').length > 1 ? identifier.split('\$')[1] : '' {
    serverUrl = 'https://$tenant.pushapp.${sandbox ? "co.in" : "com"}';

    const eventChannel = EventChannel("mesend_event_channel");

    eventChannel.receiveBroadcastStream().listen((data) {
      if (data is Map) {
        final event = Map<String, dynamic>.from(data);
        _controller.add(event);
        track(event);
      }
    });
    // serverUrl = 'https://8e5aebdbe23d.ngrok-free.app';
    if (channelId.isEmpty) {
      throw ArgumentError('Invalid identifier format. Expected format: tenant\$channelId');
    }

    meSendRouteObserver.attachSDK(this);
  }

  Future<void> track(Map<String, dynamic> event) async {
    final url = Uri.parse("https://demo.pushapp.co.in/pushapp/api/v1/notification/push/track");

    final token = event["t"] ?? event["token"] ?? userId;
    final eventName = event["event"];
    final ctaId = event["ctaId"];

    if (token == null || eventName == null) return;

    final body = {
      "t": token,
      "event": eventName,
      "data": ctaId != null ? {"ctaId": ctaId} : {}
    };

    await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );
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
    Future.delayed(const Duration(seconds: 2), () {
      _pollForNotificationData(userId);
    });
  }

  /// Initializes the SDK and sends the appropriate token (Firebase or APNs).
  Future<void> initializeAndSendToken() async {
    sdkPrint("Started Load");

    setupMethodChannelHandler();
    sendEvent("app_open", {});
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('user_id') ?? '';
    String? lastToken = prefs.getString('device_token');

    // ✅ If user already logged in, do nothing
    if (userId.isNotEmpty) {
      sdkPrint("User already logged in: $userId");
      _setupSocket(userId); // optional: just to reconnect socket
      // If user not logged in, send token
      try {
        FirebaseMessaging messaging = FirebaseMessaging.instance;
        await messaging.requestPermission();

        if (Platform.isAndroid) {
          String? firebaseToken = await messaging.getToken();
          if (firebaseToken != null && lastToken != firebaseToken) {
            await updateDeviceToken(firebaseToken);
          } else {
            sdkPrint("Failed to retrieve Firebase token on Android.");
          }
        } else if (Platform.isIOS) {
          String? apnsToken = await messaging.getAPNSToken();
          if (apnsToken != null) {
            await updateDeviceToken(apnsToken);
          } else {
            sdkPrint("Failed to retrieve APNs token on iOS.");
          }
        } else {
          sdkPrint("Unsupported platform.");
        }
      } catch (e) {
        sdkPrint("Error initializing FirebaseTokenSender: $e");
      }
      return;
    }

    // If user not logged in, send token
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      if (Platform.isAndroid) {
        String? firebaseToken = await messaging.getToken();
        if (firebaseToken != null) {
          await prefs.setString('device_token', firebaseToken);
          await sendTokenToServer('android', firebaseToken!);
        } else {
          sdkPrint("Failed to retrieve Firebase token on Android.");
        }
      } else if (Platform.isIOS) {
        String? apnsToken = await messaging.getAPNSToken();
        await prefs.setString('device_token', apnsToken!);
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
    // const slackWebhookUrl = "https://hooks.slack.com/services/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";
    //
    // final payload = {
    //   "text": message
    // };
    //
    // final res = await http.post(
    //   Uri.parse(slackWebhookUrl),
    //   headers: {"Content-Type": "application/json"},
    //   body: jsonEncode(payload),
    // );
    //
    // if (res.statusCode != 200) {
    //   sdkPrint("Failed to send message to Slack: ${res.body}");
    //   throw Exception("Failed to send message to Slack: ${res.body}");
    // }
  }


  Future<void> postApiDetailsToSlack({
    required String url,
    required String method,
    required Map<String, String> requestHeaders,
    required dynamic requestBody,
    required http.Response response,
  }) async {
//     const slackWebhookUrl = "https://hooks.slack.com/services/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";
//
//     final payload = {
//       "text": """
// *API Call Details:*
// • *URL*: $url
// • *Method*: $method
// • *Request Headers*: ${jsonEncode(requestHeaders)}
// • *Request Body*: ${jsonEncode(requestBody)}
// • *Response Status*: ${response.statusCode}
// • *Response Body*: ${response.body}
// • *Response Headers*: ${jsonEncode(response.headers)}
// """
//     };
//
//     final res = await http.post(
//       Uri.parse(slackWebhookUrl),
//       headers: {"Content-Type": "application/json"},
//       body: jsonEncode(payload),
//     );
//
//     if (res.statusCode != 200) {
//       sdkPrint("Failed to send message to Slack: ${res.body}");
//       throw Exception("Failed to send message to Slack: ${res.body}");
//     }
  }

  void setupMethodChannelHandler() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'trackNotification') {
        final args = Map<String, dynamic>.from(call.arguments as Map);

        final token = args['token'] as String;
        final event = args['event'] as String; // changed from eventType → event
        final ctaId = args['ctaId'] as String?;

        await trackNotificationEvent(token, event, ctaId: ctaId);
      }
    });
  }


  Future<void> trackNotificationEvent(String token, String event, {String? ctaId}) async {
    final url = Uri.parse('$serverUrl/pushapp/api/v1/notification/push/track');

    final body = {
      't': token,
      'event': event,
      if (ctaId != null) 'data': {'ctaId': ctaId},
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        sdkPrint('✅ Notification event "$event" tracked successfully.');
      } else {
        sdkPrint('❌ Failed to track event ($event): ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      sdkPrint('❌ Error tracking notification event: $e');
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


  Future<void> updateDeviceToken(String token) async {
    sdkPrint("🔄 updateDeviceToken() called");
    final url = '$serverUrl/pushapp/api/update/token';

    var deviceId = await getDeviceId();
    final contactId = "${userId}_$deviceId";

    try {
      final requestBody = {
        'contact_id': contactId,
        'token': token,
        'channel_id': channelId,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        sdkPrint("✅ Token updated successfully on server.");
      } else {
        sdkPrint("❌ Failed to update token: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      sdkPrint("🔥 Error updating device token: $e");
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
        deviceId = deviceId ?? '';
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
            bool tooltipShown = false;
            for (final item in results) {
              try {
                final style = item["template"]?["style"];
                final code = style?["code"];
                final compareId = item["event"]?["event_data"]?["compare"];
                final messageId = item['messageId'] ?? '';

                // ✅ Check for tooltip template
                if (code == "tooltip" && compareId != null) {
                  // Push into TooltipSdk
                  sdk.processApiResponse({
                    "results": [item]
                  });
                  await Future.delayed(const Duration(seconds: 2));
                  // Optionally trigger show immediately
                  tooltipShown = true;
                  await sdk.showTooltipFor(compareId);

                  var deviceId = await getDeviceId();
                  if (Platform.isIOS) {
                    deviceId = deviceId ?? '';
                  }
                  final contactId = "${userId}_$deviceId";

                  // 🔔 Immediately send ACK for the notification
                  if (messageId.isNotEmpty && contactId.isNotEmpty) {
                    await ackNotification(contactId, messageId);
                  }

                  sdk.onTooltipDismissedCallback = () {
                    sdkPrint("Tooltip dismissed callback fired → processing queue");
                    _processNextFromQueue();
                    sdk.onTooltipDismissedCallback = null; // cleanup
                  };
                } else {
                  // Non-tooltip → push to your existing notification queue
                  _notificationQueue.add(item);
                  await Future.delayed(Duration(seconds: 1));
                }
              } catch (e) {
                sdkPrint("Error processing result item: $e");
              }
            }
            if(!tooltipShown) {
              _processNextFromQueue();
            }
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
    sdkPrint(style.toString());
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

    final style = data['template']?['style'] ?? {};

    sdkPrint("Processing notification data - Type: $type");

    // ✅ Get contact_id and messageId for ACK
    final messageId = data['messageId'] ?? '';
    final filterId = data['filterId'] ?? '';
    var deviceId = await getDeviceId();
    if (Platform.isIOS) {
      deviceId = deviceId ?? '';
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
        _showPopupRoadblock(contentList,messageId,filterId, buildContext!);
      }
    }
    if (type?.toLowerCase().contains('bottomsheet')) {
      sdkPrint("BottomSheet");
      if (contentList.isNotEmpty && buildContext != null) {
        _showBottomSheetBanner(contentList,messageId,filterId, buildContext!);
      }
    }

    if (type?.toLowerCase().contains('banner')) {
      sdkPrint("BANNER");
      // final align = getAlignment(style);
      if (contentList.isNotEmpty && buildContext != null) {
        sdkPrint("Going in Show Banner");
        _showBanner(contentList,messageId,filterId, buildContext!, align: "top");
      }
    }
    if (type?.toLowerCase().contains('pip') || type?.toLowerCase().contains('picture-in-picture')) {
      // final align = (style['align'] ?? 'bottom-right').toString();
      sdkPrint("PIP STARTED");
      sdkPrint(style.toString());
      final align = getAlignment(style);
      sdkPrint(align);
      if (contentList.isNotEmpty && buildContext != null) {
        _showPip(contentList,messageId,filterId, buildContext!, align: align);
      }
    }
    if (type?.toLowerCase().contains('floater')) {
      final align = (style['align'] ?? 'bottom-right').toString();
      bool draggable = style['draggable'];
      if (contentList.isNotEmpty && buildContext != null) {
        _showFloater(contentList, buildContext!, align: align, draggable: draggable);
      }
    }

    if (type?.toLowerCase().contains('inline')) {
      final placeholderId = data['event']?['event_data']?["compare"];
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
      String messageId,
      String filterId,
      BuildContext context, {
        String align = "bottom-right", // supports 9 alignments
      }) {
    if (contentList.isEmpty || contentList.first is! String) return;

    final htmlContent = contentList.first as String;

    final controller = WebViewController();

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'InAppChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _handleJsMessage(message.message, messageId, filterId);
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
          _onNotificationClosed();
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            // Inject JS bridge for CTA clicks
            await controller.runJavaScript('''
            window.handleClick = function(eventType, lab, val) {
              var message = JSON.stringify({
                event: eventType,
                timestamp: Date.now(),
                data: { url: "", label: lab, value: val }
              });
              InAppChannel.postMessage(message);
            };
          ''');
          },
          onNavigationRequest: (request) {
            final url = request.url;
            if (url.startsWith('http')) {
              _handleCta(url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(htmlContent);

    // Map align string to Alignment
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
                            _showPopupRoadblock([htmlContent], messageId, filterId, context);

                          },
                        ),
                      ),
                    ),

                    /// Share Icon on Top-Right
                    InkWell(
                      child: Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          height: 32,
                          width: 32,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/share.png',
                              height: 18,
                              width: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _showPopupRoadblock([htmlContent], messageId, filterId, context);

                      },
                    )
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

  void _showFloater(
      List<dynamic> contentList,
      BuildContext context, {
        String align = "bottom-right",
        bool draggable = false,
      }) {
    if (contentList.isEmpty || contentList.first is! String) return;

    final htmlContent = contentList.first as String;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..loadHtmlString(htmlContent);

    final overlay = Overlay.of(context);

    // ✅ Initial position based on alignment
    Offset initialOffset;
    switch (align) {
      case "top-left":
        initialOffset = const Offset(20, 20);
        break;
      case "top-right":
        initialOffset = Offset(MediaQuery.of(context).size.width - 220, 20);
        break;
      case "bottom-left":
        initialOffset = Offset(20, MediaQuery.of(context).size.height - 220);
        break;
      case "bottom-right":
      default:
        initialOffset = Offset(
          MediaQuery.of(context).size.width - 220,
          MediaQuery.of(context).size.height - 220,
        );
    }

    final positionNotifier = ValueNotifier<Offset>(initialOffset);

    _floaterEntry = OverlayEntry(
      builder: (ctx) {
        return ValueListenableBuilder<Offset>(
          valueListenable: positionNotifier,
          builder: (context, offset, _) {
            final floater = RepaintBoundary(
              child: Container(
                height: 200,
                width: 200,
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                child: AbsorbPointer(
                  absorbing: !draggable,
                  child: ClipRect( // ✅ clean clip, no AA blending
                    clipBehavior: Clip.hardEdge,
                    child: WebViewWidget(controller: controller),
                  ),
                ),
              ),
            );

            return Positioned(
              left: offset.dx,
              top: offset.dy,
              child: draggable
                  ? GestureDetector(
                onPanUpdate: (details) {
                  positionNotifier.value = Offset(
                    offset.dx + details.delta.dx,
                    offset.dy + details.delta.dy,
                  );
                },
                child: floater,
              )
                  : floater,
            );
          },
        );
      },
    );

    overlay.insert(_floaterEntry!);
  }


  void _showBanner(
      List<dynamic> contentList,
      String messageId,
      String filterId,
      BuildContext context, {
        String align = "top",
      }) {
    if (contentList.isEmpty || contentList.first is! String) {
      sdkPrint("No banner HTML found.");
      return;
    }

    sdkPrint("Show Banner Called");

    final htmlContent = (contentList.first as String)
        .replaceAll('[[ALIGN]]', align == 'bottom' ? 'banner-bottom' : 'banner-top');

    final controller = WebViewController();

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'InAppChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _handleJsMessage(message.message, messageId, filterId);
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
          _onNotificationClosed();
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            // Inject JS bridge for CTA clicks
            await controller.runJavaScript('''
            window.handleClick = function(eventType, lab, val) {
              var message = JSON.stringify({
                event: eventType,
                timestamp: Date.now(),
                data: { url: "", label: lab, value: val }
              });
              InAppChannel.postMessage(message);
            };
          ''');
          },
          onNavigationRequest: (request) {
            final url = request.url;
            if (url.startsWith('http')) {
              _handleCta(url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(htmlContent);

    sdkPrint("show banner");

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (context) => Align(
        alignment: align == 'bottom' ? Alignment.bottomCenter : Alignment.topCenter,
        child: Container(
          height: 100,
          width: MediaQuery.of(context).size.width,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                SizedBox.expand(
                  child: WebViewWidget(controller: controller),
                ),
                // Close button
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        trackInAppEvent(
                          messageId: messageId,
                          event: "dismissed",
                          completion: (success) {},
                        );
                        Navigator.of(context).pop();
                        _onNotificationClosed();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

  }


  void _showPopupRoadblock(List<dynamic> contentList,String messageId,String filterId, BuildContext context) {
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
      debugPrint("❌ No valid content (HTML or image) found.");
      return;
    }

    Widget contentWidget;

    if (htmlContent.isNotEmpty) {

      // 1️⃣ Create platform-specific params
      late final PlatformWebViewControllerCreationParams params;

      if (Platform.isIOS) {
        // iOS: WebKit-specific params
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true, // ✅ allow inline
        );
      } else {
        // Android / default
        params = const PlatformWebViewControllerCreationParams();
      }

// 2️⃣ Create controller
      final controller = WebViewController.fromPlatformCreationParams(params);

      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..addJavaScriptChannel(
          'InAppChannel',
          onMessageReceived: (JavaScriptMessage message) {
            _handleJsMessage(message.message, messageId, filterId);
            Navigator.of(context).pop();
            _onNotificationClosed();
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (url) async {
              // CTA bridge
              await controller.runJavaScript('''
          window.handleClick = function(eventType, lab, val) {
            var message = JSON.stringify({
              event: eventType,
              timestamp: Date.now(),
              data: { url: "", label: lab, value: val }
            });
            InAppChannel.postMessage(message);
          };
        ''');

              // Autoplay video fix
              await controller.runJavaScript('''
  document.querySelectorAll('video').forEach(function(v) {
    // Remove poster and controls
    v.removeAttribute('poster');
    v.controls = false;
    v.muted = true;
    v.playsInline = true;
    v.autoplay = true;

    // Force reload to clear poster frame (important on Android WebView)
    try {
      v.load();
      v.currentTime = 0;
    } catch (e) {
      console.log('Video reload error', e);
    }

    // Start playing (catch autoplay block)
    var playPromise = v.play();
    if (playPromise !== undefined) {
      playPromise.catch(function(error) {
        console.log('Autoplay blocked', error);
      });
    }

    // Optional: keep removing poster if re-added by scripts
    const observer = new MutationObserver(function(mutations) {
      mutations.forEach(function(m) {
        if (m.attributeName === 'poster') {
          v.removeAttribute('poster');
        }
      });
    });
    observer.observe(v, { attributes: true });
  });
''');

              // Viewport fix for iOS
              if (Platform.isIOS) {
                await controller.runJavaScript('''
            if (!document.querySelector('meta[name=viewport]')) {
              var meta = document.createElement('meta');
              meta.name = 'viewport';
              meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
              document.head.appendChild(meta);
            }
          ''');
              }
            },
            onNavigationRequest: (request) {
              final url = request.url;
              if (url.startsWith('http')) {
                _handleCta(url);
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        )
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

    // Show dialog with the WebView or image
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Scaffold(
          backgroundColor: Colors.black, // full screen dark background
          body: Stack(
            children: [
              // Fullscreen WebView
              Positioned.fill(
                child: contentWidget, // WebView or Image
              ),

              // Close button overlay
              Positioned(
                top: 40,
                right: 20,
                child: Container(
                  width: 24, // make circle smaller
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero, // removes extra space inside button
                    constraints: const BoxConstraints(), // removes default min size (48x48)
                    icon: const Icon(Icons.close, color: Colors.white, size: 12),
                    onPressed: () {
                      trackInAppEvent(
                        messageId: messageId,
                        event: "dismissed",
                        completion: (success) {},
                      );
                      Navigator.of(context).pop();
                      _onNotificationClosed();
                    },
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }


  void _showBottomSheetBanner(
      List<dynamic> contentList,
      String messageId,
      String filterId,
      BuildContext context,
      ) {
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
      debugPrint("❌ No valid content (HTML or image) found.");
      return;
    }

    Widget contentWidget;

    if (htmlContent.isNotEmpty) {
      final controller = WebViewController();

      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..addJavaScriptChannel(
          'InAppChannel',
          onMessageReceived: (JavaScriptMessage message) {
            _handleJsMessage(message.message, messageId, filterId);
            Navigator.of(context).pop();
            _onNotificationClosed();
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (url) async {
              await controller.runJavaScript('''
              window.handleClick = function(eventType, lab, val) {
                var message = JSON.stringify({
                  event: eventType,
                  timestamp: Date.now(),
                  data: { url: "", label: lab, value: val }
                });
                InAppChannel.postMessage(message);
              };
            ''');

              // Autoplay fix
              await controller.runJavaScript('''
              document.querySelectorAll('video').forEach(function(v) {
                // Remove or override poster
                v.removeAttribute('poster'); // Option 1: remove poster
                // v.setAttribute('poster', 'data:image/gif;base64,R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs='); // Option 2: transparent pixel
                v.muted = true;
                v.playsInline = true;
                v.autoplay = true;
                var playPromise = v.play();
                if (playPromise !== undefined) {
                  playPromise.catch(function(error) {
                    console.log('Autoplay blocked', error);
                  });
                }
              });
            ''');

              // Viewport fix for iOS
              if (Platform.isIOS) {
                await controller.runJavaScript('''
                if (!document.querySelector('meta[name=viewport]')) {
                  var meta = document.createElement('meta');
                  meta.name = 'viewport';
                  meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
                  document.head.appendChild(meta);
                }
              ''');
              }
            },
            onNavigationRequest: (request) {
              final url = request.url;
              if (url.startsWith('http')) {
                _handleCta(url);
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        )
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

    // Show the bottom sheet
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
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox.expand(
                      child: contentWidget,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        onPressed: () {
                          trackInAppEvent(
                            messageId: messageId,
                            event: "dismissed",
                            completion: (success) {},
                          );
                          Navigator.of(context).pop();
                          _onNotificationClosed();
                        },
                      ),
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




  void _handleJsMessage(String body,String messageId,String filterId) async {
    debugPrint("📩 JS → Flutter message: $body");

    try {
      final decoded = jsonDecode(body);
      final event = "cta";
      final ctaId = decoded["data"]?["value"] ?? "";

      if (ctaId.isEmpty) return;

      // Handle CTA
      _handleCta(ctaId);

      // Track event (equivalent to PushApp.shared.trackInAppEvent)
      trackInAppEvent(messageId: messageId, event: event, filterId: filterId, ctaId: ctaId,completion: (success) {
        if (success) {
          print("✅ Tracked in-app event successfully");
        } else {
          print("❌ Failed to track in-app event");
        }
      }
      );
    } catch (e) {
      debugPrint("❌ Failed to parse JS message: $e");
    }
  }

  Future<void> _handleCta(String ctaId) async {
    try {
      final uri = Uri.tryParse(ctaId);
      if (uri != null && (uri.isScheme("http") || uri.isScheme("https"))) {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        debugPrint("📍 CTA String ID: $ctaId (non-URL)");
        // TODO: handle internal CTA actions here (e.g., navigate to screen)
      }
    } catch (e) {
      debugPrint("❌ Failed to handle CTA: $e");
    }
  }

  Future<void> trackInAppEvent({
    required String messageId,
    required String event,
    String? filterId,
    String? ctaId,
    required void Function(bool success) completion,
  }) async {
    final url = Uri.parse('$serverUrl/pushapp/api/v1/notification/in-app/track');
    print("📡 trackInAppEvent → $url");

    try {
      // Get device headers
      final deviceHeaders = await getDeviceHeaders();

      final requestHeaders = {
        'Content-Type': 'application/json',
        ...deviceHeaders,
      };

      // Build request body
      final body = <String, dynamic>{
        'messageId': messageId,
        'event': event,
      };

      if (filterId != null) body['filterId'] = filterId;
      if (ctaId != null) body['data'] = {'ctaId': ctaId};

      final jsonBody = jsonEncode(body);
      print("✅ Payload for in-app track:\n$jsonBody");

      // Send API request
      final response = await http.post(
        url,
        headers: requestHeaders,
        body: jsonBody,
      );

      print("🌐 In-app track → Status: ${response.statusCode}");

      if (response.statusCode >= 200 && response.statusCode < 300) {
        completion(true);
      } else {
        print("❌ Failed response: ${response.body}");
        completion(false);
      }

      // Optional: log to Slack or analytics if needed
      await postApiDetailsToSlack(
        url: url.toString(),
        method: "POST",
        requestHeaders: requestHeaders,
        requestBody: body,
        response: response,
      );
    } catch (e) {
      print("❌ In-app track request failed: $e");

      await postApiDetailsToSlack(
        url: '$serverUrl/pushapp/api/v1/notification/in-app/track',
        method: "POST",
        requestHeaders: {'Content-Type': 'application/json'},
        requestBody: {
          'messageId': messageId,
          'event': event,
          'filterId': filterId,
          'data': {'ctaId': ctaId},
        },
        response: http.Response("Exception: $e", 500),
      );

      completion(false);
    }
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
        _pollForNotificationData(this.userId);
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


  static const _key = "persistent_device_id";
  static String? _cachedDeviceId;

  static Future<String> getDeviceId() async {
    // If already loaded in memory
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    final prefs = await SharedPreferences.getInstance();
    final storedId = prefs.getString(_key);

    if (storedId != null) {
      _cachedDeviceId = storedId;
      return _cachedDeviceId!;
    }

    // First time: generate new ID
    final id = await AppSetId().getIdentifier();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    _cachedDeviceId = "${id}_$timestamp";

    // Persist to storage
    await prefs.setString(_key, _cachedDeviceId!);

    return _cachedDeviceId!;
  }


  final TooltipSdk sdk = TooltipSdk();
  Widget registerWidget({
    required String placeholderId,
    required Widget child,
  }) {
    sendEvent("widget_open", {"compare": placeholderId});
    return sdk.registerWidget(placeholderId: placeholderId, child: child);
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
      final deviceId = await getDeviceId();
      final iosInfo = await _deviceInfoPlugin.iosInfo;
      headers.addAll({
        'X-Device-Model': iosInfo.model,
        'X-OS-Name': 'IOS',
        'X-OS-Version': iosInfo.systemVersion,
        'X-System-Name': iosInfo.systemName,
        'X-Device-ID': deviceId ?? '',
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
    // const slackWebhookUrl = "https://hooks.slack.com/services/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";
    //
    // final payload = {
    //   "text": message
    // };
    //
    // final res = await http.post(
    //   Uri.parse(slackWebhookUrl),
    //   headers: {"Content-Type": "application/json"},
    //   body: jsonEncode(payload),
    // );
    //
    // if (res.statusCode != 200) {
    //   sdkPrint("Failed to send message to Slack: ${res.body}");
    //   throw Exception("Failed to send message to Slack: ${res.body}");
    // }
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
      var deviceId = await MeSend.getDeviceId();
      // if (Platform.isAndroid) {
      // } else if (Platform.isIOS) {
      //   final iosInfo = await _deviceInfoPlugin.iosInfo;
      //   deviceId = iosInfo.identifierForVendor ?? '';
      // }
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

    widget.meSend.sendEvent('widget_open', {
      'compare': widget.placeholderId,
    });

    widget.meSend.registerPlaceholderListener(widget.placeholderId, _onContentReceived);

    // Initialize controller immediately with all settings
    _initializeWebViewController();
  }

  void _initializeWebViewController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent) // Ensure background is transparent

    // Configure the Navigation Delegate
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            // FIX 1: Inject CSS to hide scrollbars and ensure content fits
            await _controller!.runJavaScript('''
              document.body.style.overflow = 'hidden';
              document.body.style.margin = '0';
              document.documentElement.style.overflow = 'hidden';
            ''');

            // ⭐ FIX 2: Force scroll to the very top (0, 0)
            await _controller!.runJavaScript('window.scrollTo(0, 0);');
          },
        ),
      );
  }

  void _onContentReceived(List<dynamic> contentList) {
    if (contentList.isEmpty || contentList.first is! String) return;

    final rawHtml = contentList.first as String;

    // Wrap HTML with viewport and essential CSS to prevent unwanted initial margins/behavior
    final html = '''
      <!DOCTYPE html>
      <html>
      <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <style>
              body, html { 
                  margin: 0; 
                  padding: 0; 
                  /* Ensure the HTML body is not taller than its content */
                  height: 100%; 
                  width: 100%;
              }
          </style>
      </head>
      <body>
          $rawHtml
      </body>
      </html>
    ''';


    if (!mounted) return;

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
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _htmlContent != null
            ? WebViewWidget(
          // Controller is now guaranteed to be non-null after initState
          controller: _controller!,
        )
            : const Center(child: Spacer()),
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
      // _meSend!.sendEvent("page_open", {"page": "login"});
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

class TooltipStyle {
  final String line1;
  final String line2;
  final String bgColor;
  final String line1Color;
  final String line1Icon;
  final double line1Size;
  final double width;
  final String line2Color;
  final double line2Size;
  final List<String> line1TextStyles; // ✅ added
  final List<String> line2TextStyles; // ✅ added

  TooltipStyle({
    required this.line1,
    required this.line2,
    required this.bgColor,
    required this.line1Color,
    required this.line1Icon,
    required this.line1Size,
    required this.width,
    required this.line2Color,
    required this.line2Size,
    required this.line1TextStyles, // ✅ added
    required this.line2TextStyles, // ✅ added
  });

  /// 👇 Put the decoder inside the class
  static String decodeHtmlEntity(String input) {
    final regex = RegExp(r'&#(\d+);');
    return input.replaceAllMapped(regex, (match) {
      final codePoint = int.tryParse(match.group(1)!);
      if (codePoint != null) {
        return String.fromCharCode(codePoint);
      }
      return match.group(0)!;
    });
  }

  factory TooltipStyle.fromJson(Map<String, dynamic> json) {
    return TooltipStyle(
      line1: json["line_1"] ?? "",
      line2: json["line_2"] ?? "",
      line1Icon: json["line1_icon"] != null
          ? TooltipStyle.decodeHtmlEntity(json["line1_icon"])
          : "",
      bgColor: (json["bg_color"] as String?)?.isNotEmpty == true
          ? json["bg_color"]
          : "#000000",
      line1Color: (json["line1_font_color"] as String?)?.isNotEmpty == true
          ? json["line1_font_color"]
          : "#FFFFFF",
      line1Size: (json["line1_font_size"] ?? 14).toDouble(),
      line2Color: (json["line2_font_color"] as String?)?.isNotEmpty == true
          ? json["line2_font_color"]
          : "#FFFFFF",
      line2Size: (json["line2_font_size"] ?? 12).toDouble(),
      width: (json["width"] ?? 70).toDouble(),
      line1TextStyles: (json["line1_text_styles"] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
          [], // ✅ safe parse
      line2TextStyles: (json["line2_text_styles"] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
          [], // ✅ safe parse
    );
  }

  @override
  String toString() {
    return "TooltipStyle(line1='$line1', line2='$line2', "
        "bgColor=$bgColor, line1Color=$line1Color, line1Size=$line1Size, "
        "line2Color=$line2Color, line2Size=$line2Size, "
        "line1TextStyles=$line1TextStyles, line2TextStyles=$line2TextStyles)";
  }
}



class TooltipSdk extends ChangeNotifier {
  static final TooltipSdk _instance = TooltipSdk._internal();
  factory TooltipSdk() => _instance;
  TooltipSdk._internal();

  final Map<String, TooltipStyle> _tooltipData = {};
  final Map<String, SuperTooltipController> _controllers = {};
  final Map<String, Widget> _tooltipWidgets = {};
  VoidCallback? onTooltipDismissedCallback;

  void _handleTooltipDismissed(String placeholderId) {
    debugPrint("🟢 Tooltip dismissed for $placeholderId");
    if (onTooltipDismissedCallback != null) {
      onTooltipDismissedCallback!();
    }
  }


  Color _parseColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) hex = "FF$hex";
    return Color(int.parse(hex, radix: 16));
  }

  /// Register a widget with a placeholder ID
  Widget registerWidget({
    required String placeholderId,
    required Widget child,
  }) {
    final controller = SuperTooltipController();
    _controllers[placeholderId] = controller;
    print('Saved controller hash: ${identityHashCode(controller)}');

    return AnimatedBuilder(
      animation: this, // listens to notifyListeners()
      builder: (context, _) {
        final style = _tooltipData[placeholderId];
        final screenWidth = MediaQuery.of(context).size.width;

        // Helper function to build TextStyle from styles list
        TextStyle _buildTextStyle({
          required double fontSize,
          required String color,
          required List<String> styles,
        }) {
          bool isBold = styles.contains("bold");
          bool isItalic = styles.contains("italic");
          bool isUnderline = styles.contains("underline");

          final parsedColor = _parseColor(color);

          return TextStyle(
            fontSize: fontSize,
            color: parsedColor,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
            decoration:
            isUnderline ? TextDecoration.underline : TextDecoration.none,
            decorationColor: parsedColor, // ✅ underline matches text color
            decorationThickness: 1.5, // ✅ optional: makes underline more visible
          );
        }

        final content = style != null
            ? SizedBox(
          width: screenWidth * (style.width / 100),
          child: Stack(
            children: [
              // 👇 Actual content
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (style.line1.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (style.line1Icon.isNotEmpty)
                              Text(
                                style.line1Icon,
                                style: _buildTextStyle(
                                  fontSize: style.line1Size,
                                  color: style.line1Color,
                                  styles: style.line1TextStyles,
                                ),
                              ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                style.line1,
                                style: _buildTextStyle(
                                  fontSize: style.line1Size,
                                  color: style.line1Color,
                                  styles: style.line1TextStyles,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (style.line2.isNotEmpty)
                      Text(
                        style.line2,
                        style: _buildTextStyle(
                          fontSize: style.line2Size,
                          color: style.line2Color,
                          styles: style.line2TextStyles,
                        ),
                      ),
                  ],
                ),
              ),

              // 👇 Close button at top right
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () {
                    controller.hideTooltip(); // closes tooltip
                    TooltipSdk()._handleTooltipDismissed(placeholderId);
                  },
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        )
            : const SizedBox.shrink();

        return SuperTooltip(
          controller: controller,
          showBarrier: true,
          backgroundColor: style != null
              ? _parseColor(style.bgColor)
              : Colors.transparent,
          content: content,
          child: child,
        );
      },
    );




  }


  /// Process API response and update tooltip styles
  void processApiResponse(Map<String, dynamic> response) {
    final results = response["results"] as List?;
    if (results == null || results.isEmpty) return;

    for (var item in results) {
      final compareId = item["event"]?["event_data"]?["compare"];
      final styleJson = item["template"]?["style"];

      if (compareId != null && styleJson != null) {
        _tooltipData[compareId] = TooltipStyle.fromJson(styleJson);
        debugPrint("✅ Tooltip data loaded for $compareId");
      }
    }

    notifyListeners(); // triggers AnimatedBuilder to rebuild content
  }


  /// Show tooltip for a registered placeholder
  Future<void> showTooltipFor(String placeholderId) async {
    final controller = _controllers[placeholderId];
    print('Retrieved controller hash: ${identityHashCode(controller)}');
    if (controller != null) {
      debugPrint("🚀 Showing tooltip for $placeholderId");
      await controller.showTooltip();
    } else {
      debugPrint("⚠️ No controller found for $placeholderId");
    }
  }
}






