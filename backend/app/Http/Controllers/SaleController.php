<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
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
            $user = auth()->user();

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
            'method' => $request->method,
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
}