<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('product_recommendations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('customer_id')->constrained('customers');
            $table->foreignId('recommended_product_id')->constrained('products', 'id');
            $table->foreignId('base_product_id')->nullable()->constrained('products', 'id');
            $table->decimal('confidence_score', 5, 4);
            $table->integer('support_count');
            $table->enum('recommendation_type', ['frequent_itemset', 'personalized', 'trending']);
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('product_recommendations');
    }
};