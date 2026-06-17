import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/seminar_provider.dart';
import '../core/constants.dart';
import '../models/models.dart';
import 'seminar_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildCategoryList(SeminarProvider seminarProvider) {
    final categories = seminarProvider.categories;
    final selectedId = seminarProvider.selectedCategoryId;

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final isSelected = isAll ? selectedId == null : selectedId == categories[index - 1].id;
          final label = isAll ? 'Semua' : categories[index - 1].name;
          final catId = isAll ? null : categories[index - 1].id;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              selectedColor: Colors.indigo,
              backgroundColor: Colors.grey[200],
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (selected) {
                if (isAll) {
                  // Chip "Semua" selalu reset ke null
                  seminarProvider.setCategoryFilter(null);
                } else {
                  // Klik chip yang sudah aktif → deselect (kembali ke "Semua")
                  // Klik chip baru → pilih kategori tersebut
                  seminarProvider.setCategoryFilter(isSelected ? null : catId);
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterRow(SeminarProvider provider) {
    return Row(
      children: [
        FilterChip(
          label: const Text('Online'),
          selected: provider.isOnlineFilter == true,
          onSelected: (val) {
            provider.setOnlineFilter(val ? true : null);
          },
          selectedColor: Colors.teal[100],
          checkmarkColor: Colors.teal[900],
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Offline'),
          selected: provider.isOnlineFilter == false,
          onSelected: (val) {
            provider.setOnlineFilter(val ? false : null);
          },
          selectedColor: Colors.teal[100],
          checkmarkColor: Colors.teal[900],
        ),
        const Spacer(),
        if (provider.selectedCategoryId != null || provider.isOnlineFilter != null || _searchController.text.isNotEmpty)
          TextButton(
            onPressed: () {
              _searchController.clear();
              provider.resetFilters();
            },
            child: const Text('Reset Filter'),
          )
      ],
    );
  }

  Widget _buildSeminarCard(Seminar seminar) {
    final imageUrl = AppConstants.buildMediaUrl(seminar.banner);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SeminarDetailScreen(seminarId: seminar.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildImagePlaceholder(seminar.title);
                      },
                    )
                  : _buildImagePlaceholder(seminar.title),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.indigo[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          seminar.categoryName ?? 'Kategori',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo[900],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        seminar.isOnline ? Icons.videocam : Icons.location_on,
                        size: 16,
                        color: Colors.teal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        seminar.isOnline ? 'Online' : 'Offline',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    seminar.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        seminar.date,
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(width: 14),
                      const Icon(Icons.access_time, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        AppConstants.formatTimeShort(seminar.time),
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                  if (seminar.speaker.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.record_voice_over,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Speaker: ${seminar.speaker}',
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Penyelenggara: ${seminar.organizerName}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(String title) {
    return Container(
      height: 150,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo, Colors.indigoAccent, Colors.teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final seminarProvider = Provider.of<SeminarProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Seminar Hub',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await seminarProvider.fetchCategories();
          await seminarProvider.fetchSeminars();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Greeting Section
              Text(
                'Halo, ${user?.fullName ?? "Pengguna"} 👋',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Temukan seminar menarik hari ini',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),

              // Search bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari seminar...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (val) {
                  seminarProvider.setSearchQuery(val);
                },
              ),
              const SizedBox(height: 16),

              // Categories filter
              const Text(
                'Kategori',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildCategoryList(seminarProvider),
              const SizedBox(height: 8),

              // Filter Row
              _buildFilterRow(seminarProvider),
              const SizedBox(height: 16),

              // Seminars List
              const Text(
                'Seminar Tersedia',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              seminarProvider.isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : seminarProvider.seminars.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48.0),
                            child: Column(
                              children: [
                                Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'Tidak ada seminar yang cocok.',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: seminarProvider.seminars.length,
                          itemBuilder: (context, index) {
                            return _buildSeminarCard(seminarProvider.seminars[index]);
                          },
                        ),
            ],
          ),
        ),
      ),
    );
  }
}
