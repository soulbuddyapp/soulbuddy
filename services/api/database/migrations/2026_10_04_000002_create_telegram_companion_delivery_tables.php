<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        $this->addConnectionColumns();
        DB::table('telegram_connections')->update([
            'daily_enabled' => true,
            'formation_enabled' => true,
            'prayer_enabled' => true,
            'sacred_hour_enabled' => true,
            'care_enabled' => true,
        ]);

        if (! Schema::hasTable('telegram_companion_deliveries')) {
            Schema::create('telegram_companion_deliveries', function (Blueprint $table): void {
                $table->uuid('id')->primary();
                $table->uuid('telegram_connection_id');
                $table->string('kind', 48);
                $table->string('occurrence_key', 191);
                $table->dateTime('delivered_at');
                $table->dateTime('created_at');
                $table->foreign('telegram_connection_id')
                    ->references('id')->on('telegram_connections')->cascadeOnDelete();
                $table->unique(['telegram_connection_id', 'occurrence_key'], 'tg_companion_delivery_once');
                $table->index(['telegram_connection_id', 'kind', 'delivered_at'], 'tg_companion_delivery_due');
            });
        } elseif (! Schema::hasIndex('telegram_companion_deliveries', 'tg_companion_delivery_once')) {
            Schema::table('telegram_companion_deliveries', function (Blueprint $table): void {
                $table->unique(['telegram_connection_id', 'occurrence_key'], 'tg_companion_delivery_once');
                $table->index(['telegram_connection_id', 'kind', 'delivered_at'], 'tg_companion_delivery_due');
            });
        }

        if (Schema::hasTable('formation_activity_events')) {
            return;
        }
        Schema::create('formation_activity_events', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('formation_video_id', 120);
            $table->enum('activity_type', ['opened', 'completed']);
            $table->enum('source', ['app', 'telegram']);
            $table->dateTime('occurred_at');
            $table->dateTime('created_at');
            $table->index(['user_id', 'occurred_at']);
            $table->index(['user_id', 'formation_video_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('formation_activity_events');
        Schema::dropIfExists('telegram_companion_deliveries');
        Schema::table('telegram_connections', function (Blueprint $table): void {
            $table->dropColumn([
                'formation_enabled',
                'prayer_enabled',
                'sacred_hour_enabled',
                'care_enabled',
            ]);
        });
    }

    private function addConnectionColumns(): void
    {
        foreach ([
            'formation_enabled' => 'daily_enabled',
            'prayer_enabled' => 'formation_enabled',
            'sacred_hour_enabled' => 'prayer_enabled',
            'care_enabled' => 'sacred_hour_enabled',
        ] as $column => $after) {
            if (Schema::hasColumn('telegram_connections', $column)) {
                continue;
            }
            Schema::table('telegram_connections', function (Blueprint $table) use ($column, $after): void {
                $table->boolean($column)->default(true)->after($after);
            });
        }
    }
};
