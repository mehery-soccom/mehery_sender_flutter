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
import 'package:flutter/widgets.dart';



class MeSend {
  late final String serverUrl;

  // final String serverUrl = "https://demo.mehery.xyz";

  final String tenant;
  final String channelId;
  bool sandbox = false;
  String userId = "";
  String guestId = "";
  BuildContext? buildContext = null;

  final MeSendRouteObserver meSendRouteObserver = MeSendRouteObserver();

  final SocketService _socketService = SocketService();

  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  static const _channel = MethodChannel('mehery_channel');

  // Updated constructor to handle tenant$channelId format
  MeSend({required String identifier, bool sandbox = false}) :
        tenant = identifier.split('\$')[0],
        channelId = identifier.split('\$').length > 1 ? identifier.split('\$')[1] : '' {
    this.sandbox = sandbox;
    serverUrl = 'https://$tenant.mehery.${sandbox ? "xyz" : "com"}';
    if (channelId.isEmpty) {
      throw ArgumentError('Invalid identifier format. Expected format: tenant\$channelId');
    }

    meSendRouteObserver.attachSDK(this);
  }

  /// Initializes the SDK and sends the appropriate token (Firebase or APNs).
  Future<void> initializeAndSendToken() async {
    debugPrint("Started Load");
    setupMethodChannelHandler();
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('user_id') ?? '';
    debugPrint("Saved User ID");
    debugPrint(userId);
    if(!userId.isEmpty && userId != ""){
      sendEvent("app_open", {"channel_id": channelId});
    }else{
      try {
        FirebaseMessaging messaging = FirebaseMessaging.instance;

        // Request notification permissions (necessary for iOS)
        await messaging.requestPermission();

        if (Platform.isAndroid) {
          // Get Firebase token for Android
          String? firebaseToken = await messaging.getToken();
          debugPrint(firebaseToken);
          if (firebaseToken != null) {
            await sendTokenToServer('android', firebaseToken);
          } else {
            throw Exception("Failed to retrieve Firebase token on Android.");
          }
        } else if (Platform.isIOS) {
          // Get APNs token for iOS
          String? apnsToken = await messaging.getAPNSToken();
          debugPrint("APNS TOKEN "+apnsToken!);
          if (apnsToken != null) {
            await sendTokenToServer('ios', apnsToken);
          } else {
            throw Exception("Failed to retrieve APNs token on iOS.");
          }
        } else {
          throw UnsupportedError("Unsupported platform.");
        }
      } catch (e) {
        debugPrint("Error initializing FirebaseTokenSender: $e");
      }
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
        Uri.parse('$serverUrl/pushapp/api/v2/notification/track?t='+token+'&eventType=opened'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        debugPrint('Notification event tracked successfully.');
      } else {
        debugPrint('Failed to track event: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Error tracking notification event: $e');
    }
  }


  /// Sends the token (APNs or Firebase) to the server.
  Future<void> sendTokenToServer(String tokenType, String token) async {
    try {
      debugPrint('Server URL : '+'$serverUrl/pushapp/api/register');
      var device_id = await getDeviceId();
      final deviceHeaders = await getDeviceHeaders();
      debugPrint("ServerDeviceID");
      debugPrint(device_id);
      final response = await http.post(
        Uri.parse('$serverUrl/pushapp/api/register'),
        headers: {
          'Content-Type': 'application/json',
          ...deviceHeaders,
        },
        body: jsonEncode({
          'platform': tokenType, // 'firebase' or 'apns'
          'token': token,
          'device_id' : device_id,
          'channel_id': channelId
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint(response.body);
        if (responseData['device']['user_id'] != null) {
          this.guestId = responseData['device']['user_id'].toString();
        }
        debugPrint("guest_id");
        debugPrint(guestId);
        this.sendEvent("app_open", {});
        debugPrint("Token sent successfully!");
      } else {
        throw Exception("Failed to send token: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error sending token to server: $e");
    }
  }


  /// Sends the token (APNs or Firebase) to the server.
  Future<void> login(String userId) async {
    try {
      this.userId = userId;
      var device_id = await getDeviceId();
      final deviceHeaders = await getDeviceHeaders();
      debugPrint("LoginDeviceID");
      debugPrint(device_id);
      final response = await http.post(
        Uri.parse('$serverUrl/pushapp/api/register/user'),
        headers: {
          'Content-Type': 'application/json',
          ...deviceHeaders,
        },
        body: jsonEncode({
          'user_id': userId,
          'device_id' : device_id,
          'channel_id': channelId
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("User registered successfully!");
        _setupSocket(userId);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', userId);
      } else {
        throw Exception("Failed to register user: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error registering user: $e");
    }
  }

  void setInAppNotification(BuildContext context){
    if (context is Element && context.mounted) {
      buildContext = context;
      debugPrint("In-app context set!");
    } else {
      debugPrint("Context not mounted yet");
    }
    this.buildContext = context;
  }


  void _setupSocket(String userId) {
    debugPrint("SocketStarted : $userId");
    _socketService.connect(userId,tenant,channelId,sandbox);

    _socketService.notificationStream.listen((notification) {
      debugPrint("Received notification: $notification");

      final data = notification['data'];

      // ✅ CHECK FOR RULE-TRIGGERED MESSAGE FIRST
      final messageType = data['message_type'];
      if (messageType == 'rule_triggered') {
        debugPrint("RULE_TRIGGERED: Processing rule-based notification");
        final ruleId = data['rule_id'];
        debugPrint("Rule ID: $ruleId");

        // Call the poll endpoint to get actual notification data
        _pollForNotificationData(ruleId);
        return; // Exit early, don't process as regular notification
      }

      // ✅ PROCESS DIRECT NOTIFICATIONS (existing logic)
      _processNotificationData(data);
    });
  }

  Future<void> _pollForNotificationData(String ruleId) async {
    try {
      debugPrint("Polling for notification data with rule ID: $ruleId");

      // Make HTTP request to poll endpoint
      final response = await http.post(
        Uri.parse('$serverUrl/pushapp/api/poll/in-app'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'rule_id': ruleId,
        }),
      );

      debugPrint("Poll response status: ${response.statusCode}");
      debugPrint("Poll response body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint("Poll response data: $responseData");

        if (responseData['success'] == true) {
          final notificationData = responseData['data'];
          debugPrint("Received notification data: $notificationData");

          // Process the notification data using existing logic
          _processNotificationData(notificationData);
        } else {
          debugPrint("Poll failed: ${responseData['message']}");
        }
      } else {
        debugPrint("Poll request failed with status: ${response.statusCode}");
        debugPrint("Response body: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error polling for notification data: $e");
    }
  }

// ✅ NEW: Method to process notification data (extracted from existing logic)
  void _processNotificationData(Map<String, dynamic> data) {
    final type = data['type'];
    final template = data['template'];
    final contentList = template?['data']?['content'] ?? [];
    final style = data['style'] ?? {};

    debugPrint("Processing notification data - Type: $type");

    if (type == 'popup') {
      debugPrint("POPUP");
      if (contentList.isNotEmpty && buildContext != null) {
        _showPopupRoadblock(contentList, buildContext!);
      }
    }

    // ✅ Banner Handler
    if (type == 'popout-banner') {
      debugPrint("BANNER");
      final align = (style['align'] ?? 'top').toString();
      if (contentList.isNotEmpty && buildContext != null) {
        _showBanner(contentList, buildContext!, align: align);
      }
    }

    if (type == 'popout-pip') {
      final align = (style['align'] ?? 'bottom-right').toString();
      if (contentList.isNotEmpty && buildContext != null) {
        _showPip(contentList, buildContext!, align: align);
      }
    }
  }


  void _showPip(List<dynamic> contentList, BuildContext context, {String align = "bottom-right"}) {
    if (contentList.isEmpty || contentList.first is! String) return;

    final htmlContent = contentList.first as String;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(htmlContent);

    final alignment = {
      'top-left': Alignment.topLeft,
      'top-right': Alignment.topRight,
      'bottom-left': Alignment.bottomLeft,
      'bottom-right': Alignment.bottomRight,
    }[align] ?? Alignment.bottomRight;

    // ✅ Show dialog directly
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
                boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black26)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    WebViewWidget(controller: controller),
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
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  void _showBanner(List<dynamic> contentList, BuildContext context, {String align = "top"}) {
    if (contentList.isEmpty || contentList.first is! String) {
      debugPrint("No banner HTML found.");
      return;
    }

    final htmlContent = (contentList.first as String).replaceAll('[[ALIGN]]', align == 'bottom' ? 'banner-bottom' : 'banner-top');

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(htmlContent);

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
        } else if (item.startsWith('http') && (item.endsWith('.png') || item.endsWith('.jpg') || item.endsWith('.jpeg') || item.endsWith('.gif') || item.endsWith('.webp'))) {
          imageUrl = item;
          break;
        }
      }
    }

    if (htmlContent.isEmpty && imageUrl.isEmpty) {
      debugPrint("No valid content (HTML or image) found.");
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
        errorBuilder: (context, error, stackTrace) => const Center(child: Text("Failed to load image")),
      );
    }

    // Show dialog with the appropriate content
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Scaffold(
          backgroundColor: Colors.black.withOpacity(0.8),
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
                  top: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.close, color: Colors.white, size: 30),
                      onPressed: () => Navigator.of(context).pop(),
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




  Future<void> sendEvent(String eventName, Map<String, dynamic> eventData) async {

    var _userId = this.guestId;
    if(this.userId != null && userId != ""){
      _userId = this.userId;
    }

    try {
      final deviceHeaders = await getDeviceHeaders();
      debugPrint(jsonEncode({
        'user_id': _userId,
        'channel_id': channelId,
        'event_name': eventName,
        'event_data': eventData,
      }));
      final response = await http.post(
        Uri.parse('$serverUrl/pushapp/api/events'),
        headers: {
          'Content-Type': 'application/json',
          ...deviceHeaders,
        },
        body: jsonEncode({
          'user_id': _userId,
          'channel_id': channelId,
          'event_name': eventName,
          'event_data': eventData,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("Event sent successfully!");
      } else {
        throw Exception("Failed to send event: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error sending event: $e");
    }
  }


  /// Sends the token (APNs or Firebase) to the server.
  Future<void> logout(String userId) async {
    try {
      var device_id = await getDeviceId();
      final deviceHeaders = await getDeviceHeaders();
      final response = await http.post(
        Uri.parse('$serverUrl/pushapp/api/logout'),
        headers: {
          'Content-Type': 'application/json',
          ...deviceHeaders,
        },
        body: jsonEncode({
          'user_id': userId,
          'device_id' : device_id
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("User logged out successfully!");
      } else {
        throw Exception("Failed to log out user: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error logging out user: $e");
    }
  }

  Future<String?> getDeviceId() async {
    return await AppSetId().getIdentifier();
  }


  static Future<Map<String, String>> getDeviceHeaders() async {
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
      headers.addAll({
        'X-Device-Model': androidInfo.model,
        'X-OS-Name': 'ANDROID',
        'X-OS-Version': androidInfo.version.release,
        'X-Manufacturer': androidInfo.manufacturer,
        'X-API-Level': androidInfo.version.sdkInt.toString(),
        'X-Boot-Time': androidInfo.bootloader,
        'X-CPU-ABI': androidInfo.supportedAbis.join(', '),
      });

    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfoPlugin.iosInfo;
      headers.addAll({
        'X-Device-Model': iosInfo.model,
        'X-OS-Name': 'IOS',
        'X-OS-Version': iosInfo.systemVersion,
        'X-System-Name': iosInfo.systemName,
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
  String? _channelId;
  bool _sandbox = false;

  // Stream controller for notifications
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;

  // Connect to WebSocket
  void connect(String userId,String tenant,String channelId,bool sandbox) {
    _userId = userId;
    _tenant = tenant;
    _channelId = channelId;
    _sandbox = sandbox;
    _connectToSocket();
  }

  void _connectToSocket() {
    try {
      // Replace with your actual WebSocket URL
      final wsUrl = 'wss://$_tenant.mehery.${_sandbox ? "xyz" : "com"}/pushapp';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Send authentication message
      _sendAuthMessage();

      // Listen for messages
      _channel!.stream.listen(
            (message) {
          _handleMessage(message);
        },
        onError: (error) {
          debugPrint('Socket error: $error');
          _handleDisconnection();
        },
        onDone: () {
          debugPrint('Socket connection closed');
          _handleDisconnection();
        },
      );

      _isConnected = true;
    } catch (e) {
      debugPrint('Error connecting to socket: $e');
      _handleDisconnection();
    }
  }

  void _sendAuthMessage() {
    if (_channel != null && _userId != null) {
      final authMessage = {
        'type': 'auth',
        'userId': _userId,
      };
      _channel!.sink.add(jsonEncode(authMessage));
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      if (data is Map<String, dynamic>) {
        switch (data['type']) {
          case 'auth':
            if (data['status'] == 'success') {
              debugPrint('Socket authenticated successfully');
            } else {
              debugPrint('Socket authentication failed: ${data['message']}');
            }
            break;
          case 'in_app':
            _notificationController.add(data);
            break;
          case 'error':
            debugPrint('Socket error: ${data['message']}');
            break;
        }
      }
    } catch (e) {
      debugPrint('Error handling message: $e');
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


class MeSendRouteObserver extends NavigatorObserver {
  static final MeSendRouteObserver _instance = MeSendRouteObserver._internal();
  factory MeSendRouteObserver() => _instance;
  MeSendRouteObserver._internal();

  MeSend? _meSend;

  void attachSDK(MeSend sdkInstance) {
    _meSend = sdkInstance;
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    if(_meSend != null) {
      final pageName = route.settings.name ?? route.toString();
      if (previousRoute != null) {
        final previousPageName = previousRoute!.settings.name ??
            previousRoute!.toString();
        _meSend!.sendEvent("page_closed", {"page": previousPageName});
      }
      debugPrint("SDK: Page Opened -> $pageName");
      _meSend!.sendEvent("page_open", {"page": pageName});
    }

    // Send this info to analytics/logging server if needed
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if(_meSend != null) {
      final pageName = route.settings.name ?? route.toString();
      debugPrint("SDK: Page Closed -> $pageName");
      _meSend!.sendEvent("page_closed", {"page": pageName});
    }
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if(_meSend != null) {
      if (newRoute != null) {
        final pageName = newRoute!.settings.name ?? newRoute!.toString();
        debugPrint("SDK: Page Replaced -> $pageName");
        _meSend!.sendEvent("page_open", {"page": pageName});
      }
      if (oldRoute != null) {
        final previousPageName = oldRoute!.settings.name ??
            oldRoute!.toString();
        _meSend!.sendEvent("page_closed", {"page": previousPageName});
      }


    }
  }
}

