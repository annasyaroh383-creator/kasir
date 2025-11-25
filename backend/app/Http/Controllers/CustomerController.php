<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Customer;

class CustomerController extends Controller
{
    public function index(Request $request)
    {
        $query = Customer::query();

        // Search by name, email, or phone
        if ($request->has('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('email', 'like', "%{$search}%")
                  ->orWhere('phone', 'like', "%{$search}%");
            });
        }

        // Filter by membership
        if ($request->has('has_membership')) {
            $query->hasMembership();
        }

        // Filter by membership tier
        if ($request->has('tier')) {
            $query->where('total_spent', '>=', $this->getTierThreshold($request->tier));
        }

        $customers = $query->orderBy('created_at', 'desc')
                           ->paginate($request->get('per_page', 15));

        return response()->json([
            'success' => true,
            'data' => $customers,
        ]);
    }

    public function store(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'nullable|email|unique:customers',
            'phone' => 'nullable|string|max:20',
            'membership_id' => 'nullable|string|max:50|unique:customers',
        ]);

        $customer = Customer::create($request->all());

        return response()->json([
            'success' => true,
            'message' => 'Customer created successfully',
            'data' => $customer,
        ], 201);
    }

    public function show(Customer $customer)
    {
        return response()->json([
            'success' => true,
            'data' => $customer->load(['sales' => function ($query) {
                $query->with('saleItems.product')->latest()->limit(10);
            }]),
        ]);
    }

    public function update(Request $request, Customer $customer)
    {
        $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'email' => 'nullable|email|unique:customers,email,' . $customer->id,
            'phone' => 'nullable|string|max:20',
            'membership_id' => 'nullable|string|max:50|unique:customers,membership_id,' . $customer->id,
        ]);

        $customer->update($request->all());

        return response()->json([
            'success' => true,
            'message' => 'Customer updated successfully',
            'data' => $customer,
        ]);
    }

    public function destroy(Customer $customer)
    {
        // Check if customer has sales
        if ($customer->sales()->exists()) {
            return response()->json([
                'success' => false,
                'message' => 'Cannot delete customer with existing sales',
            ], 400);
        }

        $customer->delete();

        return response()->json([
            'success' => true,
            'message' => 'Customer deleted successfully',
        ]);
    }

    public function getPurchaseHistory(Customer $customer)
    {
        $history = $customer->purchaseHistories()
                           ->with('product', 'sale')
                           ->orderBy('purchase_date', 'desc')
                           ->paginate(20);

        return response()->json([
            'success' => true,
            'data' => $history,
        ]);
    }

    public function addPoints(Request $request, Customer $customer)
    {
        $request->validate([
            'points' => 'required|integer|min:1',
        ]);

        $customer->increment('points', $request->points);

        return response()->json([
            'success' => true,
            'message' => 'Points added successfully',
            'data' => $customer,
        ]);
    }

    public function usePoints(Request $request, Customer $customer)
    {
        $request->validate([
            'points' => 'required|integer|min:1',
        ]);

        if ($customer->points < $request->points) {
            return response()->json([
                'success' => false,
                'message' => 'Insufficient points',
            ], 400);
        }

        $customer->decrement('points', $request->points);

        return response()->json([
            'success' => true,
            'message' => 'Points used successfully',
            'data' => $customer,
        ]);
    }

    public function getTopCustomers(Request $request)
    {
        $limit = $request->get('limit', 10);

        $customers = Customer::orderBy('total_spent', 'desc')
                            ->limit($limit)
                            ->get()
                            ->map(function ($customer) {
                                return [
                                    'id' => $customer->id,
                                    'name' => $customer->name,
                                    'total_spent' => $customer->total_spent,
                                    'membership_tier' => $customer->membership_tier,
                                    'points' => $customer->points,
                                ];
                            });

        return response()->json([
            'success' => true,
            'data' => $customers,
        ]);
    }

    private function getTierThreshold($tier)
    {
        return match ($tier) {
            'Bronze' => 0,
            'Silver' => 500000,
            'Gold' => 2000000,
            'Platinum' => 5000000,
            default => 0,
        };
    }
}