# WAPI WhatsApp Integration

## Overview

This feature integrates a self-hosted WhatsApp gateway (WAPI/whatsameow) directly into Chatwoot's inbox creation flow. It allows users to connect their own WhatsApp number without requiring a Meta Business API account.

WAPI devices are stored as `Channel::Api` channels with `wapi_device_id` inside `additional_attributes`. The integration handles the full lifecycle: device creation, WhatsApp pairing (QR or phone number), message routing (incoming + outgoing), and device management (reconnect/logout).

---

## Architecture

```
┌──────────────────┐       ┌──────────────────┐       ┌──────────────────┐
│                  │       │                  │       │                  │
│   Chatwoot UI    │──────▶│  Chatwoot API    │──────▶│   WAPI Server    │
│   (Vue.js)       │       │  (Rails)         │       │   (Go/whatsameow)│
│                  │◀──────│                  │◀──────│                  │
└──────────────────┘       └──────────────────┘       └──────────────────┘
                                    │                         │
                                    │                         ▼
                                    │                ┌──────────────────┐
                                    │                │                  │
                                    └───────────────▶│  WhatsApp Servers│
                                     channel.webhook │                  │
                                                     └──────────────────┘
```

### Message Flow

**Incoming (WhatsApp → Chatwoot):**
1. Contact sends WhatsApp message
2. WAPI receives it via whatsameow WebSocket
3. WAPI forwards to Chatwoot API using the configured `chatwoot_url` + `api_token`
4. Message appears in Chatwoot inbox

**Outgoing (Chatwoot → WhatsApp):**
1. Agent types message in Chatwoot
2. Chatwoot delivers webhook to `Channel::Api.webhook_url` via `deliver_api_inbox_webhooks`
3. WAPI receives webhook, matches `inbox_id` to device
4. WAPI sends message via WhatsApp

---

## Environment Variables

| Variable | Description | Example |
|---|---|---|
| `WAPI_BASE_URL` | URL of the WAPI server | `https://wapi.example.com` |
| `WAPI_BASIC_AUTH` | Base64-encoded `user:password` | `YWRtaW46cGFzc3dvcmQ=` |

Both are **required**. The controller returns `503 Service Unavailable` if either is missing.

---

## Files Modified/Created

### Backend (Ruby)

| File | Type | Description |
|---|---|---|
| `app/controllers/api/v1/accounts/wapi_controller.rb` | **NEW** | Main controller with 8 actions |
| `app/services/wapi/device_service.rb` | **NEW** | HTTP client for WAPI REST API |
| `lib/custom_exceptions/wapi_error.rb` | **NEW** | Custom exception class |
| `config/routes.rb` | MODIFIED | Added WAPI routes under accounts namespace |
| `spec/request/api/v1/accounts/wapi_spec.rb` | **NEW** | Request specs (261 examples) |

### Frontend (Vue.js)

| File | Type | Description |
|---|---|---|
| `app/javascript/dashboard/api/channel/wapiChannel.js` | **NEW** | API client for WAPI endpoints |
| `app/javascript/dashboard/routes/.../channels/WapiInbox.vue` | **NEW** | Inbox creation + QR/pairing flow |
| `app/javascript/dashboard/routes/.../channels/WapiSettings.vue` | **NEW** | Device info, reconnect, logout |
| `app/javascript/dashboard/components/widgets/ChannelItem.vue` | MODIFIED | Added WAPI channel type card |
| `app/javascript/dashboard/routes/.../ChannelFactory.vue` | MODIFIED | Route to WapiInbox component |
| `app/javascript/dashboard/routes/.../ConfigurationPage.vue` | MODIFIED | Show WapiSettings for WAPI inboxes |

### i18n

| File | Keys Added |
|---|---|
| `app/javascript/dashboard/i18n/locale/en/inboxMgmt.json` | `INBOX_MGMT.ADD.WAPI_INBOX.*`, `INBOX_MGMT.WAPI_SETTINGS.*` |
| `app/javascript/dashboard/i18n/locale/fr/inboxMgmt.json` | Same keys, French translations |

