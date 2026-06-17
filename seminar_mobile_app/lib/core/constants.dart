import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConstants {
  static const String appName = 'Seminar Booking';

  static String get apiBaseUrl {
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          return 'http://15.15.6.228:8000/api/';
        }
      } catch (_) {}
    }
    return 'http://127.0.0.1:8000/api/';
  }

  static String get mediaUrl {
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          return 'http://15.15.6.228:8000';
        }
      } catch (_) {}
    }
    return 'http://127.0.0.1:8000';
  }

  /// Buat full URL untuk file media dari Django.
  /// Django menyimpan path seperti: "seminars/banners/foto.jpg"
  /// atau "/media/seminars/banners/foto.jpg"
  static String? buildMediaUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    // Kalau sudah full URL, langsung kembalikan
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    // Kalau sudah ada /media/ di depan
    if (path.startsWith('/media/')) return '$mediaUrl$path';
    // Kalau belum ada /media/
    return '$mediaUrl/media/$path';
  }

  /// Format waktu HH:MM dari string HH:MM:SS atau HH:MM
  static String formatTimeShort(String time) {
    if (time.length >= 5) return time.substring(0, 5);
    return time;
  }
}
