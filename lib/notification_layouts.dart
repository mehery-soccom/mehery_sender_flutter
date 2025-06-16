import 'package:flutter/services.dart' show rootBundle;

class NotificationLayouts {
  static Future<String> getStandardLayout() async {
    return await rootBundle.loadString('lib/android/res/layout/standard_notification.xml');
  }

  static Future<String> getDeliveryLayout() async {
    return await rootBundle.loadString('lib/android/res/layout/delivery_notification.xml');
  }

  static Future<String> getScoreLayout() async {
    return await rootBundle.loadString('lib/android/res/layout/score_notification.xml');
  }
} 