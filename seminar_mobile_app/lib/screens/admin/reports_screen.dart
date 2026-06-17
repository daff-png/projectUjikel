import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ApiService _apiService = ApiService();
  AdminChartSummary? _summary;
  bool _isLoading = false;
  String? _exportingFormat;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoading = true);
    try {
      final summary = await _apiService.getAdminChartSummary();
      if (mounted) setState(() => _summary = summary);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  String _formatMonth(String? value) {
    if (value == null || value.isEmpty) return 'Belum ada tanggal';
    try {
      final parsed = DateTime.parse(value).toLocal();
      return DateFormat('MMM yyyy', 'id_ID').format(parsed);
    } catch (_) {
      return value;
    }
  }

  Future<void> _downloadExport(String format) async {
    setState(() => _exportingFormat = format);
    try {
      final savedPath = await _apiService.downloadOrdersExport(format);
      if (!mounted) return;

      final message = savedPath == null
          ? 'File $format mulai diunduh'
          : 'File $format tersimpan di $savedPath';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingFormat = null);
    }
  }

  Widget _buildExportCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Export Pesanan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exportingFormat == null
                        ? () => _downloadExport('PDF')
                        : null,
                    icon: _exportingFormat == 'PDF'
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('PDF'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exportingFormat == null
                        ? () => _downloadExport('XLSX')
                        : null,
                    icon: _exportingFormat == 'XLSX'
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.table_chart, size: 18),
                    label: const Text('XLSX'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'File akan diunduh memakai akses admin yang sedang login.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarItem({
    required String title,
    required String value,
    required double ratio,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: ratio.clamp(0.0, 1.0),
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersPerSeminarChart(AdminChartSummary summary) {
    if (summary.ordersPerSeminar.isEmpty) {
      return Text('Belum ada data.', style: TextStyle(color: Colors.grey[600]));
    }

    final List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < summary.ordersPerSeminar.length; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: summary.ordersPerSeminar[i].totalOrders.toDouble(),
              color: Colors.indigo,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              width: 16,
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          barGroups: barGroups,
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              left: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey[200],
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= summary.ordersPerSeminar.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      summary.ordersPerSeminar[index].seminarTitle.length > 10
                          ? '${summary.ordersPerSeminar[index].seminarTitle.substring(0, 10)}...'
                          : summary.ordersPerSeminar[index].seminarTitle,
                      style: const TextStyle(fontSize: 10),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
                reservedSize: 40,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          alignment: BarChartAlignment.spaceAround,
          maxY: summary.ordersPerSeminar
              .fold<double>(0, (prev, item) => prev > item.totalOrders.toDouble() ? prev : item.totalOrders.toDouble())
              .ceilToDouble(),
        ),
      ),
    );
  }

  Widget _buildRevenuePerMonthChart(AdminChartSummary summary) {
    if (summary.revenuePerMonth.isEmpty) {
      return Text('Belum ada data.', style: TextStyle(color: Colors.grey[600]));
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < summary.revenuePerMonth.length; i++) {
      spots.add(FlSpot(i.toDouble(), summary.revenuePerMonth[i].totalRevenue / 1000000));
    }

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.green,
              barWidth: 2,
              belowBarData: BarAreaData(
                show: true,
                color: Colors.green.withValues(alpha: 0.3),
              ),
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barAreaData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.green,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
            ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= summary.revenuePerMonth.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _formatMonth(summary.revenuePerMonth[index].month),
                      style: const TextStyle(fontSize: 10),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
                reservedSize: 40,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    'Rp${value.toInt()}M',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey[200],
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              left: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots
                    .map((spot) => LineTooltipItem(
                          _formatCurrency(spot.y * 1000000),
                          const TextStyle(color: Colors.white),
                        ))
                    .toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDistributionChart(AdminChartSummary summary) {
    if (summary.categoryDistribution.isEmpty) {
      return Text('Belum ada data.', style: TextStyle(color: Colors.grey[600]));
    }

    final List<PieChartSectionData> sections = [];
    final colors = [
      Colors.teal,
      Colors.cyan,
      Colors.teal.shade300,
      Colors.teal.shade200,
      Colors.teal.shade400,
    ];

    for (int i = 0; i < summary.categoryDistribution.length; i++) {
      final item = summary.categoryDistribution[i];
      sections.add(
        PieChartSectionData(
          color: colors[i % colors.length],
          value: item.count.toDouble(),
          title: '${item.count}',
          radius: 80,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 250,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (int i = 0; i < summary.categoryDistribution.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors[i % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${summary.categoryDistribution[i].categoryName} (${summary.categoryDistribution[i].count})',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildContent(AdminChartSummary summary) {
    return RefreshIndicator(
      onRefresh: _loadSummary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildExportCard(),
          const SizedBox(height: 12),
          _buildSection(
            title: 'Pesanan per Seminar',
            icon: Icons.confirmation_number,
            color: Colors.indigo,
            child: _buildOrdersPerSeminarChart(summary),
          ),
          const SizedBox(height: 12),
          _buildSection(
            title: 'Pendapatan per Bulan',
            icon: Icons.payments,
            color: Colors.green,
            child: _buildRevenuePerMonthChart(summary),
          ),
          const SizedBox(height: 12),
          _buildSection(
            title: 'Distribusi Kategori',
            icon: Icons.pie_chart,
            color: Colors.teal,
            child: _buildCategoryDistributionChart(summary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Statistik & Export',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: _isLoading && _summary == null
          ? const Center(child: CircularProgressIndicator())
          : _summary == null
          ? Center(
              child: ElevatedButton.icon(
                onPressed: _loadSummary,
                icon: const Icon(Icons.refresh),
                label: const Text('Muat ulang'),
              ),
            )
          : _buildContent(_summary!),
    );
  }
}
