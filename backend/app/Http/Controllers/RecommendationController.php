<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\ProductRecommendation;
use App\Models\Customer;
use App\Models\Product;
use App\Models\PurchaseHistory;

class RecommendationController extends Controller
{
    public function getRecommendations(Request $request)
    {
        $customerId = $request->get('customer_id');
        $limit = $request->get('limit', 5);

        if (!$customerId) {
            // General recommendations for non-logged-in users
            return $this->getGeneralRecommendations($limit);
        }

        $customer = Customer::find($customerId);
        if (!$customer) {
            return response()->json([
                'success' => false,
                'message' => 'Customer not found',
            ], 404);
        }

        // Get personalized recommendations
        $recommendations = ProductRecommendation::where('customer_id', $customerId)
            ->active()
            ->highConfidence()
            ->with('recommendedProduct.category')
            ->orderBy('confidence_score', 'desc')
            ->limit($limit)
            ->get();

        // If not enough personalized recommendations, add general ones
        if ($recommendations->count() < $limit) {
            $personalizedProductIds = $recommendations->pluck('recommended_product_id')->toArray();

            $generalRecommendations = ProductRecommendation::whereNull('customer_id')
                ->whereNotIn('recommended_product_id', $personalizedProductIds)
                ->active()
                ->with('recommendedProduct.category')
                ->orderBy('confidence_score', 'desc')
                ->limit($limit - $recommendations->count())
                ->get();

            $recommendations = $recommendations->merge($generalRecommendations);
        }

        $data = $recommendations->map(function ($rec) {
            return [
                'id' => $rec->id,
                'product' => $rec->recommendedProduct,
                'confidence_score' => $rec->confidence_score,
                'reason' => $this->getRecommendationReason($rec),
            ];
        });

        return response()->json([
            'success' => true,
            'data' => $data,
        ]);
    }

    public function generateRecommendations(Request $request)
    {
        $customerId = $request->get('customer_id');

        try {
            $count = ProductRecommendation::generateRecommendations($customerId);

            return response()->json([
                'success' => true,
                'message' => "Generated $count recommendations",
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    public function getFrequentlyBoughtTogether(Request $request)
    {
        $productId = $request->get('product_id');
        $limit = $request->get('limit', 3);

        if (!$productId) {
            return response()->json([
                'success' => false,
                'message' => 'Product ID is required',
            ], 400);
        }

        // Find products frequently bought together
        $relatedProducts = PurchaseHistory::selectRaw('product_id, COUNT(*) as frequency')
            ->whereIn('sale_id', function ($query) use ($productId) {
                $query->select('sale_id')
                      ->from('purchase_history')
                      ->where('product_id', $productId);
            })
            ->where('product_id', '!=', $productId)
            ->groupBy('product_id')
            ->orderBy('frequency', 'desc')
            ->limit($limit)
            ->with('product')
            ->get();

        $data = $relatedProducts->map(function ($item) {
            return [
                'product' => $item->product,
                'frequency' => $item->frequency,
                'reason' => 'Frequently bought together',
            ];
        });

        return response()->json([
            'success' => true,
            'data' => $data,
        ]);
    }

    public function getTrendingProducts(Request $request)
    {
        $limit = $request->get('limit', 10);
        $days = $request->get('days', 30);

        $trendingProducts = PurchaseHistory::selectRaw('product_id, SUM(quantity) as total_sold')
            ->where('purchase_date', '>=', now()->subDays($days)->toDateString())
            ->groupBy('product_id')
            ->orderBy('total_sold', 'desc')
            ->limit($limit)
            ->with('product.category')
            ->get();

        $data = $trendingProducts->map(function ($item) {
            return [
                'product' => $item->product,
                'total_sold' => $item->total_sold,
                'reason' => 'Trending this month',
            ];
        });

        return response()->json([
            'success' => true,
            'data' => $data,
        ]);
    }

    public function getCustomerBasedRecommendations(Request $request)
    {
        $customerId = $request->get('customer_id');
        $limit = $request->get('limit', 5);

        if (!$customerId) {
            return response()->json([
                'success' => false,
                'message' => 'Customer ID is required',
            ], 400);
        }

        // Get customer's purchase history
        $customerPurchases = PurchaseHistory::where('customer_id', $customerId)
            ->pluck('product_id')
            ->toArray();

        if (empty($customerPurchases)) {
            return $this->getGeneralRecommendations($limit);
        }

        // Find customers with similar purchase patterns
        $similarCustomers = PurchaseHistory::select('customer_id')
            ->whereIn('product_id', $customerPurchases)
            ->where('customer_id', '!=', $customerId)
            ->groupBy('customer_id')
            ->orderByRaw('COUNT(*) DESC')
            ->limit(10)
            ->pluck('customer_id');

        // Get products bought by similar customers but not by this customer
        $recommendations = PurchaseHistory::selectRaw('product_id, COUNT(*) as frequency')
            ->whereIn('customer_id', $similarCustomers)
            ->whereNotIn('product_id', $customerPurchases)
            ->groupBy('product_id')
            ->orderBy('frequency', 'desc')
            ->limit($limit)
            ->with('product.category')
            ->get();

        $data = $recommendations->map(function ($item) {
            return [
                'product' => $item->product,
                'frequency' => $item->frequency,
                'reason' => 'Customers with similar tastes bought this',
            ];
        });

        return response()->json([
            'success' => true,
            'data' => $data,
        ]);
    }

    private function getGeneralRecommendations($limit)
    {
        // Get most popular products
        $popularProducts = PurchaseHistory::selectRaw('product_id, SUM(quantity) as total_sold')
            ->groupBy('product_id')
            ->orderBy('total_sold', 'desc')
            ->limit($limit)
            ->with('product.category')
            ->get();

        $data = $popularProducts->map(function ($item) {
            return [
                'product' => $item->product,
                'total_sold' => $item->total_sold,
                'reason' => 'Popular product',
            ];
        });

        return response()->json([
            'success' => true,
            'data' => $data,
        ]);
    }

    private function getRecommendationReason($recommendation)
    {
        if ($recommendation->recommendation_type === 'trending') {
            return 'Trending product';
        } elseif ($recommendation->recommendation_type === 'personalized') {
            return 'Based on your purchase history';
        } elseif ($recommendation->recommendation_type === 'frequent_itemset') {
            return 'Frequently bought together';
        }

        return 'Recommended for you';
    }
}