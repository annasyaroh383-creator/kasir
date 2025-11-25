<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Customer extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'name',
        'email',
        'phone',
        'membership_id',
        'points',
        'total_spent',
    ];

    protected $casts = [
        'points' => 'decimal:2',
        'total_spent' => 'decimal:2',
    ];

    // Relationships
    public function sales()
    {
        return $this->hasMany(Sale::class);
    }

    public function purchaseHistories()
    {
        return $this->hasMany(PurchaseHistory::class);
    }

    public function productRecommendations()
    {
        return $this->hasMany(ProductRecommendation::class);
    }

    // Scopes
    public function scopeHasMembership($query)
    {
        return $query->whereNotNull('membership_id');
    }

    public function scopeHighValue($query, $threshold = 1000000)
    {
        return $query->where('total_spent', '>=', $threshold);
    }

    // Accessors
    public function getMembershipTierAttribute()
    {
        if ($this->total_spent >= 5000000) return 'Platinum';
        if ($this->total_spent >= 2000000) return 'Gold';
        if ($this->total_spent >= 500000) return 'Silver';
        return 'Bronze';
    }

    // Methods
    public function addPoints($amount)
    {
        $pointsEarned = floor($amount / 10000); // 1 point per 10k spent
        $this->increment('points', $pointsEarned);
    }

    public function usePoints($points)
    {
        if ($this->points >= $points) {
            $this->decrement('points', $points);
            return true;
        }
        return false;
    }

    public function addToTotalSpent($amount)
    {
        $this->increment('total_spent', $amount);
        $this->addPoints($amount);
    }
}