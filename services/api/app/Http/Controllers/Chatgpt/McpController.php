<?php

namespace App\Http\Controllers\Chatgpt;

use App\Domain\LifePlanning\ChatgptIdentity;
use App\Domain\LifePlanning\ChatgptAccountLinks;
use App\Domain\LifePlanning\LifePlannerService;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;
use Throwable;

class McpController extends Controller
{
    private const PROTOCOLS = ['2025-03-26', '2025-06-18', '2025-11-25'];

    public function protectedResource(ChatgptIdentity $identity): JsonResponse
    {
        if (! $identity->configured()) {
            return response()->json(['message' => 'ChatGPT identity provider is not configured.'], 503);
        }

        return response()->json([
            'resource' => $identity->resource(),
            'authorization_servers' => [$identity->issuer()],
            'scopes_supported' => ['life.read', 'life.write'],
            'bearer_methods_supported' => ['header'],
        ]);
    }

    public function handle(Request $request, ChatgptIdentity $identity, ChatgptAccountLinks $accounts, LifePlannerService $planner): JsonResponse|Response
    {
        $version = $request->header('MCP-Protocol-Version');
        if ($version && ! in_array($version, self::PROTOCOLS, true)) {
            return $this->rpc(null, null, -32600, 'Unsupported MCP protocol version', 400);
        }

        $body = $request->json()->all();
        $id = $body['id'] ?? null;
        if (($body['jsonrpc'] ?? null) !== '2.0' ||
            ! is_string($body['method'] ?? null) ||
            array_is_list($body)) {
            return $this->rpc($id, null, -32600, 'Invalid JSON-RPC request', 400);
        }

        $origin = $request->header('Origin');
        $appUrl = parse_url((string) config('app.url'));
        $appOrigin = isset($appUrl['scheme'], $appUrl['host'])
            ? $appUrl['scheme'].'://'.$appUrl['host'].(isset($appUrl['port']) ? ':'.$appUrl['port'] : '')
            : '';
        if ($origin && ! in_array($origin, [$appOrigin, 'https://chatgpt.com'], true)) {
            return $this->rpc($id, null, -32600, 'Origin not allowed', 403);
        }

        if (! array_key_exists('id', $body)) {
            // JSON-RPC notifications (including notifications/initialized) have no response payload.
            return response()->noContent(202);
        }

        if ($body['method'] === 'initialize') {
            $clientVersion = $body['params']['protocolVersion'] ?? null;

            return $this->rpc($id, [
                'protocolVersion' => in_array($clientVersion, self::PROTOCOLS, true)
                    ? $clientVersion : '2025-11-25',
                'capabilities' => ['tools' => ['listChanged' => false]],
                'serverInfo' => ['name' => 'soulbuddy-life-planner', 'version' => '0.1.0'],
                'instructions' => 'Help people thoughtfully design and review a seven-day rule of life. Ask about work, family, prayer, learning, reflection, service and rest. Never suggest that completion measures holiness, claim divine revelation, or compose prayers on SoulBuddy behalf. Before any write, show exactly what will be saved and obtain explicit consent. Do not record intimate confessions. Check get_account_link_status before storing private plans. Read tools do not create accounts: with consent, call create_soulbuddy_account for a new user or link_existing_soulbuddy_account with a code generated from the user’s already authenticated SoulBuddy account. Never infer account ownership from email alone. '
                    .'During planning, offer an optional daily reminder once. Only with explicit consent and a chosen local time and time zone, request a recurring ChatGPT scheduled task if available. Ask whether reminders may include commitment details; default to a generic reminder because notifications can be visible to others. Each run must read get_daily_life_plan without writing: invite setup when there is no plan, report the start date for an upcoming plan, remind about today’s commitments, or invite a review after the week ends. Include commitment details only with permission. Do not treat authentication or service failure as an empty plan. Say a reminder is active only when the platform has confirmed it; never claim notification delivery without evidence. '
                    .'For a disconnect request, use get_connection_management to find verified provider controls, explain that ending the provider session and disconnecting ChatGPT are separate steps, and never claim a session or token was revoked merely because a link was returned.',
            ]);
        }

        if ($body['method'] === 'ping') {
            return $this->rpc($id, (object) []);
        }

        if ($body['method'] === 'tools/list') {
            return $this->rpc($id, ['tools' => $this->tools()]);
        }

        if ($body['method'] !== 'tools/call') {
            return $this->rpc($id, null, -32601, 'Method not found');
        }

        $name = $body['params']['name'] ?? null;
        $args = $body['params']['arguments'] ?? [];
        if (! is_string($name) || ! is_array($args) || array_is_list($args) && $args !== []) {
            return $this->rpc($id, null, -32602, 'Invalid tool arguments');
        }

        if ($name === 'get_planning_guide') {
            return $this->rpc($id, $this->toolResponse([
                'approach' => 'Start with an honest assessment, propose a realistic seven-day plan, check in daily and reflect at the end. Adjust without guilt or moral scores.',
                'daily_pillars' => [
                    'Draw closer to God through prayer and service',
                    'Learn something about God and practice a virtue',
                    'Spend 6-10 minutes examining personal reactions and relationships',
                ],
                'other_domains' => ['work', 'relationships', 'rest'],
                'privacy' => 'Do not write personal details to SoulBuddy until the user has explicitly agreed.',
            ]));
        }

        if ($name === 'get_connection_management') {
            $url = $identity->accountManagementUrl();

            return $this->rpc($id, $this->toolResponse($url ? [
                'status' => 'available',
                'url' => $url,
                'message' => 'End the SoulBuddy application session with your provider, then disconnect in ChatGPT.',
            ] : [
                'status' => 'unavailable',
                'message' => 'Account access controls are unavailable.',
            ]));
        }

        $scope = match ($name) {
            'get_account_link_status' => 'life.read',
            'create_soulbuddy_account', 'link_existing_soulbuddy_account' => 'life.write',
            'get_life_plan', 'get_daily_life_plan', 'list_life_plans', 'review_week' => 'life.read',
            'create_seven_day_plan', 'record_daily_checkin', 'save_weekly_review', 'delete_life_plan' => 'life.write',
            default => null,
        };

        if (! $scope) {
            return $this->rpc($id, null, -32602, 'Unknown tool');
        }

        $principal = $identity->verify($request, $scope);
        if (! $principal) {
            if (! $identity->configured()) {
                return $this->rpc($id, $this->toolError('Life planner is not configured for secure account linking.'));
            }

            return $this->rpc($id, $this->toolError('Sign in with your SoulBuddy identity provider to continue.', [
                'mcp/www_authenticate' => [
                    'Bearer resource_metadata="'.rtrim((string) config('app.url'), '/').'/.well-known/oauth-protected-resource", error="insufficient_scope", error_description="Sign in to SoulBuddy with life planning access"',
                ],
            ]));
        }

        try {
            if ($name === 'get_account_link_status') {
                return $this->rpc($id, $this->toolResponse([
                    'status' => $accounts->resolve($principal) ? 'linked' : 'not_linked',
                    'message' => 'Account lookup is based on the provider issuer and subject, never email alone.',
                ]));
            }
            if ($name === 'create_soulbuddy_account') {
                $user = $accounts->create($principal, $args);

                return $this->rpc($id, $this->toolResponse([
                    'status' => 'linked',
                    'message' => 'A SoulBuddy account is associated with this provider identity.',
                ]));
            }
            if ($name === 'link_existing_soulbuddy_account') {
                $user = $accounts->link($principal, $args);

                return $this->rpc($id, $this->toolResponse([
                    'status' => 'linked',
                    'message' => 'The verified SoulBuddy account is now linked to this provider identity.',
                ]));
            }

            $user = $accounts->resolve($principal);
            if (! $user) {
                return $this->rpc($id, $this->toolError('No SoulBuddy account is linked to this identity. Choose to create a new account or link an existing verified account with its one-time code.'));
            }

            $result = match ($name) {
                'get_life_plan' => $planner->get($user, $args),
                'get_daily_life_plan' => $planner->daily($user),
                'list_life_plans' => $planner->history($user, $args),
                'create_seven_day_plan' => $planner->create($user, $args),
                'record_daily_checkin' => $planner->checkIn($user, $args),
                'review_week' => $planner->weeklySummary($user),
                'save_weekly_review' => $planner->saveReview($user, $args),
                'delete_life_plan' => $planner->delete($user, $args),
            };

            return $this->rpc($id, $this->toolResponse($result));
        } catch (ValidationException $exception) {
            return $this->rpc($id, $this->toolError(collect($exception->errors())->flatten()->first() ?: 'Invalid request.'));
        } catch (Throwable) {
            return $this->rpc($id, $this->toolError('SoulBuddy could not complete this request. Please retry later.'));
        }
    }

