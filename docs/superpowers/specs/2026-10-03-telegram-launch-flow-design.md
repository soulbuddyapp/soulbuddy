# Telegram launch flow

## Goal

Let a person begin SoulBuddy on Telegram from the mobile or web app, understand the required Telegram action, and receive a verified completion state without exposing private spiritual records.

## Chosen approach

Use one shared Flutter launch flow. It creates a short-lived server code, presents a three-step guide, opens the bot's `start` URL, and polls the authenticated server for the code state after the app returns to the foreground.

The existing webhook remains the authority for completion. It verifies Telegram's secret header, consumes a code once, and binds one private chat to one SoulBuddy user. The app never receives the Telegram bot token, chat identifier, or webhook secret.

## Flow

1. The person selects `Connect Telegram`.
2. SoulBuddy creates a fresh code valid for ten minutes and displays:
   - Open SoulBuddy on Telegram.
   - Select Start.
   - Return after the confirmation message.
3. The app opens `https://t.me/soul_buddy_bot?start=<code>`.
4. The Telegram webhook consumes the code and sends `SoulBuddy connected. Daily notes are off.`
5. When the app resumes, it checks the code state. A consumed code shows a connected state; a valid unconsumed code remains actionable until expiry; an expired code offers a fresh launch.

## API

- `POST /api/companions/telegram/link-codes`: authenticated; returns code, expiry, bot start URL, and initial status.
- `GET /api/companions/telegram/link-codes/{id}`: authenticated; returns only the current caller's code status.
- `POST /integrations/telegram/webhook`: Telegram-only; validates the configured secret and consumes the code.

Codes are random 256-bit values. The database stores only SHA-256 hashes. Status queries are scoped to the issuing user and return no chat metadata.

## Failure handling

- Missing bot configuration: show a concise unavailable state; do not issue a code.
- Telegram cannot open: keep the active code and offer a retry.
- Code expires or has been superseded: create a new code.
- The app is closed: reopening Settings retrieves the latest known status from the server.

## Testing

Feature tests cover ownership-scoped status, expiry, one-time consumption, webhook-secret rejection, and bot acknowledgement. Widget tests cover the three-step guide, external launch, app-resume confirmation, retry, and unavailable states.
