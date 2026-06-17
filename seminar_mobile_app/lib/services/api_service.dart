import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/models.dart';
import 'export_downloader.dart';

class ApiService {
  static const String _tokenKey = 'jwt_access_token';
  static const String _refreshKey = 'jwt_refresh_token';

  // Get headers, optionally including authorization if token exists
  Future<Map<String, String>> _getHeaders({bool authRequired = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (authRequired) {
      final token = await getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // Token Management
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, access);
    await prefs.setString(_refreshKey, refresh);
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshKey);
  }

  Future<bool> hasToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // 1. Authentication Endpoints
  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    String? firstName,
    String? lastName,
  }) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}auth/register/');
    final body = jsonEncode({
      'username': username,
      'email': email,
      'password': password,
      'password2': passwordConfirm,
      'first_name': firstName ?? '',
      'last_name': lastName ?? '',
    });

    final response = await http.post(
      url,
      headers: await _getHeaders(authRequired: false),
      body: body,
    );

    if (response.statusCode == 201) {
      return true;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? error.toString());
    }
  }

  Future<bool> login(String username, String password) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}auth/token/');
    final body = jsonEncode({'username': username, 'password': password});

    final response = await http.post(
      url,
      headers: await _getHeaders(authRequired: false),
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await saveTokens(data['access'], data['refresh']);
      return true;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(
        error['detail'] ?? 'Login failed. Invalid username or password.',
      );
    }
  }

  Future<User> getProfile() async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}auth/profile/');
    final response = await http.get(url, headers: await _getHeaders());

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load profile.');
    }
  }

  Future<User> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
  }) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}auth/profile/');
    final body = {};
    if (firstName != null) body['first_name'] = firstName;
    if (lastName != null) body['last_name'] = lastName;
    if (email != null) body['email'] = email;

    final response = await http.put(
      url,
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to update profile.');
    }
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}auth/change-password/');
    final body = jsonEncode({
      'old_password': oldPassword,
      'new_password': newPassword,
    });

    final response = await http.put(
      url,
      headers: await _getHeaders(),
      body: body,
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? error.toString());
    }
  }

  // Helper: parse error response dari backend jadi pesan yang bersih
  String _parseErrorMessage(dynamic responseBody) {
    try {
      final Map<String, dynamic> error = responseBody is String
          ? jsonDecode(responseBody)
          : responseBody;

      // Kalau ada field 'detail', langsung pakai
      if (error.containsKey('detail')) {
        return error['detail'].toString();
      }

      // Kumpulkan semua pesan error dari field-field lain
      final messages = <String>[];
      error.forEach((key, value) {
        String fieldName = _friendlyFieldName(key);
        if (value is List) {
          messages.add('$fieldName: ${value.join(', ')}');
        } else {
          messages.add('$fieldName: $value');
        }
      });

      return messages.isNotEmpty ? messages.join('\n') : 'Terjadi kesalahan.';
    } catch (_) {
      return 'Terjadi kesalahan. Silakan coba lagi.';
    }
  }

  String _friendlyFieldName(String key) {
    const map = {
      'title': 'Judul',
      'speaker': 'Speaker',
      'description': 'Deskripsi',
      'category': 'Kategori',
      'date': 'Tanggal',
      'time': 'Waktu',
      'location_url': 'Link Lokasi',
      'is_online': 'Tipe Seminar',
      'max_participants': 'Maks. Peserta',
      'quota': 'Kuota',
      'name': 'Nama',
      'username': 'Username',
      'email': 'Email',
      'password': 'Password',
      'non_field_errors': 'Error',
    };
    return map[key] ?? key;
  }

  // Helper: parse list dari response yang mungkin paginated atau plain array
  List<dynamic> _parseList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map && decoded.containsKey('results')) {
      return decoded['results'] as List;
    }
    return [];
  }

  /// Helper: buat MultipartFile yang kompatibel Web & Mobile
  /// Di Web, pakai fromBytes. Di Mobile, pakai fromPath.
  Future<http.MultipartFile> _buildMultipartFile(
    String field,
    String path,
  ) async {
    if (kIsWeb) {
      // Di web, path adalah object URL — baca bytes via XFile
      // Fallback: baca bytes dari network URL
      final uri = Uri.parse(path);
      final bytes = await http.readBytes(uri);
      final filename = path.split('/').last.split('?').first;
      return http.MultipartFile.fromBytes(field, bytes, filename: filename);
    }
    return http.MultipartFile.fromPath(field, path);
  }

  // 2. Seminar & Category Endpoints
  Future<List<Category>> getCategories() async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}categories/');
    final response = await http.get(url, headers: await _getHeaders());

    if (response.statusCode == 200) {
      final data = _parseList(jsonDecode(response.body));
      return data.map((c) => Category.fromJson(c)).toList();
    } else {
      throw Exception('Failed to load categories.');
    }
  }

  Future<List<Seminar>> getSeminars({
    String? search,
    int? categoryId,
    bool? isOnline,
  }) async {
    var queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (categoryId != null) queryParams['category'] = categoryId.toString();
    if (isOnline != null) queryParams['is_online'] = isOnline.toString();

    final uri = Uri.parse(
      '${AppConstants.apiBaseUrl}seminars/',
    ).replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      final data = _parseList(jsonDecode(response.body));
      return data.map((s) => Seminar.fromJson(s)).toList();
    } else {
      throw Exception('Failed to load seminars.');
    }
  }

  Future<Seminar> getSeminarDetail(int id) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}seminars/$id/');
    final response = await http.get(url, headers: await _getHeaders());

    if (response.statusCode == 200) {
      try {
        return Seminar.fromJson(jsonDecode(response.body));
      } catch (e) {
        throw Exception('Gagal memproses data seminar: $e');
      }
    } else {
      throw Exception(_parseErrorMessage(jsonDecode(response.body)));
    }
  }

  Future<Seminar> createSeminar(
    Map<String, dynamic> data, {
    File? bannerFile,
    XFile? bannerXFile,
  }) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}seminars/');
    final token = await getAccessToken();

    final request = http.MultipartRequest('POST', url);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    // Tambah field teks
    data.forEach((key, value) {
      if (value != null) request.fields[key] = value.toString();
    });

    // Tambah banner — support Web (XFile) dan Mobile (File)
    if (kIsWeb && bannerXFile != null) {
      final bytes = await bannerXFile.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'banner',
          bytes,
          filename: bannerXFile.name,
        ),
      );
    } else if (!kIsWeb && bannerFile != null) {
      final file = await _buildMultipartFile('banner', bannerFile.path);
      request.files.add(file);
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 201) {
      return Seminar.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_parseErrorMessage(jsonDecode(response.body)));
    }
  }

  Future<Seminar> updateSeminar(
    int id,
    Map<String, dynamic> data, {
    File? bannerFile,
    XFile? bannerXFile,
  }) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}seminars/$id/');
    final token = await getAccessToken();

    final request = http.MultipartRequest('PATCH', url);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    // Tambah field teks
    data.forEach((key, value) {
      if (value != null) request.fields[key] = value.toString();
    });

    // Tambah banner — support Web (XFile) dan Mobile (File)
    if (kIsWeb && bannerXFile != null) {
      final bytes = await bannerXFile.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'banner',
          bytes,
          filename: bannerXFile.name,
        ),
      );
    } else if (!kIsWeb && bannerFile != null) {
      final file = await _buildMultipartFile('banner', bannerFile.path);
      request.files.add(file);
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      return Seminar.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_parseErrorMessage(jsonDecode(response.body)));
    }
  }

  Future<void> deleteSeminar(int id) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}seminars/$id/');
    final response = await http.delete(url, headers: await _getHeaders());

    if (response.statusCode != 204) {
      throw Exception(_parseErrorMessage(jsonDecode(response.body)));
    }
  }

  // Category CRUD
  Future<Category> createCategory(Map<String, dynamic> data) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}categories/');
    final response = await http.post(
      url,
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );

    if (response.statusCode == 201) {
      return Category.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_parseErrorMessage(jsonDecode(response.body)));
    }
  }

  Future<Category> updateCategory(int id, Map<String, dynamic> data) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}categories/$id/');
    final response = await http.patch(
      url,
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return Category.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_parseErrorMessage(jsonDecode(response.body)));
    }
  }

  Future<void> deleteCategory(int id) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}categories/$id/');
    final response = await http.delete(url, headers: await _getHeaders());

    if (response.statusCode != 204) {
      throw Exception(_parseErrorMessage(jsonDecode(response.body)));
    }
  }

  // Admin — monitor semua order
  Future<List<Order>> getAdminOrders({String? status}) async {
    var queryParams = <String, String>{};
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    final uri = Uri.parse(
      '${AppConstants.apiBaseUrl}admin/orders/',
    ).replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      final data = _parseList(jsonDecode(response.body));
      return data.map((o) => Order.fromJson(o)).toList();
    } else {
      throw Exception(_parseErrorMessage(jsonDecode(response.body)));
    }
  }

  Future<Order> adminConfirmPayment(int paymentId, String status) async {
    final url = Uri.parse(
      '${AppConstants.apiBaseUrl}admin/payments/$paymentId/confirm/',
    );
    final response = await http.patch(
      url,
      headers: await _getHeaders(),
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_parseErrorMessage(jsonDecode(response.body)));
    }
  }

  Future<AdminChartSummary> getAdminChartSummary() async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}charts/summary/');
    final response = await http.get(url, headers: await _getHeaders());

    if (response.statusCode == 200) {
      return AdminChartSummary.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_parseErrorMessage(jsonDecode(response.body)));
    }
  }

  String get exportOrdersPdfUrl =>
      '${AppConstants.apiBaseUrl}exports/orders/pdf/';

  String get exportOrdersXlsxUrl =>
      '${AppConstants.apiBaseUrl}exports/orders/xlsx/';

  Future<String?> downloadOrdersExport(String format) async {
    final normalized = format.toLowerCase();
    final isPdf = normalized == 'pdf';
    final url = Uri.parse(isPdf ? exportOrdersPdfUrl : exportOrdersXlsxUrl);
    final headers = await _getHeaders();

    // Remove content negotiation headers for file downloads.
    headers.remove('Accept');
    headers.remove('Content-Type');

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final filename =
          _filenameFromContentDisposition(
            response.headers['content-disposition'],
          ) ??
          'laporan_pesanan.${isPdf ? 'pdf' : 'xlsx'}';

      return saveExportFile(
        bytes: response.bodyBytes,
        filename: filename,
        mimeType: response.headers['content-type'] ??
            (isPdf ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
      );
    }

    throw Exception(_parseErrorMessage(response.body));
  }

  String? _filenameFromContentDisposition(String? value) {
    if (value == null || value.isEmpty) return null;
    final match = RegExp(
      r'''filename\*?=(?:UTF-8'')?"?([^";]+)"?''',
      caseSensitive: false,
    ).firstMatch(value);
    return match?.group(1);
  }

  Future<List<Ticket>> getTicketsBySeminar(int seminarId) async {
    final uri = Uri.parse(
      '${AppConstants.apiBaseUrl}tickets/',
    ).replace(queryParameters: {'seminar': seminarId.toString()});
    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      final data = _parseList(jsonDecode(response.body));
      return data.map((t) => Ticket.fromJson(t)).toList();
    } else {
      throw Exception('Gagal memuat tiket.');
    }
  }

  Future<Ticket> createTicket(Map<String, dynamic> data) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}tickets/');
    final response = await http.post(
      url,
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );

    if (response.statusCode == 201) {
      return Ticket.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_parseErrorMessage(jsonDecode(response.body)));
    }
  }

  Future<Ticket> updateTicket(int id, Map<String, dynamic> data) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}tickets/$id/');
    final response = await http.patch(
      url,
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return Ticket.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_parseErrorMessage(jsonDecode(response.body)));
    }
  }

  Future<void> deleteTicket(int id) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}tickets/$id/');
    final response = await http.delete(url, headers: await _getHeaders());

    if (response.statusCode != 204) {
      throw Exception(_parseErrorMessage(jsonDecode(response.body)));
    }
  }

  // 3. Order Endpoints
  Future<List<Order>> getOrders({String? status}) async {
    var queryParams = <String, String>{};
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    final uri = Uri.parse(
      '${AppConstants.apiBaseUrl}orders/',
    ).replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      final data = _parseList(jsonDecode(response.body));
      return data.map((o) => Order.fromJson(o)).toList();
    } else {
      throw Exception('Failed to load orders.');
    }
  }

  Future<Order> getOrderDetail(int id) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}orders/$id/');
    final response = await http.get(url, headers: await _getHeaders());

    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load order details.');
    }
  }

  Future<Order> createOrder({
    required int ticketId,
    required int quantity,
    required String paymentMethod,
  }) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}orders/');
    final body = jsonEncode({
      'ticket': ticketId,
      'quantity': quantity,
      'payment_method': paymentMethod,
    });

    final response = await http.post(
      url,
      headers: await _getHeaders(),
      body: body,
    );

    if (response.statusCode == 201) {
      return Order.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_parseErrorMessage(jsonDecode(response.body)));
    }
  }

  Future<Order> cancelOrder(int orderId) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}orders/$orderId/cancel/');
    final response = await http.post(
      url,
      headers: await _getHeaders(),
      body: jsonEncode({}),
    );

    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_parseErrorMessage(jsonDecode(response.body)));
    }
  }

  // 4. Payment — upload bukti pembayaran (Web & Mobile compatible)
  Future<Payment> uploadPaymentProof({
    required int paymentId,
    required String imagePath,
    List<int>? imageBytes,
    String? filename,
  }) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}payments/$paymentId/');
    final token = await getAccessToken();

    final request = http.MultipartRequest('PATCH', url);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    if (kIsWeb && imageBytes != null) {
      // Web: pakai bytes langsung
      request.files.add(
        http.MultipartFile.fromBytes(
          'proof_image',
          imageBytes,
          filename: filename ?? 'proof.jpg',
        ),
      );
    } else {
      // Mobile: pakai fromPath
      final file = await http.MultipartFile.fromPath('proof_image', imagePath);
      request.files.add(file);
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return Payment.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_parseErrorMessage(jsonDecode(response.body)));
    }
  }
}
