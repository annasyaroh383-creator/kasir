import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:kasir/providers/auth_provider.dart';
import 'package:kasir/services/auth_service.dart';
import 'package:kasir/services/printer_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';

class SalesReportsPage extends StatefulWidget {
  const SalesReportsPage({super.key});

  @override
  State<SalesReportsPage> createState() => _SalesReportsPageState();
}

class _SalesReportsPageState extends State<SalesReportsPage> {
  String _selectedPeriod = 'day';
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _reportData;
  bool _isLoading = false;

  final List<Map<String, String>> _periods = [
    {'value': 'day', 'label': 'Hari Ini'},
    {'value': 'week', 'label': 'Minggu Ini'},
    {'value': 'month', 'label': 'Bulan Ini'},
  ];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);

    try {
      final token = await AuthService.getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse(
          '${AuthService.baseUrl}/reports/sales?period=$_selectedPeriod&date=${_selectedDate.toIso8601String().split('T')[0]}',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() => _reportData = data['data']);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading report: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportPDF() async {
    if (_reportData == null) return;

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Laporan Penjualan SmartSISAPA',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Periode: ${_getPeriodLabel()}'),
              pw.Text(
                'Tanggal: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
              ),
              pw.SizedBox(height: 20),

              // Summary
              pw.Text(
                'Ringkasan',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      'Total Penjualan: Rp ${_reportData!['summary']['total_revenue']}',
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      'Jumlah Transaksi: ${_reportData!['summary']['total_sales']}',
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      'Item Terjual: ${_reportData!['summary']['total_items_sold']}',
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      'Rata-rata Transaksi: Rp ${_reportData!['summary']['average_sale'].toStringAsFixed(0)}',
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Top Products
              pw.Text(
                'Produk Terlaris',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Text(
                        'Produk',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Qty',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Pendapatan',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  ...(_reportData!['top_products'] as List).take(10).map((
                    product,
                  ) {
                    return pw.TableRow(
                      children: [
                        pw.Text(product['name']),
                        pw.Text(product['quantity'].toString()),
                        pw.Text('Rp ${product['revenue']}'),
                      ],
                    );
                  }),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Save and open PDF
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/laporan_penjualan.pdf');
    await file.writeAsBytes(await pdf.save());

    await OpenFile.open(file.path);
  }

  Future<void> _exportExcel() async {
    // TODO: Implement Excel export
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export Excel akan segera tersedia')),
    );
  }

  Future<void> _reprintReceipt(Map<String, dynamic> transaction) async {
    try {
      // Prepare receipt data for reprinting
      final receiptData = {
        'store_name': 'Smart Cashier',
        'store_address': 'Jl. Example No. 123\nJakarta, Indonesia',
        'invoice_id': transaction['invoice_code'] ?? 'N/A',
        'printed_at': DateTime.now().toString(),
        'customer_name': transaction['customer'] ?? 'Pelanggan Umum',
        'customer_phone': null, // Not available in transaction data
        'items': [], // Would need to fetch from API in real implementation
        'subtotal': transaction['total'] ?? 0,
        'tax_amount': 0, // Would need to calculate from API data
        'final_total': transaction['total'] ?? 0,
        'payment_method': transaction['payment_method'] ?? 'Cash',
        'paid_amount': transaction['total'] ?? 0,
      };

      // For demo purposes, add some sample items
      if (receiptData['items'].isEmpty) {
        receiptData['items'] = [
          {
            'name': 'Item Sample',
            'qty': 1,
            'unit_price': transaction['total'] ?? 0,
            'subtotal': transaction['total'] ?? 0,
          },
        ];
      }

      final printerService = PrinterService();
      final success = await printerService.printReceipt(receiptData);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Struk ${transaction['invoice_code']} berhasil dicetak ulang',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mencetak struk. Periksa koneksi printer.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error reprint: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getPeriodLabel() {
    return _periods.firstWhere((p) => p['value'] == _selectedPeriod)['label']!;
  }

  bool _canAccessReports() {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user == null) return false;

    final role = user['role'];
    return role == 'admin' ||
        role == 'supervisor' ||
        (role == 'cashier' && _selectedPeriod == 'day');
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    if (!_canAccessReports()) {
      return Scaffold(
        appBar: AppBar(title: const Text('Laporan Penjualan')),
        body: const Center(
          child: Text('Anda tidak memiliki akses ke laporan ini'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Penjualan'),
        actions: [
          if (_reportData != null) ...[
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _exportPDF,
              tooltip: 'Export PDF',
            ),
            IconButton(
              icon: const Icon(Icons.table_chart),
              onPressed: _exportExcel,
              tooltip: 'Export Excel',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reportData == null
          ? const Center(child: Text('Gagal memuat laporan'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filters
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Filter Periode',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedPeriod,
                                  decoration: const InputDecoration(
                                    labelText: 'Periode',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _periods.map((period) {
                                    return DropdownMenuItem(
                                      value: period['value'],
                                      child: Text(period['label']!),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() => _selectedPeriod = value!);
                                    _loadReport();
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _selectedDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null) {
                                      setState(() => _selectedDate = picked);
                                      _loadReport();
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Tanggal',
                                      border: OutlineInputBorder(),
                                    ),
                                    child: Text(
                                      DateFormat(
                                        'dd/MM/yyyy',
                                      ).format(_selectedDate),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Summary Cards
                  if (_reportData!['summary'] != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'Total Penjualan',
                            'Rp ${_reportData!['summary']['total_revenue']}',
                            Icons.attach_money,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSummaryCard(
                            'Jumlah Transaksi',
                            '${_reportData!['summary']['total_sales']}',
                            Icons.receipt,
                            Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'Item Terjual',
                            '${_reportData!['summary']['total_items_sold']}',
                            Icons.inventory,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSummaryCard(
                            'Rata-rata',
                            'Rp ${_reportData!['summary']['average_sale'].toStringAsFixed(0)}',
                            Icons.trending_up,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Chart
                  if (_reportData!['chart_data'] != null &&
                      (_reportData!['chart_data'] as List).isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Grafik Penjualan',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 300,
                              child: LineChart(
                                LineChartData(
                                  gridData: FlGridData(show: true),
                                  titlesData: FlTitlesData(
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(showTitles: true),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          final data =
                                              _reportData!['chart_data'][value
                                                  .toInt()];
                                          return Text(
                                            data?['period'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 10,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: true),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots:
                                          (_reportData!['chart_data'] as List)
                                              .asMap()
                                              .entries
                                              .map(
                                                (entry) => FlSpot(
                                                  entry.key.toDouble(),
                                                  entry.value['revenue']
                                                      .toDouble(),
                                                ),
                                              )
                                              .toList(),
                                      isCurved: true,
                                      color: Colors.blue,
                                      barWidth: 3,
                                      belowBarData: BarAreaData(show: false),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Top Products Table
                  if (_reportData!['top_products'] != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Produk Terlaris',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Produk')),
                                  DataColumn(label: Text('Qty')),
                                  DataColumn(label: Text('Pendapatan')),
                                ],
                                rows: (_reportData!['top_products'] as List)
                                    .take(10)
                                    .map(
                                      (product) => DataRow(
                                        cells: [
                                          DataCell(Text(product['name'])),
                                          DataCell(
                                            Text(
                                              product['quantity'].toString(),
                                            ),
                                          ),
                                          DataCell(
                                            Text('Rp ${product['revenue']}'),
                                          ),
                                        ],
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Recent Transactions
                  if (_reportData!['recent_transactions'] != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Transaksi Terbaru',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Invoice')),
                                  DataColumn(label: Text('Tanggal')),
                                  DataColumn(label: Text('Pelanggan')),
                                  DataColumn(label: Text('Total')),
                                  DataColumn(label: Text('Pembayaran')),
                                  DataColumn(label: Text('Aksi')),
                                ],
                                rows:
                                    (_reportData!['recent_transactions']
                                            as List)
                                        .take(20)
                                        .map(
                                          (transaction) => DataRow(
                                            cells: [
                                              DataCell(
                                                Text(
                                                  transaction['invoice_code'],
                                                ),
                                              ),
                                              DataCell(
                                                Text(transaction['date']),
                                              ),
                                              DataCell(
                                                Text(transaction['customer']),
                                              ),
                                              DataCell(
                                                Text(
                                                  'Rp ${transaction['total']}',
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  transaction['payment_method'],
                                                ),
                                              ),
                                              DataCell(
                                                IconButton(
                                                  icon: const Icon(Icons.print),
                                                  onPressed: () =>
                                                      _reprintReceipt(
                                                        transaction,
                                                      ),
                                                  tooltip: 'Cetak Ulang Struk',
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                        .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
