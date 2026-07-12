# Telegram Bot API Integration

## Overview

The Telegram Bot API is used for sending real-time notifications, alerts, and daily digests to the platform operator. It is a lightweight integration — the platform sends messages only (outbound). No inbound command processing is required for the core workflow, though the bot can optionally support `/status` and `/pause` commands via webhook callbacks.

The integration uses the Telegram Bot HTTP API directly through Make.com HTTP modules. No SDK is required. All API calls go to `https://api.telegram.org/bot<token>/<method>`.

---

## Bot Setup

### Creating a Bot

1. In Telegram, search for **BotFather** (`@BotFather`)
2. Send `/newbot`
3. Choose a display name: `Jasfo Lead Bot`
4. Choose a username: `jasfo_lead_bot`
5. Save the API token: `123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11`

### Getting Your Chat ID

```
GET https://api.telegram.org/bot<token>/getUpdates
```

Send `/start` to the bot, then call the above URL. The response contains your chat ID:

```json
{
  "result": [{
    "message": {
      "chat": {
        "id": 123456789,
        "type": "private"
      }
    }
  }]
}
```

---

## Methods

### sendMessage

Primary method for sending text notifications.

```
POST https://api.telegram.org/bot<token>/sendMessage
Content-Type: application/json

{
  "chat_id": 123456789,
  "text": "🔔 **High-Intent Lead Detected**\n\nJohn Smith — CTO at Acme Corp",
  "parse_mode": "MarkdownV2",
  "disable_web_page_preview": true,
  "reply_markup": {
    "inline_keyboard": [[
      { "text": "View Lead", "url": "https://app.jasfo.com/lead/..." },
      { "text": "Dismiss", "callback_data": "dismiss:..." }
    ]]
  }
}
```

**Parameters**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `chat_id` | Yes | Target chat ID |
| `text` | Yes | Message text (max 4096 chars) |
| `parse_mode` | No | `MarkdownV2` or `HTML` |
| `disable_web_page_preview` | No | Suppress link previews |
| `disable_notification` | No | Send silently |
| `reply_markup` | No | Inline keyboard JSON |

### sendDocument

Used for sending exported files (PDF reports, CSV exports).

```
POST https://api.telegram.org/bot<token>/sendDocument
Content-Type: multipart/form-data

{
  "chat_id": 123456789,
  "document": "https://storage.jasfo.com/exports/report-123.pdf",
  "caption": "Lead Intelligence Report — John Smith"
}
```

### editMessageText

Update an existing notification (e.g., resolve an alert).

```
POST https://api.telegram.org/bot<token>/editMessageText
Content-Type: application/json

{
  "chat_id": 123456789,
  "message_id": 42,
  "text": "✅ ~~Error~~ Resolved\n\n...",
  "parse_mode": "MarkdownV2"
}
```

### answerCallbackQuery

Respond to inline keyboard button presses.

```
POST https://api.telegram.org/bot<token>/answerCallbackQuery
Content-Type: application/json

{
  "callback_query_id": "123456",
  "text": "Alert dismissed",
  "show_alert": false
}
```

---

## MarkdownV2 Formatting

The platform uses Telegram's MarkdownV2 parse mode. Characters must be escaped with `\`:

### Escape Rules

| Character | Escape |
|-----------|--------|
| `_` | `\_` |
| `*` | `\*` |
| `[` | `\[` |
| `]` | `\]` |
| `(` | `\(` |
| `)` | `\)` |
| `~` | `\~` |
| `` ` `` | `` \` `` |
| `>` | `\>` |
| `#` | `\#` |
| `+` | `\+` |
| `-` | `\-` |
| `=` | `\=` |
| `|` | `\|` |
| `{` | `\{` |
| `}` | `\}` |
| `.` | `\.` |
| `!` | `\!` |

### Formatting Syntax

| Style | Syntax |
|-------|--------|
| Bold | `*text*` |
| Italic | `_text_` or `\_text\_` |
| Code | `` `code` `` |
| Pre | `` ```code``` `` |
| Link | `[text](url)` |
| Strikethrough | `~text~` |
| Spoiler | `||text||` |

---

## Inline Keyboards

Inline keyboards provide action buttons on notifications.

```json
{
  "reply_markup": {
    "inline_keyboard": [
      [
        { "text": "🔍 View Lead", "url": "https://app.jasfo.com/lead/0194f1c0..." },
        { "text": "⏸ Pause", "callback_data": "pause:apollo" }
      ],
      [
        { "text": "📊 Dashboard", "url": "https://app.jasfo.com/dashboard" },
        { "text": "✅ Dismiss", "callback_data": "dismiss:alert-123" }
      ]
    ]
  }
}
```

---

## Rate Limits

| Constraint | Limit |
|-----------|-------|
| Messages per second (per chat) | ~30 |
| Messages per minute (per chat) | ~20 |
| Group messages per minute | 20 (N/A — single chat only) |
| Message length | 4,096 characters |
| Caption length | 1,024 characters |
| Callback data length | 64 bytes |

Messages exceeding 4,096 characters are split into multiple messages using the platform's message chunking utility.

---

## Implementation in Make.com

### Send Notification Module

| Field | Value |
|-------|-------|
| Method | `sendMessage` |
| URL | `https://api.telegram.org/bot{{tgToken}}/sendMessage` |
| Body | JSON from template |
| Parse Mode | `MarkdownV2` |

### Error Handling

| HTTP Status | Handling |
|-------------|----------|
| `200` | Message sent |
| `400` | Bad request — check formatting |
| `401` | Invalid token — alert admin |
| `403` | Bot blocked by user — stop notifications |
| `429` | Retry-After header — wait before resending |
