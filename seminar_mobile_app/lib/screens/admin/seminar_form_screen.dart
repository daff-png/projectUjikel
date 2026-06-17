import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';
import '../../core/constants.dart';

class SeminarFormScreen extends StatefulWidget {
  final Seminar? seminar;
  const SeminarFormScreen({super.key, this.seminar});

  @override
  State<SeminarFormScreen> createState() => _SeminarFormScreenState();
}

class _SeminarFormScreenState extends State<SeminarFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  final _titleController = TextEditingController();
  final _speakerController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _maxParticipantsController = TextEditingController();

  List<Category> _categories = [];
  int? _selectedCategoryId;
  bool _isOnline = true;
  String _date = '';
  String _time = '';
  bool _isLoading = false;
  bool _isSaving = false;

  // Gunakan XFile agar kompatibel Web & Mobile
  XFile? _bannerXFile;
  // True jika user eksplisit hapus banner (tanpa ganti dengan yang baru)
  bool _bannerCleared = false;

  bool get isEdit => widget.seminar != null;
  bool get hasBanner => _bannerXFile != null;
  bool get hasServerBanner =>
      isEdit &&
      widget.seminar!.banner != null &&
      widget.seminar!.banner!.isNotEmpty;
  // Banner lama masih ada jika: edit mode, punya banner, belum dihapus, belum diganti
  bool get hasExistingBanner => hasServerBanner && !_bannerCleared && !hasBanner;
  bool get canRemoveBanner => hasBanner || hasServerBanner;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (isEdit) {
      final s = widget.seminar!;
      _titleController.text = s.title;
      _speakerController.text = s.speaker;
      _descController.text = s.description;
      _locationController.text = s.locationUrl;
      _maxParticipantsController.text = s.maxParticipants.toString();
      _isOnline = s.isOnline;
      _date = s.date;
      _time = s.time;
      _selectedCategoryId = s.categoryId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _speakerController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final cats = await _apiService.getCategories();
      setState(() => _categories = cats);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isNotEmpty ? DateTime.tryParse(_date) ?? now : now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _date =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time.isNotEmpty
          ? TimeOfDay(
              hour: int.parse(_time.split(':')[0]),
              minute: int.parse(_time.split(':')[1]),
            )
          : TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _time =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00';
      });
    }
  }

  void _removeBanner() {
    setState(() {
      _bannerXFile = null;
      _bannerCleared = true;
    });
  }

  Future<void> _pickBanner() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            // Kamera tidak tersedia di Web
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.indigo),
                title: const Text('Ambil dari Kamera'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked = await _picker.pickImage(
                      source: ImageSource.camera, imageQuality: 80);
                  if (picked != null) {
                    setState(() {
                      _bannerXFile = picked;
                      _bannerCleared = false;
                    });
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.indigo),
              title: const Text('Pilih dari Galeri'),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await _picker.pickImage(
                    source: ImageSource.gallery, imageQuality: 80);
                if (picked != null) {
                  setState(() {
                    _bannerXFile = picked;
                    _bannerCleared = false;
                  });
                }
              },
            ),
            if (canRemoveBanner)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Hapus Banner',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeBanner();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Widget gambar yang kompatibel Web & Mobile
  Widget _buildPickedImage() {
    if (kIsWeb) {
      // Di web, XFile.path adalah object URL blob
      return Image.network(
        _bannerXFile!.path,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => _bannerPlaceholder(),
      );
    }
    return Image.file(
      File(_bannerXFile!.path),
      fit: BoxFit.cover,
      width: double.infinity,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pilih tanggal seminar')));
      return;
    }
    if (_time.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pilih waktu seminar')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Siapkan file banner
      File? bannerFile;
      if (_bannerXFile != null && !kIsWeb) {
        bannerFile = File(_bannerXFile!.path);
      }

      final data = {
        'title': _titleController.text.trim(),
        'speaker': _speakerController.text.trim(),
        'description': _descController.text.trim(),
        'category': _selectedCategoryId,
        'date': _date,
        'time': _time,
        'location_url': _locationController.text.trim(),
        'is_online': _isOnline,
        'max_participants': int.tryParse(_maxParticipantsController.text) ?? 0,
        if (isEdit)
          'clear_banner': (_bannerCleared && !hasBanner) ? 'true' : 'false',
      };

      if (isEdit) {
        await _apiService.updateSeminar(
          widget.seminar!.id,
          data,
          bannerFile: bannerFile,
          bannerXFile: kIsWeb ? _bannerXFile : null,
        );
      } else {
        await _apiService.createSeminar(
          data,
          bannerFile: bannerFile,
          bannerXFile: kIsWeb ? _bannerXFile : null,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit
                ? 'Seminar berhasil diperbarui'
                : 'Seminar berhasil ditambahkan'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Seminar' : 'Tambah Seminar',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Simpan',
                  style: TextStyle(
                      color: Colors.indigo, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner Picker
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: _pickBanner,
                          child: Container(
                            height: 180,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: hasBanner
                                  ? _buildPickedImage()
                                  : hasExistingBanner
                                      ? Image.network(
                                          AppConstants.buildMediaUrl(
                                                  widget.seminar!.banner) ??
                                              '',
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          errorBuilder: (_, __, ___) =>
                                              _bannerPlaceholder(),
                                        )
                                      : _bannerPlaceholder(),
                            ),
                          ),
                        ),
                        if (canRemoveBanner)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Material(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: _removeBanner,
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.delete_outline,
                                      color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Judul
                    TextFormField(
                      controller: _titleController,
                      decoration: _inputDecoration('Judul Seminar', Icons.title),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Judul wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),

                    // Speaker
                    TextFormField(
                      controller: _speakerController,
                      decoration: _inputDecoration('Nama Speaker', Icons.record_voice_over),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Nama speaker wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),

                    // Deskripsi
                    TextFormField(
                      controller: _descController,
                      decoration:
                          _inputDecoration('Deskripsi', Icons.description),
                      maxLines: 4,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Deskripsi wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),

                    // Kategori
                    DropdownButtonFormField<int>(
                      value: _selectedCategoryId,
                      decoration: _inputDecoration('Kategori', Icons.category),
                      items: _categories
                          .map((c) => DropdownMenuItem(
                              value: c.id, child: Text(c.name)))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedCategoryId = val),
                      hint: const Text('Pilih Kategori'),
                    ),
                    const SizedBox(height: 16),

                    // Tanggal & Waktu
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                                _date.isEmpty ? 'Pilih Tanggal' : _date),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickTime,
                            icon: const Icon(Icons.access_time),
                            label: Text(_time.isEmpty
                                ? 'Pilih Waktu'
                                : AppConstants.formatTimeShort(_time)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Lokasi / URL
                    TextFormField(
                      controller: _locationController,
                      decoration: _inputDecoration(
                          _isOnline ? 'Link Meeting (URL)' : 'Alamat Lokasi',
                          Icons.link),
                    ),
                    const SizedBox(height: 16),

                    // Max Peserta
                    TextFormField(
                      controller: _maxParticipantsController,
                      decoration:
                          _inputDecoration('Maks. Peserta', Icons.people),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Wajib diisi';
                        if (int.tryParse(v) == null) return 'Harus angka';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Online / Offline toggle
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: SwitchListTile(
                        title: const Text('Seminar Online',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(_isOnline
                            ? 'Peserta bergabung secara online'
                            : 'Peserta hadir secara langsung'),
                        value: _isOnline,
                        activeColor: Colors.indigo,
                        onChanged: (val) => setState(() => _isOnline = val),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Tombol Simpan
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(
                                isEdit
                                    ? 'Perbarui Seminar'
                                    : 'Tambah Seminar',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _bannerPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined,
              size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text('Tap untuk pilih banner',
              style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }
}
