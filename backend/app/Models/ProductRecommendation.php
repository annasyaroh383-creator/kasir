<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ProductRecommendation extends Model
{
    use HasFactory;

    protected $fillable = [
        'customer_id',
        'recommended_product_id',
        'base_product_id',
        'confidence_score',
        'support_count',
        'recommendation_type',
        'is_active',
    ];

    protected $casts = [
        'confidence_score' => 'decimal:4',
        'support_count' => 'integer',
        'is_active' => 'boolean',
    ];

    // Relationships
    public function customer()
    {
        return $this->belongsTo(Customer::class);
    }

    public function recommendedProduct()
    {
        return $this->belongsTo(Product::class, 'recommended_product_id');
    }

    public function baseProduct()
    {
        return $this->belongsTo(Product::class, 'base_product_id');
    }

    // Scopes
    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    public function scopeByType($query, $type)
    {
        return $query->where('recommendation_type', $type);
    }

    public function scopeHighConfidence($query, $threshold = 0.5)
    {
        return $query->where('confidence_score', '>=', $threshold);
    }

    public function scopeByCustomer($query, $customerId)
    {
        return $query->where('customer_id', $customerId);
    }

    // Methods
    public static function generateRecommendations($customerId = null)
    {
        // Simple recommendation algorithm based on purchase history
        $query = self::query();

        if ($customerId) {
            $query->where('customer_id', $customerId);
        }

        // Get popular products
        $popularProducts = PurchaseHistory::selectRaw('product_id, COUNT(*) as purchase_count')
            ->groupBy('product_id')
            ->orderBy('purchase_count', 'desc')
            ->limit(10)
            ->pluck('product_id');

        // Get customer's purchase history
        $customerPurchases = [];
        if ($customerId) {
            $customerPurchases = PurchaseHistory::where('customer_id', $customerId)
                ->pluck('product_id')
                ->toArray();
        }

        $recommendations = [];

        foreach ($popularProducts as $productId) {
            if (!in_array($productId, $customerPurchases)) {
                $recommendations[] = [
                    'customer_id' => $customerId,
                    'recommended_product_id' => $productId,
                    'confidence_score' => 0.8, // Simplified score
                    'support_count' => 1,
                    'recommendation_type' => 'trending',
                    'is_active' => true,
                ];
            }
        }

        // Insert or update recommendations
        foreach ($recommendations as $rec) {
            self::updateOrCreate(
                [
                    'customer_id' => $rec['customer_id'],
                    'recommended_product_id' => $rec['recommended_product_id'],
                ],
                $rec
            );
        }

        return count($recommendations);
    }
}