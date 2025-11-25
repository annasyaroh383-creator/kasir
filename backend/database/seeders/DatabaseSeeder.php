<?php

namespace Database\Seeders;

use App\Models\User;
use App\Models\Category;
use App\Models\Product;
use App\Models\Customer;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // Create admin user
        User::create([
            'name' => 'Administrator',
            'email' => 'admin@kasir.com',
            'password' => Hash::make('password'),
            'role' => 'admin',
            'is_active' => true,
        ]);

        // Create cashier user
        User::create([
            'name' => 'Kasir 1',
            'email' => 'kasir@kasir.com',
            'password' => Hash::make('password'),
            'role' => 'cashier',
            'is_active' => true,
        ]);

        // Create categories
        $categories = [
            ['name' => 'Makanan', 'description' => 'Produk makanan dan minuman'],
            ['name' => 'Minuman', 'description' => 'Berbagai jenis minuman'],
            ['name' => 'Snack', 'description' => 'Camilan dan makanan ringan'],
            ['name' => 'Produk Rumah Tangga', 'description' => 'Kebutuhan rumah tangga'],
            ['name' => 'Produk Kesehatan', 'description' => 'Obat-obatan dan produk kesehatan'],
        ];

        foreach ($categories as $category) {
            Category::create($category);
        }

        // Create sample products
        $products = [
            [
                'name' => 'Nasi Putih',
                'barcode' => '10000001',
                'category_id' => 1,
                'price' => 5000,
                'cost_price' => 3000,
                'stock_quantity' => 100,
                'min_stock_level' => 10,
                'description' => 'Nasi putih berkualitas tinggi',
                'is_active' => true,
            ],
            [
                'name' => 'Ayam Goreng',
                'barcode' => '10000002',
                'category_id' => 1,
                'price' => 15000,
                'cost_price' => 8000,
                'stock_quantity' => 50,
                'min_stock_level' => 5,
                'description' => 'Ayam goreng crispy',
                'is_active' => true,
            ],
            [
                'name' => 'Es Teh Manis',
                'barcode' => '20000001',
                'category_id' => 2,
                'price' => 3000,
                'cost_price' => 1500,
                'stock_quantity' => 200,
                'min_stock_level' => 20,
                'description' => 'Es teh manis dingin',
                'is_active' => true,
            ],
            [
                'name' => 'Kopi Hitam',
                'barcode' => '20000002',
                'category_id' => 2,
                'price' => 4000,
                'cost_price' => 2000,
                'stock_quantity' => 150,
                'min_stock_level' => 15,
                'description' => 'Kopi hitam pekat',
                'is_active' => true,
            ],
            [
                'name' => 'Keripik Kentang',
                'barcode' => '30000001',
                'category_id' => 3,
                'price' => 8000,
                'cost_price' => 4000,
                'stock_quantity' => 80,
                'min_stock_level' => 8,
                'description' => 'Keripik kentang original',
                'is_active' => true,
            ],
            [
                'name' => 'Sabun Mandi',
                'barcode' => '40000001',
                'category_id' => 4,
                'price' => 12000,
                'cost_price' => 6000,
                'stock_quantity' => 60,
                'min_stock_level' => 6,
                'description' => 'Sabun mandi wangi',
                'is_active' => true,
            ],
            [
                'name' => 'Paracetamol',
                'barcode' => '50000001',
                'category_id' => 5,
                'price' => 2500,
                'cost_price' => 1000,
                'stock_quantity' => 120,
                'min_stock_level' => 12,
                'description' => 'Obat sakit kepala',
                'is_active' => true,
            ],
        ];

        foreach ($products as $product) {
            Product::create($product);
        }

        // Create sample customers
        $customers = [
            [
                'name' => 'Budi Santoso',
                'email' => 'budi@email.com',
                'phone' => '081234567890',
                'membership_id' => 'MEM001',
                'points' => 150,
                'total_spent' => 750000,
            ],
            [
                'name' => 'Siti Aminah',
                'email' => 'siti@email.com',
                'phone' => '081987654321',
                'membership_id' => 'MEM002',
                'points' => 200,
                'total_spent' => 1200000,
            ],
            [
                'name' => 'Ahmad Rahman',
                'email' => 'ahmad@email.com',
                'phone' => '081345678901',
                'membership_id' => null,
                'points' => 50,
                'total_spent' => 250000,
            ],
        ];

        foreach ($customers as $customer) {
            Customer::create($customer);
        }
    }
}
