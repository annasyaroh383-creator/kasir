<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Carbon;
use App\Models\Sale;
use App\Models\SaleItem;
use App\Models\Payment;
use App\Models\Customer;
use App\Models\Product;

class SaleController extends Controller
{
    public function index(Request $request)
    {
        $query = Sale::with(['customer', 'user', 'saleItems.product']);

        // Filter by date range
        if ($request->has('start_date')) {
            $query->whereDate('created_at', '>=', $request->start_date);
        }

        if ($request->has('end_date')) {
            $query->whereDate('created_at', '<=', $request->end_date);
        }

        // Filter by status
        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        // Filter by payment status
        if ($request->has('payment_status')) {
            $query->where('payment_status', $request->payment_status);
        }

        // Filter by user (for cashier-specific sales)
        if ($request->has('user_id')) {
            $query->where('user_id', $request->user_id);
        }

        $sales = $query->orderBy('created_at', 'desc')
                       ->paginate($request->get('per_page', 15));

        return response()->json([
            'success' => true,
            'data' => $sales,
        ]);
    }

    public function store(Request $request)
    {
        $request->validate([
            'customer_id' => 'nullable|exists:customers,id',
            'items' => 'required|array|min:1',
            'items.*.product_id' => 'required|exists:products,id',
            'items.*.quantity' => 'required|integer|min:1',
            'items.*.unit_price' => 'required|numeric|min:0',
            'items.*.discount' => 'nullable|numeric|min:0',
            'discount_amount' => 'nullable|numeric|min:0',
            'tax_amount' => 'nullable|numeric|min:0',
            'notes' => 'nullable|string',
        ]);

        DB::beginTransaction();

        try {
            $user = auth('sanctum')->user();

            // Create sale
            $sale = Sale::create([
                'customer_id' => $request->customer_id,
                'user_id' => $user->id,
                'total_amount' => 0, // Will be calculated
                'discount_amount' => $request->discount_amount ?? 0,
                'tax_amount' => $request->tax_amount ?? 0,
                'final_amount' => 0, // Will be calculated
                'status' => 'pending',
                'payment_status' => 'unpaid',
                'notes' => $request->notes,
            ]);

            $totalAmount = 0;

            // Create sale items
            foreach ($request->items as $itemData) {
                $product = Product::findOrFail($itemData['product_id']);

                // Check stock availability
                if ($product->stock_quantity < $itemData['quantity']) {
                    throw new \Exception("Insufficient stock for product: {$product->name}");
                }

                $subtotal = ($itemData['unit_price'] * $itemData['quantity']) - ($itemData['discount'] ?? 0);

                SaleItem::create([
                    'sale_id' => $sale->id,
                    'product_id' => $itemData['product_id'],
                    'quantity' => $itemData['quantity'],
                    'unit_price' => $itemData['unit_price'],
                    'discount' => $itemData['discount'] ?? 0,
                    'subtotal' => $subtotal,
                ]);

                $totalAmount += $subtotal;
            }

            // Update sale totals
            $finalAmount = $totalAmount + $sale->tax_amount - $sale->discount_amount;

            $sale->update([
                'total_amount' => $totalAmount,
                'final_amount' => $finalAmount,
            ]);

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Sale created successfully',
                'data' => $sale->load(['customer', 'user', 'saleItems.product']),
            ], 201);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], 400);
        }
    }

    public function show(Sale $sale)
    {
        return response()->json([
            'success' => true,
            'data' => $sale->load(['customer', 'user', 'saleItems.product', 'payments']),
        ]);
    }

    public function update(Request $request, Sale $sale)
    {
        // Only allow updates for pending sales
        if ($sale->status !== 'pending') {
            return response()->json([
                'success' => false,
                'message' => 'Cannot update completed sale',
            ], 400);
        }

        $request->validate([
            'status' => 'nullable|in:pending,completed,cancelled,refunded',
            'notes' => 'nullable|string',
        ]);

        $sale->update($request->only(['status', 'notes']));

        // If marking as completed, process the sale
        if ($request->status === 'completed') {
            $sale->markAsCompleted();
        }

        return response()->json([
            'success' => true,
            'message' => 'Sale updated successfully',
            'data' => $sale->load(['customer', 'user', 'saleItems.product', 'payments']),
        ]);
    }

    public function processPayment(Request $request, Sale $sale)
    {
        $request->validate([
            'method' => 'required|in:cash,qris,e_money,card',
            'amount' => 'required|numeric|min:0',
            'reference_number' => 'nullable|string',
            'payment_data' => 'nullable|array',
        ]);

        // Check if payment amount is valid
        $remainingAmount = $sale->final_amount - $sale->payments()->sum('amount');

        if ($request->amount > $remainingAmount) {
            return response()->json([
                'success' => false,
                'message' => 'Payment amount exceeds remaining balance',
            ], 400);
        }

        // Create payment
        $payment = Payment::create([
            'sale_id' => $sale->id,
            'method' => $request->input('method'),
            'amount' => $request->amount,
            'reference_number' => $request->reference_number,
            'status' => 'completed',
            'payment_data' => $request->payment_data,
        ]);

        // Update payment status
        $totalPaid = $sale->payments()->sum('amount');
        if ($totalPaid >= $sale->final_amount) {
            $sale->update(['payment_status' => 'paid']);
        } elseif ($totalPaid > 0) {
            $sale->update(['payment_status' => 'partial']);
        }

        return response()->json([
            'success' => true,
            'message' => 'Payment processed successfully',
            'data' => $payment,
        ]);
    }

    public function getReceipt(Sale $sale)
    {
        // Generate receipt data for printing (Indonesian retail standard)
        $receiptData = [
            'invoice_id' => $sale->invoice_code,
            'store_name' => 'SmartSISAPA',
            'store_address' => 'Jl. Raya Supermarket No.1',
            'printed_at' => now()->format('Y-m-d H:i:s'),
            'items' => $sale->saleItems->map(function ($item) {
                return [
                    'name' => $item->product->name,
                    'qty' => $item->quantity,
                    'price' => $item->unit_price,
                    'subtotal' => $item->subtotal,
                ];
            }),
            'total' => $sale->total_amount,
            'discount' => $sale->discount_amount,
            'tax' => $sale->tax_amount,
            'final_total' => $sale->final_amount,
            'payment' => $sale->payments->sum('amount'),
            'change' => max(0, $sale->payments->sum('amount') - $sale->final_amount),
            'payment_method' => $sale->payments->first()?->method ?? 'cash',
            'cashier' => $sale->user->name,
            'customer' => $sale->customer?->name ?? 'Walk-in Customer',
        ];

        return response()->json([
            'success' => true,
            'data' => $receiptData,
        ]);
    }

    public function getDailyReport(Request $request)
    {
        $date = $request->get('date', today()->toDateString());

        $sales = Sale::whereDate('created_at', $date)
                     ->completed()
                     ->with(['customer', 'saleItems'])
                     ->get();

        $report = [
            'date' => $date,
            'total_sales' => $sales->count(),
            'total_revenue' => $sales->sum('final_amount'),
            'total_items_sold' => $sales->sum(function ($sale) {
                return $sale->saleItems->sum('quantity');
            }),
            'payment_methods' => $sales->flatMap->payments->groupBy('method')->map->sum('amount'),
            'top_products' => $sales->flatMap->saleItems
                ->groupBy('product.name')
                ->map(function ($items, $productName) {
                    return [
                        'name' => $productName,
                        'quantity' => $items->sum('quantity'),
                        'revenue' => $items->sum('subtotal'),
                    ];
                })
                ->sortByDesc('quantity')
                ->take(10)
                ->values(),
        ];

        return response()->json([
            'success' => true,
            'data' => $report,
        ]);
    }

    public function getSalesReport(Request $request)
    {
        $request->validate([
            'period' => 'required|in:day,week,month',
            'date' => 'nullable|date',
        ]);

        $period = $request->period;
        $date = $request->date ? Carbon::parse($request->date) : now();

        $query = Sale::completed()->with(['customer', 'user', 'saleItems.product', 'payments']);

        // Filter by period
        switch ($period) {
            case 'day':
                $query->whereDate('created_at', $date->toDateString());
                $groupBy = 'HOUR(created_at)';
                $dateFormat = '%H:00';
                break;
            case 'week':
                $startOfWeek = $date->copy()->startOfWeek();
                $endOfWeek = $date->copy()->endOfWeek();
                $query->whereBetween('created_at', [$startOfWeek, $endOfWeek]);
                $groupBy = 'DATE(created_at)';
                $dateFormat = '%Y-%m-%d';
                break;
            case 'month':
                $query->whereYear('created_at', $date->year)
                      ->whereMonth('created_at', $date->month);
                $groupBy = 'DATE(created_at)';
                $dateFormat = '%Y-%m-%d';
                break;
        }

        $sales = $query->get();

        // Chart data
        $chartData = Sale::selectRaw("
                DATE_FORMAT(created_at, '$dateFormat') as period,
                COUNT(*) as sales_count,
                SUM(final_amount) as revenue,
                SUM((SELECT SUM(quantity) FROM sale_items WHERE sale_items.sale_id = sales.id)) as items_sold
            ")
            ->whereIn('id', $sales->pluck('id'))
            ->groupBy('period')
            ->orderBy('period')
            ->get()
            ->map(function ($item) {
                return [
                    'period' => $item->period,
                    'sales_count' => (int) $item->sales_count,
                    'revenue' => (float) $item->revenue,
                    'items_sold' => (int) $item->items_sold,
                ];
            });

        // Summary statistics
        $summary = [
            'total_sales' => $sales->count(),
            'total_revenue' => $sales->sum('final_amount'),
            'total_items_sold' => $sales->sum(function ($sale) {
                return $sale->saleItems->sum('quantity');
            }),
            'average_sale' => $sales->count() > 0 ? $sales->sum('final_amount') / $sales->count() : 0,
            'payment_methods' => $sales->flatMap->payments->groupBy('method')->map->sum('amount'),
        ];

        // Top products
        $topProducts = $sales->flatMap->saleItems
            ->groupBy('product.name')
            ->map(function ($items, $productName) {
                return [
                    'name' => $productName,
                    'quantity' => $items->sum('quantity'),
                    'revenue' => $items->sum('subtotal'),
                    'transactions' => $items->count(),
                ];
            })
            ->sortByDesc('revenue')
            ->take(20)
            ->values();

        // Recent transactions
        $recentTransactions = $sales->sortByDesc('created_at')->take(50)->map(function ($sale) {
            return [
                'id' => $sale->id,
                'invoice_code' => $sale->invoice_code,
                'date' => $sale->created_at->format('Y-m-d H:i:s'),
                'customer' => $sale->customer?->name ?? 'Walk-in Customer',
                'cashier' => $sale->user->name,
                'total' => $sale->final_amount,
                'payment_method' => $sale->payments->first()?->method ?? 'unknown',
                'items_count' => $sale->saleItems->sum('quantity'),
            ];
        });

        return response()->json([
            'success' => true,
            'data' => [
                'period' => $period,
                'date' => $date->toDateString(),
                'chart_data' => $chartData,
                'summary' => $summary,
                'top_products' => $topProducts,
                'recent_transactions' => $recentTransactions,
            ],
        ]);
    }

    public function initiateQrPayment(Request $request)
    {
        \Log::info('QR Payment Initiation Request', [
            'headers' => $request->headers->all(),
            'body' => $request->all(),
            'auth_header' => $request->header('Authorization'),
        ]);

        $request->validate([
            'method' => 'required|in:qris,e_money',
            'amount' => 'required|numeric|min:1000',
            'invoice_id' => 'required|string',
        ]);

        $user = auth('sanctum')->user();
        \Log::info('User authentication check', [
            'user_found' => $user ? true : false,
            'user_id' => $user ? $user->id : null,
            'user_email' => $user ? $user->email : null,
        ]);

        if (!$user) {
            \Log::error('QR Payment: User not authenticated');
            return response()->json([
                'success' => false,
                'message' => 'Unauthorized',
            ], 401);
        }

        try {
            // Generate unique payment token for security
            $paymentToken = 'PAY_' . strtoupper(uniqid()) . '_' . time();

            // Generate QR string (simulated for demo)
            $qrString = $this->generateQrString($request->input('method'), $request->amount, $request->invoice_id);

            // Store payment initiation data (in production, use cache/database)
            $paymentData = [
                'invoice_id' => $request->invoice_id,
                'method' => $request->input('method'),
                'amount' => $request->amount,
                'payment_token' => $paymentToken,
                'status' => 'PENDING',
                'created_at' => now(),
                'expires_at' => now()->addMinutes(15), // 15 minutes expiry
            ];

            // Store in cache for demo (in production, use database)
            Cache::put('payment_' . $paymentToken, $paymentData, now()->addMinutes(15));

            return response()->json([
                'success' => true,
                'data' => [
                    'qr_string' => $qrString,
                    'payment_token' => $paymentToken,
                    'expires_at' => $paymentData['expires_at']->toISOString(),
                ],
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to initiate QR payment: ' . $e->getMessage(),
            ], 500);
        }
    }

    public function checkPaymentStatus(Request $request)
    {
        $request->validate([
            'invoice_id' => 'required|string',
        ]);

        // For demo purposes, simulate payment completion after some time
        $cacheKey = 'payment_status_' . $request->invoice_id;
        $status = Cache::get($cacheKey, 'PENDING');

        // Simulate payment completion (in production, this would come from payment gateway webhook)
        if ($status === 'PENDING' && rand(1, 10) > 7) { // 30% chance of completion
            $status = 'PAID';
            Cache::put($cacheKey, $status, now()->addMinutes(5));
        }

        return response()->json([
            'success' => true,
            'data' => [
                'status' => $status,
                'invoice_id' => $request->invoice_id,
            ],
        ]);
    }

    public function processQrPayment(Request $request)
    {
        $request->validate([
            'invoice_id' => 'required|string',
            'payment_token' => 'required|string',
            'method' => 'required|in:qris,e_money',
            'amount' => 'required|numeric|min:1000',
        ]);

        DB::beginTransaction();

        try {
            // Validate payment token
            $paymentData = Cache::get('payment_' . $request->payment_token);

            if (!$paymentData || $paymentData['invoice_id'] !== $request->invoice_id) {
                throw new \Exception('Invalid payment token');
            }

            if ($paymentData['status'] !== 'PAID') {
                throw new \Exception('Payment not completed');
            }

            if (now()->isAfter($paymentData['expires_at'])) {
                throw new \Exception('Payment token expired');
            }

            $user = auth('sanctum')->user();

            // Create sale
            $sale = Sale::create([
                'customer_id' => null, // No customer for QR payments
                'user_id' => $user->id,
                'total_amount' => $request->amount,
                'discount_amount' => 0,
                'tax_amount' => 0,
                'final_amount' => $request->amount,
                'status' => 'completed',
                'payment_status' => 'paid',
                'notes' => 'QR Payment - ' . $request->input('method'),
            ]);

            // Create payment record
            Payment::create([
                'sale_id' => $sale->id,
                'method' => $request->input('method'),
                'amount' => $request->amount,
                'reference_number' => $request->payment_token,
                'status' => 'completed',
                'payment_data' => json_encode([
                    'qr_payment' => true,
                    'payment_token' => $request->payment_token,
                ]),
            ]);

            // Clear payment cache
            Cache::forget('payment_' . $request->payment_token);

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Payment processed successfully',
                'data' => $sale->load(['payments']),
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], 400);
        }
    }

    public function processDirectPayment(Request $request)
    {
        $request->validate([
            'items' => 'required|array|min:1',
            'items.*.product_id' => 'required|exists:products,id',
            'items.*.quantity' => 'required|integer|min:1',
            'items.*.unit_price' => 'required|numeric|min:0',
            'items.*.discount' => 'nullable|numeric|min:0',
            'method' => 'required|in:cash,card',
            'amount' => 'required|numeric|min:0',
            'customer_id' => 'nullable|exists:customers,id',
            'customer_name' => 'nullable|string',
            'customer_phone' => 'nullable|string',
            'notes' => 'nullable|string',
        ]);

        DB::beginTransaction();

        try {
            $user = auth('sanctum')->user();

            // Create sale
            $sale = Sale::create([
                'customer_id' => $request->customer_id,
                'user_id' => $user->id,
                'total_amount' => 0, // Will be calculated
                'discount_amount' => 0,
                'tax_amount' => 0,
                'final_amount' => $request->amount, // Use provided amount
                'status' => 'completed',
                'payment_status' => 'paid',
                'notes' => $request->notes,
            ]);

            $totalAmount = 0;

            // Create sale items
            foreach ($request->items as $itemData) {
                $product = Product::findOrFail($itemData['product_id']);

                // Check stock availability
                if ($product->stock_quantity < $itemData['quantity']) {
                    throw new \Exception("Insufficient stock for product: {$product->name}");
                }

                $subtotal = ($itemData['unit_price'] * $itemData['quantity']) - ($itemData['discount'] ?? 0);

                SaleItem::create([
                    'sale_id' => $sale->id,
                    'product_id' => $itemData['product_id'],
                    'quantity' => $itemData['quantity'],
                    'unit_price' => $itemData['unit_price'],
                    'discount' => $itemData['discount'] ?? 0,
                    'subtotal' => $subtotal,
                ]);

                // Update product stock
                $product->decrement('stock_quantity', $itemData['quantity']);

                // Record inventory movement
                \App\Models\InventoryMovement::create([
                    'product_id' => $itemData['product_id'],
                    'type' => 'sale',
                    'quantity' => $itemData['quantity'],
                    'previous_stock' => $product->stock_quantity + $itemData['quantity'],
                    'new_stock' => $product->stock_quantity,
                    'reason' => 'Sale transaction',
                    'reference_id' => $sale->id,
                    'user_id' => $user->id,
                ]);

                $totalAmount += $subtotal;
            }

            // Update sale totals
            $sale->update([
                'total_amount' => $totalAmount,
            ]);

            // Create payment record
            Payment::create([
                'sale_id' => $sale->id,
                'method' => $request->input('method'),
                'amount' => $request->amount,
                'reference_number' => 'DIRECT-' . $sale->id,
                'status' => 'completed',
                'payment_data' => json_encode([
                    'direct_payment' => true,
                    'customer_name' => $request->customer_name,
                    'customer_phone' => $request->customer_phone,
                ]),
            ]);

            // Update purchase history for recommendations
            if ($sale->customer_id) {
                foreach ($sale->saleItems as $item) {
                    \App\Models\PurchaseHistory::create([
                        'customer_id' => $sale->customer_id,
                        'product_id' => $item->product_id,
                        'sale_id' => $sale->id,
                        'quantity' => $item->quantity,
                        'unit_price' => $item->unit_price,
                        'purchase_date' => $sale->created_at->toDateString(),
                    ]);
                }
            }

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Payment processed successfully',
                'data' => $sale->load(['payments', 'saleItems.product', 'customer']),
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], 400);
        }
    }

    public function validatePaymentToken(Request $request)
    {
        $request->validate([
            'payment_token' => 'required|string',
        ]);

        $paymentData = Cache::get('payment_' . $request->payment_token);

        if (!$paymentData) {
            return response()->json([
                'success' => false,
                'message' => 'Payment token not found',
            ]);
        }

        if (now()->isAfter($paymentData['expires_at'])) {
            return response()->json([
                'success' => false,
                'message' => 'Payment token expired',
            ]);
        }

        return response()->json([
            'success' => true,
            'data' => [
                'valid' => true,
                'invoice_id' => $paymentData['invoice_id'],
                'amount' => $paymentData['amount'],
                'method' => $paymentData['method'],
            ],
        ]);
    }

    private function generateQrString($method, $amount, $invoiceId)
    {
        if ($method === 'qris') {
            // Generate proper QRIS format (simplified for demo)
            // In production, this should come from a QRIS payment gateway like Midtrans, Gopay, etc.
            $merchantId = 'ID102001234567890'; // Demo merchant ID
            $merchantName = 'Smart Cashier';
            $transactionId = 'TXN' . time() . rand(1000, 9999);

            // QRIS format structure (simplified)
            $qrisData = [
                '00' => '01', // Payload Format Indicator
                '01' => '12', // Point of Initiation Method (12 = dynamic)
                '26' => [    // Merchant Account Information
                    '00' => 'ID.CO.QRIS.WWW', // Globally Unique Identifier
                    '01' => '0002', // Merchant Category Code
                    '02' => $merchantId, // Merchant ID
                    '03' => $merchantName, // Merchant Name
                ],
                '52' => '0000', // Merchant Category Code
                '53' => '360', // Transaction Currency (360 = IDR)
                '54' => number_format($amount, 0, '', ''), // Transaction Amount
                '58' => 'ID', // Country Code
                '59' => $merchantName, // Merchant Name
                '60' => 'Jakarta', // Merchant City
                '61' => '10110', // Postal Code
                '62' => [    // Additional Data Field
                    '01' => 'SMARTCASHIER', // Bill Number
                    '02' => $invoiceId, // Invoice ID
                ],
                '63' => '00', // CRC (placeholder, will be calculated)
            ];

            // Convert to QRIS string format
            $qrString = $this->buildQrisString($qrisData);

            // Add CRC16 checksum
            $crc = $this->calculateCrc16($qrString . '6304');
            $qrString .= '6304' . strtoupper($crc);

            return $qrString;
        } else {
            // For e-money, use a simpler format
            return 'EMONEY|' . $invoiceId . '|' . $amount . '|' . time();
        }
    }

    private function buildQrisString($data)
    {
        $result = '';

        foreach ($data as $id => $value) {
            if (is_array($value)) {
                $subData = '';
                foreach ($value as $subId => $subValue) {
                    $subData .= $subId . sprintf('%02d', strlen($subValue)) . $subValue;
                }
                $result .= $id . sprintf('%02d', strlen($subData)) . $subData;
            } else {
                $result .= $id . sprintf('%02d', strlen($value)) . $value;
            }
        }

        return $result;
    }

    private function calculateCrc16($data)
    {
        // Simple CRC16-CCITT calculation (simplified for demo)
        $crc = 0xFFFF;
        $polynomial = 0x1021;

        for ($i = 0; $i < strlen($data); $i++) {
            $byte = ord($data[$i]);
            for ($bit = 0; $bit < 8; $bit++) {
                $bitValue = ($byte >> (7 - $bit)) & 1;
                $crcBit = ($crc >> 15) & 1;
                $crc = ($crc << 1) & 0xFFFF;

                if ($bitValue != $crcBit) {
                    $crc ^= $polynomial;
                }
            }
        }

        return str_pad(dechex($crc), 4, '0', STR_PAD_LEFT);
    }
}