    private function rpc(mixed $id, mixed $result, ?int $error = null, ?string $message = null, int $status = 200): JsonResponse
    {
        return response()->json($error === null
            ? ['jsonrpc' => '2.0', 'id' => $id, 'result' => $result]
            : ['jsonrpc' => '2.0', 'id' => $id, 'error' => ['code' => $error, 'message' => $message]], $status)
            ->header('Cache-Control', 'no-store');
    }

    private function toolResponse(array $data): array
    {
        return [
            'structuredContent' => $data,
            'content' => [['type' => 'text', 'text' => json_encode($data, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE)]],
        ];
    }

    private function toolError(string $message, array $meta = []): array
    {
        return array_filter([
            'isError' => true,
            'content' => [['type' => 'text', 'text' => $message]],
            '_meta' => $meta ?: null,
        ], fn (mixed $value): bool => $value !== null);
    }

    private function tools(): array
    {
        $read = [['type' => 'oauth2', 'scopes' => ['life.read']]];
        $write = [['type' => 'oauth2', 'scopes' => ['life.write']]];
        $object = fn (array $properties, array $required = []): array => [
            'type' => 'object',
            'properties' => $properties ?: (object) [],
            'required' => $required,
            'additionalProperties' => false,
        ];
        $string = fn (string $description): array => ['type' => 'string', 'description' => $description];
        $confirmed = ['type' => 'boolean', 'const' => true, 'description' => 'True only after showing the exact proposed change and receiving the person’s explicit approval.'];
        $domains = LifePlannerService::DOMAINS;

        return [
            [
                'name' => 'get_account_link_status', 'title' => 'Check SoulBuddy account connection',
                'description' => 'Check whether this verified OAuth issuer and subject are linked. Does not create users or reveal personal data.',
                'inputSchema' => $object([]),
                'securitySchemes' => $read,
                'annotations' => ['readOnlyHint' => true, 'destructiveHint' => false, 'openWorldHint' => false],
            ],
            [
                'name' => 'create_soulbuddy_account', 'title' => 'Create my SoulBuddy account',
                'description' => 'Create an account only after explicit permission and a verified provider email. Never attach to existing accounts by email; if an account exists, use explicit linking instead.',
                'inputSchema' => $object(['confirmed' => $confirmed], ['confirmed']),
                'securitySchemes' => $write,
                'annotations' => ['readOnlyHint' => false, 'destructiveHint' => false, 'openWorldHint' => false],
            ],
            [
                'name' => 'link_existing_soulbuddy_account', 'title' => 'Link my existing SoulBuddy account',
                'description' => 'Connect a previously verified SoulBuddy account with a short-lived single-use code generated from its authenticated app account via POST /api/account/chatgpt/link-codes. Requires explicit user confirmation and matching verified email. Never claim a match from email alone.',
                'inputSchema' => $object([
                    'code' => ['type' => 'string', 'minLength' => 32, 'maxLength' => 32, 'description' => 'One-time 32-character hexadecimal code from the authenticated SoulBuddy account'],
                    'confirmed' => $confirmed,
                ], ['code', 'confirmed']),
                'securitySchemes' => $write,
                'annotations' => ['readOnlyHint' => false, 'destructiveHint' => false, 'openWorldHint' => false],
            ],
            [
                'name' => 'get_planning_guide', 'title' => 'Discover SoulBuddy planning',
                'description' => 'Explain the free planning approach without saving anything or requiring login.',
                'inputSchema' => $object([]),
                'securitySchemes' => [['type' => 'noauth']],
                'annotations' => ['readOnlyHint' => true, 'destructiveHint' => false, 'openWorldHint' => false],
            ],
            [
                'name' => 'get_connection_management', 'title' => 'Manage account access',
                'description' => 'Find verified identity-provider controls for ending the SoulBuddy application session. This does not itself revoke access.',
                'inputSchema' => $object([]),
                'securitySchemes' => [['type' => 'noauth']],
                'annotations' => ['readOnlyHint' => true, 'destructiveHint' => false, 'openWorldHint' => false],
            ],
            [
                'name' => 'get_life_plan', 'title' => 'View my seven-day plan',
                'description' => 'Read the signed-in person’s active plan, or a specified plan from their history.',
                'inputSchema' => $object(['plan_id' => ['type' => 'string', 'format' => 'uuid', 'description' => 'Optional plan ID from plan history']]),
                'securitySchemes' => $read,
                'annotations' => ['readOnlyHint' => true, 'destructiveHint' => false, 'openWorldHint' => false],
            ],
            [
                'name' => 'get_daily_life_plan', 'title' => 'View today’s commitments',
                'description' => 'Read today’s commitments in the plan’s time zone, or whether a plan is missing, upcoming, or finished. Excludes private notes and reflections.',
                'inputSchema' => $object([]),
                'securitySchemes' => $read,
                'annotations' => ['readOnlyHint' => true, 'destructiveHint' => false, 'openWorldHint' => false],
            ],
            [
                'name' => 'list_life_plans', 'title' => 'View my life plan history',
                'description' => 'List the signed-in person’s active and archived plans, including IDs for review or deletion.',
                'inputSchema' => $object(['page' => ['type' => 'integer', 'minimum' => 1, 'maximum' => 10000, 'description' => 'Page number, starting at 1']]),
                'securitySchemes' => $read,
                'annotations' => ['readOnlyHint' => true, 'destructiveHint' => false, 'openWorldHint' => false],
            ],
            [
                'name' => 'create_seven_day_plan', 'title' => 'Save my seven-day life plan',
                'description' => 'After user approval, save a practical seven-day plan. Ask about available time and priorities first. Never create generated prayers or claim spiritual scores. Use a fresh UUID request_id; reuse it for retries. Existing plans require explicitly approved replace_active.',
                'inputSchema' => $object([
                    'request_id' => ['type' => 'string', 'format' => 'uuid'],
                    'confirmed' => $confirmed,
                    'replace_active' => ['type' => 'boolean', 'description' => 'Explicitly replace the current active plan'],
                    'focus' => $string('Person-approved life priority, maximum 240 characters'),
                    'starts_on' => $string('First local date YYYY-MM-DD, today or up to 14 days ahead'),
                    'timezone' => $string('IANA timezone name, e.g. Africa/Lagos'),
                    'items' => ['type' => 'array', 'minItems' => 7, 'maxItems' => 35, 'items' => $object([
                        'day' => ['type' => 'integer', 'minimum' => 0, 'maximum' => 6],
                        'domain' => ['type' => 'string', 'enum' => $domains],
                        'title' => $string('Short, concrete, person-approved action; never a generated prayer'),
                        'minutes' => ['type' => 'integer', 'minimum' => 2, 'maximum' => 180],
                    ], ['day', 'domain', 'title', 'minutes'])],
                ], ['request_id', 'confirmed', 'focus', 'starts_on', 'timezone', 'items']),
                'securitySchemes' => $write,
                'annotations' => ['readOnlyHint' => false, 'destructiveHint' => true, 'openWorldHint' => false],
            ],
            [
                'name' => 'record_daily_checkin', 'title' => 'Record my daily check-in',
                'description' => 'Record or correct one commitment outcome only after the person confirms what to record. A missed commitment is never spiritual failure.',
                'inputSchema' => $object([
                    'item_id' => ['type' => 'string', 'format' => 'uuid'],
                    'outcome' => ['type' => 'string', 'enum' => ['done', 'partial', 'skipped']],
                    'note' => $string('Optional neutral observation in the person’s own words, maximum 300 characters; never ask for confessions'),
                    'confirmed' => $confirmed,
                ], ['item_id', 'outcome', 'confirmed']),
                'securitySchemes' => $write,
                'annotations' => ['readOnlyHint' => false, 'destructiveHint' => true, 'openWorldHint' => false],
            ],
            [
                'name' => 'review_week', 'title' => 'Reflect on my past week',
                'description' => 'Read observed outcomes and gentle reflection prompts. No ranking of character, virtue, or holiness.',
                'inputSchema' => $object([]),
                'securitySchemes' => $read,
                'annotations' => ['readOnlyHint' => true, 'destructiveHint' => false, 'openWorldHint' => false],
            ],
            [
                'name' => 'save_weekly_review', 'title' => 'Save my weekly reflection',
                'description' => 'Save only the reflection and next adjustment the person approved. Never invent personal reflections.',
                'inputSchema' => $object([
                    'plan_id' => ['type' => 'string', 'format' => 'uuid'],
                    'reflection' => $string('Person-authored summary, up to 2,000 characters'),
                    'next_adjustment' => $string('One person-approved change, up to 500 characters'),
                    'confirmed' => $confirmed,
                ], ['plan_id', 'reflection', 'next_adjustment', 'confirmed']),
                'securitySchemes' => $write,
                'annotations' => ['readOnlyHint' => false, 'destructiveHint' => true, 'openWorldHint' => false],
            ],
            [
                'name' => 'delete_life_plan', 'title' => 'Delete my life plan',
                'description' => 'Permanently delete a specific plan and all its check-ins/review ONLY after explicit informed confirmation.',
                'inputSchema' => $object([
                    'plan_id' => ['type' => 'string', 'format' => 'uuid'],
                    'confirmed' => $confirmed,
                ], ['plan_id', 'confirmed']),
                'securitySchemes' => $write,
                'annotations' => ['readOnlyHint' => false, 'destructiveHint' => true, 'openWorldHint' => false],
            ],
        ];
    }
}
