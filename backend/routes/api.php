<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\ProductController;
use App\Http\Controllers\CustomerController;
use App\Http\Controllers\SaleController;
use App\Http\Controllers\RecommendationController;

// Public routes
Route::post('/login', [AuthController::class, 'login']);

// Protected routes
Route::middleware('auth:sanctum')->group(function () {
    // Authentication
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::post('/refresh', [AuthController::class, 'refresh']);
    Route::get('/profile', [AuthController::class, 'profile']);

    // Products
    Route::apiResource('products', ProductController::class);
    Route::post('/products/search/barcode', [ProductController::class, 'searchByBarcode']);
    Route::patch('/products/{product}/stock', [ProductController::class, 'updateStock']);
    Route::get('/products/low-stock', [ProductController::class, 'getLowStockProducts']);

    // Categories (nested under products for now)
    Route::get('/categories', function () {
        return response()->json([
            'success' => true,
            'data' => \App\Models\Category::all(),
        ]);
    });

    // Customers
    Route::apiResource('customers', CustomerController::class);
    Route::get('/customers/{customer}/history', [CustomerController::class, 'getPurchaseHistory']);
    Route::post('/customers/{customer}/points/add', [CustomerController::class, 'addPoints']);
    Route::post('/customers/{customer}/points/use', [CustomerController::class, 'usePoints']);
    Route::get('/customers/top', [CustomerController::class, 'getTopCustomers']);

    // Sales/Transactions
    Route::apiResource('sales', SaleController::class)->except(['update']);
    Route::patch('/sales/{sale}', [SaleController::class, 'update']);
    Route::post('/sales/{sale}/payment', [SaleController::class, 'processPayment']);
    Route::get('/sales/{sale}/receipt', [SaleController::class, 'getReceipt']);
    Route::get('/reports/daily', [SaleController::class, 'getDailyReport']);
    Route::get('/reports/sales', [SaleController::class, 'getSalesReport']);

    // AI Recommendations
    Route::get('/recommendations', [RecommendationController::class, 'getRecommendations']);
    Route::post('/recommendations/generate', [RecommendationController::class, 'generateRecommendations']);
    Route::get('/recommendations/frequent-together', [RecommendationController::class, 'getFrequentlyBoughtTogether']);
    Route::get('/recommendations/trending', [RecommendationController::class, 'getTrendingProducts']);
    Route::get('/recommendations/customer-based', [RecommendationController::class, 'getCustomerBasedRecommendations']);

    // Dashboard/Analytics (for admin)
    Route::get('/dashboard/stats', function () {
        $today = today();

        $stats = [
            'today_sales' => \App\Models\Sale::completed()->whereDate('created_at', $today)->count(),
            'today_revenue' => \App\Models\Sale::completed()->whereDate('created_at', $today)->sum('final_amount'),
            'total_products' => \App\Models\Product::active()->count(),
            'low_stock_products' => \App\Models\Product::lowStock()->count(),
            'total_customers' => \App\Models\Customer::count(),
            'pending_payments' => \App\Models\Sale::where('payment_status', '!=', 'paid')->count(),
        ];

        return response()->json([
            'success' => true,
            'data' => $stats,
        ]);
    });

    // Inventory movements
    Route::get('/inventory/movements', function (Request $request) {
        $query = \App\Models\InventoryMovement::with(['product', 'user']);

        if ($request->has('type')) {
            $query->byType($request->type);
        }

        if ($request->has('days')) {
            $query->recent($request->days);
        }

        $movements = $query->orderBy('created_at', 'desc')
                           ->paginate($request->get('per_page', 15));

        return response()->json([
            'success' => true,
            'data' => $movements,
        ]);
    });
});