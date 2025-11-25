import 'package:flutter/material.dart';
import 'package:kasir/services/printer_service.dart';

class PrinterSetupPage extends StatefulWidget {
  const PrinterSetupPage({super.key});

  @override
  State<PrinterSetupPage> createState() => _PrinterSetupPageState();
}

class _PrinterSetupPageState extends State<PrinterSetupPage> {
  final PrinterService _printerService = PrinterService();
  bool _isScanning = false;
  List<Map<String, dynamic>> _availablePrinters = [];

  Future<void> _scanPrinters() async {
    setState(() => _isScanning = true);
    try {
      _availablePrinters = await _printerService.getAvailableDevices();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error scanning printers: $e')));
    }
    setState(() => _isScanning = false);
  }

  Future<void> _checkConnectionStatus() async {
    try {
      bool isConnected = await _printerService.checkPrinterConnection();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isConnected
                ? 'Printer terhubung dan siap digunakan'
                : 'Printer tidak terhubung',
          ),
          backgroundColor: isConnected ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error checking connection: $e')));
    }
  }

  Future<void> _connectPrinter(String address) async {
    try {
      final success = await _printerService.connectToDevice(address);
      if (success) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Terhubung ke ${_printerService.connectedDeviceName}',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal terhubung ke printer')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error connecting: $e')));
    }
  }

  Future<void> _disconnectPrinter() async {
    await _printerService.disconnect();
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Printer terputus')));
  }

  Future<void> _testPrint() async {
    final success = await _printerService.printTest();
    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Test print berhasil')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Test print gagal')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Printer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkConnectionStatus,
            tooltip: 'Periksa Status Koneksi',
          ),
        ],
      ),
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
                      _printerService.isConnected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color: _printerService.isConnected
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
                            _printerService.isConnected
                                ? 'Terhubung'
                                : 'Tidak Terhubung',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _printerService.connectedDeviceName ??
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
                  ? const Center(
                      child: Text('Tekan "Cari Printer" untuk mencari printer'),
                    )
                  : ListView.builder(
                      itemCount: _availablePrinters.length,
                      itemBuilder: (context, index) {
                        final printer = _availablePrinters[index];
                        final printerName = printer['name'] as String;
                        final printerAddress = printer['address'] as String;
                        final isConnected =
                            _printerService.isConnected &&
                            _printerService.connectedDeviceName ==
                                'Thermal Printer ($printerAddress)';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.print),
                            title: Text(printerName),
                            subtitle: Text(
                              isConnected
                                  ? 'Terhubung'
                                  : 'Tersedia - $printerAddress',
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
                                    onPressed: () =>
                                        _connectPrinter(printerAddress),
                                    child: const Text('Hubungkan'),
                                  ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 16),

            // Test Print Button
            if (_printerService.isConnected)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _testPrint,
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