---

## API Endpoints

All endpoints are under `/api/v1/accounts/:account_id/wapi/`.

### POST `/wapi/create_inbox`

Creates a new Channel::Api inbox and registers a device on the WAPI server.

**Params:** `{ name: "Support WhatsApp" }`

**Flow:**
1. Creates `Channel::Api` with empty `webhook_url`
2. Creates inbox with the given name
3. Generates device ID: `cw-inbox-{inbox_id}`
4. Calls `POST /devices` on WAPI to register the device
5. Stores `wapi_device_id` in channel's `additional_attributes`

**Response:** `{ success: true, inbox_id: 63, device_id: "cw-inbox-63" }`

---

### GET `/wapi/qr?inbox_id=63`

Returns a QR code link for WhatsApp pairing.

**Response:** `{ success: true, qr: "https://wapi.../qrcode.png", qr_duration: 30 }`

---

### POST `/wapi/login_with_code`

Generates a pairing code for phone-number-based linking.

**Params:** `{ inbox_id: 63, phone: "22890000000" }`

**Response:** `{ success: true, pair_code: "ABCD-EFGH" }`

---

### GET `/wapi/status?inbox_id=63`

Checks the WhatsApp connection status.

**Response:** `{ success: true, status: "connected" }` or `{ success: true, status: "disconnected" }`

---

### POST `/wapi/connect`

Finalizes the connection after WhatsApp is paired. Saves the Chatwoot config on WAPI and stores the JID.

**Params:** `{ inbox_id: 63 }`

**Flow:**
1. Calls `PUT /devices/{device_id}/chatwoot` on WAPI with `chatwoot_url`, `api_token`, `account_id`, `inbox_id`
2. WAPI returns the WhatsApp JID (e.g., `22870111810@s.whatsapp.net`)
3. Sets `channel.webhook_url` to `{WAPI_BASE_URL}/chatwoot/webhook`
4. Stores JID in `channel.additional_attributes['wapi_jid']`

**Response:** `{ success: true, phone_number: "+22870111810", jid: "22870111810@s.whatsapp.net" }`

---

### GET `/wapi/device_info?inbox_id=63`

Returns device info for the inbox settings page.

**Response:**
```json
{
  "success": true,
  "device_id": "cw-inbox-63",
  "jid": "22870111810@s.whatsapp.net",
  "phone_number": "+22870111810",
  "is_connected": true
}
```

---

### POST `/wapi/reconnect`

Reconnects a disconnected WhatsApp session.

**Params:** `{ inbox_id: 63 }`
**Response:** `{ success: true }`

---

### POST `/wapi/logout`

Disconnects WhatsApp and clears the stored JID.

**Params:** `{ inbox_id: 63 }`

**Flow:**
1. Calls `GET /app/logout` on WAPI
2. Removes `wapi_jid` from channel's `additional_attributes`

**Response:** `{ success: true }`

---

## Frontend Components

### WapiInbox.vue — Inbox Creation Flow

**Step 1: Inbox Name**
- Input field for the inbox name
- On submit → calls `POST /wapi/create_inbox`

**Step 2: WhatsApp Pairing**
Two modes available:

1. **QR Code** (default)
   - Displays QR image from WAPI
   - Auto-refreshes every 30 seconds (QR expiry)
   - Polls status every 5 seconds

2. **Pairing Code** (phone number)
   - Uses `PhoneInput` component with country code selector
   - Formats number: strips `+` and `00` prefix, concatenates country code + number
   - Shows the 8-digit pairing code
   - Auto-refreshes code every 30 seconds
   - Polls status every 5 seconds

When status returns `connected` → auto-calls `POST /wapi/connect` → redirects to inbox settings.

### WapiSettings.vue — Inbox Settings

Displayed in the inbox Configuration tab for WAPI inboxes. Shows:

