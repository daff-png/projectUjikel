import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class SeminarProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Category> _categories = [];
  List<Seminar> _seminars = [];
  Seminar? _selectedSeminar;
  bool _isLoading = false;
  String? _errorMessage;

  String _searchQuery = '';
  int? _selectedCategoryId;
  bool? _isOnlineFilter;

  List<Category> get categories => _categories;
  List<Seminar> get seminars => _seminars;
  Seminar? get selectedSeminar => _selectedSeminar;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get searchQuery => _searchQuery;
  int? get selectedCategoryId => _selectedCategoryId;
  bool? get isOnlineFilter => _isOnlineFilter;

  void setSearchQuery(String query) {
    _searchQuery = query;
    fetchSeminars();
  }

  void setCategoryFilter(int? categoryId) {
    _selectedCategoryId = categoryId;
    fetchSeminars();
  }

  void setOnlineFilter(bool? isOnline) {
    _isOnlineFilter = isOnline;
    fetchSeminars();
  }

  void resetFilters() {
    _searchQuery = '';
    _selectedCategoryId = null;
    _isOnlineFilter = null;
    fetchSeminars();
  }

  Future<void> fetchCategories() async {
    try {
      _categories = await _apiService.getCategories();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  Future<void> fetchSeminars() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _seminars = await _apiService.getSeminars(
        search: _searchQuery.isEmpty ? null : _searchQuery,
        categoryId: _selectedCategoryId,
        isOnline: _isOnlineFilter,
      );
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchSeminarDetail(int id) async {
    _isLoading = true;
    _selectedSeminar = null;
    _errorMessage = null;
    notifyListeners();

    try {
      _selectedSeminar = await _apiService.getSeminarDetail(id);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }}
