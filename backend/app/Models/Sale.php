<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Sale extends Model
{
    use HasFactory, SoftDeletes;

    protected static function boot()
    {
        parent::boot();

        static::creating(function ($sale) {
            if (empty($sale->invoice_code)) {
                $sale->invoice_code = static::generateInvoiceCode();
            }
        });
    }

    protected $fillable = [
        'invoice_code',
        'customer_id',
        'user_id',
        'total_amount',
        'discount_amount',
        'tax_amount',
        'final_amount',
        'status',
        'payment_status',
        'notes',
    ];

    protected $casts = [
        'total_amount' => 'decimal:2',
        'discount_amount' => 'decimal:2',
        'tax_amount' => 'decimal:2',
        'final_amount' => 'decimal:2',
    ];

    // Relationships
    public function customer()
    {
        return $this->belongsTo(Customer::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function saleItems()
    {
        return $this->hasMany(SaleItem::class);
    }

    public function payments()
    {
        return $this->hasMany(Payment::class);
    }

    public function purchaseHistories()
    {
        return $this->hasMany(PurchaseHistory::class);
    }

    // Scopes
    public function scopeCompleted($query)
    {
        return $query->where('status', 'completed');
    }

    public function scopePaid($query)
    {
        return $query->where('payment_status', 'paid');
    }

    public function scopeToday($query)
    {
        return $query->whereDate('created_at', today());
    }

    // Accessors
    public function getTotalItemsAttribute()
    {
        return $this->saleItems->sum('quantity');
    }

    public function getIsFullyPaidAttribute()
    {
        return $this->payment_status === 'paid';
    }

    // Methods
    public static function generateInvoiceCode()
    {
        $date = now()->format('Ymd');
        $lastSale = static::where('invoice_code', 'like', "INV-{$date}%")
                         ->orderBy('invoice_code', 'desc')
                         ->first();

        if ($lastSale) {
            $lastNumber = (int) substr($lastSale->invoice_code, -4);
            $newNumber = str_pad($lastNumber + 1, 4, '0', STR_PAD_LEFT);
        } else {
            $newNumber = '0001';
        }

        return "INV-{$date}-{$newNumber}";
    }

    public function calculateTotals()
    {
        $this->total_amount = $this->saleItems->sum(function ($item) {
            return $item->quantity * $item->unit_price;
        });

        $this->final_amount = $this->total_amount + $this->tax_amount - $this->discount_amount;
        $this->save();
    }

    public function markAsCompleted()
    {
        $this->status = 'completed';
        $this->save();

        // Update inventory
        foreach ($this->saleItems as $item) {
            $item->product->decrement('stock_quantity', $item->quantity);

            // Create inventory movement
            InventoryMovement::create([
                'product_id' => $item->product_id,
                'type' => 'sale',
                'quantity' => $item->quantity,
                'previous_stock' => $item->product->stock_quantity + $item->quantity,
                'new_stock' => $item->product->stock_quantity,
                'reference_id' => $this->id,
                'user_id' => $this->user_id,
            ]);

            // Create purchase history
            PurchaseHistory::create([
                'customer_id' => $this->customer_id,
                'product_id' => $item->product_id,
                'sale_id' => $this->id,
                'quantity' => $item->quantity,
                'unit_price' => $item->unit_price,
                'purchase_date' => $this->created_at->toDateString(),
            ]);
        }

        // Update customer total spent and points
        if ($this->customer) {
            $this->customer->addToTotalSpent($this->final_amount);
        }
    }
}