- **Device ID**: `cw-inbox-63`
- **WhatsApp Number**: `+22870111810`
- **Status**: Connected / Disconnected (with color indicator)
- **Reconnect** button: calls `POST /wapi/reconnect`
- **Logout** button: calls `POST /wapi/logout` (with confirmation)

### ChannelItem.vue

Added WAPI as a new channel type in the inbox creation flow:
- Title: "WhatsApp (Self-hosted)"
- Description: "Connect your own WhatsApp via WAPI (whatsameow). No Meta Business API required."
- Channel key: `wapi`

---

## Data Model

WAPI inboxes use `Channel::Api` as the underlying channel type. WAPI-specific data is stored in `additional_attributes`:

```json
{
  "wapi_device_id": "cw-inbox-63",
  "wapi_jid": "22870111810@s.whatsapp.net"
}
```

The `webhook_url` field on `Channel::Api` is set to `{WAPI_BASE_URL}/chatwoot/webhook` during the `connect` step. Chatwoot's built-in `deliver_api_inbox_webhooks` mechanism delivers outgoing messages to this URL.

### How WAPI inboxes are identified

A `Channel::Api` inbox is considered a WAPI inbox if `additional_attributes['wapi_device_id']` is present. This is checked in:
- `ChannelFactory.vue` to render `WapiInbox` instead of the default API flow
- `ConfigurationPage.vue` to show `WapiSettings` in the settings tab

---

## WAPI Server Communication

### DeviceService

`Wapi::DeviceService` is the HTTP client that talks to the WAPI REST API. It handles:

- Authentication via `Authorization: Basic {base64}` header
- Device scoping via `X-Device-Id` header
- JSON request/response parsing
- Error handling via `CustomExceptions::WapiError`
- Debug logging: all requests/responses are logged with `[WAPI]` prefix

### WAPI API Endpoints Used

| Method | WAPI Endpoint | Chatwoot Method |
|---|---|---|
| `POST` | `/devices` | `create_device(device_id)` |
| `GET` | `/app/login` | `get_qr(device_id)` |
| `GET` | `/app/login-with-code?phone=...` | `login_with_code(device_id, phone)` |
| `GET` | `/app/status` | `check_status(device_id)` |
| `PUT` | `/devices/{id}/chatwoot` | `save_chatwoot_config(...)` |
| `GET` | `/app/reconnect` | `reconnect(device_id)` |
| `GET` | `/app/logout` | `logout(device_id)` |

---

## Debugging

### Logs

All WAPI API calls are logged with the `[WAPI]` prefix:

```
[WAPI] PUT https://wapi.example.com/devices/cw-inbox-63/chatwoot device_id=cw-inbox-63 body={...}
[WAPI] Response 200: {"code":"SUCCESS","message":"Chatwoot configuration saved",...}
```

### Common Issues

| Symptom | Cause | Fix |
|---|---|---|
| `Invalid request body` on connect | `api_token` sent as full AR object | Use `current_user.access_token.token` |
| `401 Unauthorized` on webhook delivery | WAPI connection stale/dead | Reconnect device via WAPI |
| QR not loading | Device not registered on WAPI | Check `create_device` succeeded |
| Status shows connected but messages fail | WhatsApp WebSocket stale | Call reconnect, then retry |
| Translations not showing | i18n keys at wrong JSON level | `WAPI_INBOX` must be under `INBOX_MGMT.ADD` |

---

## Testing

### Running Specs

```bash
bundle exec rspec spec/request/api/v1/accounts/wapi_spec.rb
```

261 examples covering all endpoints, authentication, error handling, and environment validation.

### Manual Testing

1. Set env vars: `WAPI_BASE_URL`, `WAPI_BASIC_AUTH`
2. Create inbox via UI: Settings → Inboxes → Add → WhatsApp (Self-hosted)
3. Scan QR or enter phone number
4. Wait for auto-connection
5. Send/receive messages
6. Check settings: reconnect/logout
