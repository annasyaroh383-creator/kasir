import 'package:flutter/material.dart';

class PrinterSetupPage extends StatefulWidget {
  const PrinterSetupPage({super.key});

  @override
  State<PrinterSetupPage> createState() => _PrinterSetupPageState();
}

class _PrinterSetupPageState extends State<PrinterSetupPage> {
  bool _isScanning = false;
  String? _connectedPrinter;
  final List<String> _availablePrinters = [
    'Thermal Printer BT-001',
    'POS Printer XP-200',
    'Receipt Printer RPT-45',
  ];

  Future<void> _scanPrinters() async {
    setState(() => _isScanning = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _isScanning = false);
  }

  void _connectPrinter(String printerName) {
    setState(() => _connectedPrinter = printerName);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Terhubung ke $printerName')));
  }

  void _disconnectPrinter() {
    setState(() => _connectedPrinter = null);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Printer terputus')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup Printer')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _connectedPrinter != null
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color: _connectedPrinter != null
                          ? Colors.green
                          : Colors.red,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _connectedPrinter != null
                                ? 'Terhubung'
                                : 'Tidak Terhubung',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _connectedPrinter ??
                                'Tidak ada printer yang terhubung',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Scan Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isScanning ? null : _scanPrinters,
                icon: _isScanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bluetooth_searching),
                label: Text(
                  _isScanning ? 'Mencari Printer...' : 'Cari Printer Bluetooth',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Available Printers
            const Text(
              'Printer Tersedia',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: _availablePrinters.isEmpty
                  ? const Center(child: Text('Tidak ada printer ditemukan'))
                  : ListView.builder(
                      itemCount: _availablePrinters.length,
                      itemBuilder: (context, index) {
                        final printer = _availablePrinters[index];
                        final isConnected = _connectedPrinter == printer;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.print),
                            title: Text(printer),
                            subtitle: Text(
                              isConnected ? 'Terhubung' : 'Tersedia',
                            ),
                            trailing: isConnected
                                ? ElevatedButton(
                                    onPressed: _disconnectPrinter,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Putus'),
                                  )
                                : ElevatedButton(
                                    onPressed: () => _connectPrinter(printer),
                                    child: const Text('Hubungkan'),
                                  ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 16),

            // Test Print Button
            if (_connectedPrinter != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Test print berhasil dikirim'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.print),
                  label: const Text('Test Print'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
