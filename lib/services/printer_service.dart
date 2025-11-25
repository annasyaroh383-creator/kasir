import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  BluetoothDevice? _selectedDevice;
  bool _isConnected = false;
  String? _connectedDeviceName;

  bool get isConnected => _isConnected;
  String? get connectedDeviceName => _connectedDeviceName;

  Future<void> init() async {
    // Initialize Bluetooth
    await bluetooth.isAvailable;
  }

  Future<List<Map<String, dynamic>>> getAvailableDevices() async {
    List<BluetoothDevice> devices = await bluetooth.getBondedDevices();
    return devices
        .map(
          (device) => {
            'name': device.name ?? 'Unknown Device',
            'address': device.address ?? '',
            'type': 'bluetooth',
          },
        )
        .toList();
  }

  Future<bool> connectToDevice(String address) async {
    List<BluetoothDevice> devices = await bluetooth.getBondedDevices();
    BluetoothDevice? device = devices.firstWhere(
      (d) => d.address == address,
      orElse: () => throw Exception('Device not found'),
    );

    bool? connected = await bluetooth.connect(device);
    if (connected == true) {
      _selectedDevice = device;
      _isConnected = true;
      _connectedDeviceName = device.name;
      return true;
    }
    return false;
  }

  Future<void> disconnect() async {
    await bluetooth.disconnect();
    _isConnected = false;
    _connectedDeviceName = null;
    _selectedDevice = null;
  }

  /// Check if printer is actually connected and responsive
  Future<bool> checkPrinterConnection() async {
    if (_selectedDevice == null) {
      _isConnected = false;
      return false;
    }

    try {
      // Try to check connection status
      bool? isConnected = await bluetooth.isConnected;
      if (isConnected == true) {
        _isConnected = true;
        return true;
      } else {
        // Connection lost, reset state
        _isConnected = false;
        _connectedDeviceName = null;
        _selectedDevice = null;
        return false;
      }
    } catch (e) {
      debugPrint('Connection check error: $e');
      _isConnected = false;
      _connectedDeviceName = null;
      _selectedDevice = null;
      return false;
    }
  }

  Future<bool> printReceipt(Map<String, dynamic> receiptData) async {
    // First check if connection is still alive
    bool isStillConnected = await checkPrinterConnection();
    if (!isStillConnected) return false;

    try {
      // Initialize ESC/POS profile
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);

      List<int> bytes = [];

      // Store header
      bytes += generator.text(
        receiptData['store_name'] ?? 'Smart Cashier',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );

      bytes += generator.text(
        receiptData['store_address'] ?? 'Jl. Example No. 123',
        styles: const PosStyles(align: PosAlign.center),
      );

      bytes += generator.feed(1);

      // Invoice info
      bytes += generator.text(
        'Invoice: ${receiptData['invoice_id'] ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );

      bytes += generator.text(
        'Tanggal: ${receiptData['printed_at'] ?? DateTime.now().toString()}',
        styles: const PosStyles(align: PosAlign.center),
      );

      bytes += generator.feed(1);
      bytes += generator.hr();

      // Customer info
      if (receiptData['customer_name'] != null &&
          receiptData['customer_name'].toString().isNotEmpty) {
        bytes += generator.text('Pelanggan: ${receiptData['customer_name']}');
        if (receiptData['customer_phone'] != null) {
          bytes += generator.text('Telp: ${receiptData['customer_phone']}');
        }
        bytes += generator.feed(1);
      }

      // Items header
      bytes += generator.row([
        PosColumn(text: 'Item', width: 8),
        PosColumn(
          text: 'Qty',
          width: 2,
          styles: const PosStyles(align: PosAlign.right),
        ),
        PosColumn(
          text: 'Total',
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.hr();

      // Items
      List<dynamic> items = receiptData['items'] ?? [];
      for (var item in items) {
        String name = item['name'] ?? '';
        int qty = item['qty'] ?? item['quantity'] ?? 1;
        double subtotal = (item['subtotal'] ?? item['unit_price'] ?? 0.0) * 1.0;

        bytes += generator.row([
          PosColumn(
            text: name.length > 12 ? '${name.substring(0, 12)}...' : name,
            width: 8,
          ),
          PosColumn(
            text: '$qty',
            width: 2,
            styles: const PosStyles(align: PosAlign.right),
          ),
          PosColumn(
            text: 'Rp${subtotal.toStringAsFixed(0)}',
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      bytes += generator.hr();

      // Totals
      double subtotal = receiptData['subtotal'] ?? 0.0;
      double tax = receiptData['tax_amount'] ?? 0.0;
      double total = receiptData['final_total'] ?? receiptData['total'] ?? 0.0;

      bytes += generator.row([
        PosColumn(text: 'Subtotal', width: 8),
        PosColumn(text: '', width: 2),
        PosColumn(
          text: 'Rp${subtotal.toStringAsFixed(0)}',
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      if (tax > 0) {
        bytes += generator.row([
          PosColumn(text: 'PPN (10%)', width: 8),
          PosColumn(text: '', width: 2),
          PosColumn(
            text: 'Rp${tax.toStringAsFixed(0)}',
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      bytes += generator.row([
        PosColumn(text: 'TOTAL', width: 8, styles: const PosStyles(bold: true)),
        PosColumn(text: '', width: 2),
        PosColumn(
          text: 'Rp${total.toStringAsFixed(0)}',
          width: 4,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);

      bytes += generator.feed(1);

      // Payment info
      String paymentMethod = receiptData['payment_method'] ?? 'Cash';
      bytes += generator.text(
        'Pembayaran: $paymentMethod',
        styles: const PosStyles(align: PosAlign.center),
      );

      // Change calculation
      double paid = receiptData['paid_amount'] ?? total;
      double change = paid - total;
      if (change > 0) {
        bytes += generator.text(
          'Kembalian: Rp${change.toStringAsFixed(0)}',
          styles: const PosStyles(align: PosAlign.center),
        );
      }

      bytes += generator.feed(2);

      // Footer
      bytes += generator.text(
        'Terima Kasih',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );

      bytes += generator.text(
        'Atas Kunjungan Anda',
        styles: const PosStyles(align: PosAlign.center),
      );

      bytes += generator.feed(3);
      bytes += generator.cut();

      // Send to printer
      await bluetooth.writeBytes(Uint8List.fromList(bytes));

      return true;
    } catch (e) {
      debugPrint('Print error: $e');
      return false;
    }
  }

  Future<bool> printTest() async {
    // First check if connection is still alive
    bool isStillConnected = await checkPrinterConnection();
    if (!isStillConnected) return false;

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);

      List<int> bytes = [];

      bytes += generator.text(
        'SMART CASHIER',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );

      bytes += generator.feed(1);
      bytes += generator.text(
        'Test Print Berhasil',
        styles: const PosStyles(align: PosAlign.center),
      );

      bytes += generator.text(
        DateTime.now().toString(),
        styles: const PosStyles(align: PosAlign.center),
      );

      bytes += generator.feed(3);
      bytes += generator.cut();

      await bluetooth.writeBytes(Uint8List.fromList(bytes));

      return true;
    } catch (e) {
      debugPrint('Test print error: $e');
      return false;
    }
  }
}
