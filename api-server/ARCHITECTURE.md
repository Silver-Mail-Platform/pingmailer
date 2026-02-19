# Architecture & Flow Diagrams

## Dual Authentication Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Dual Authentication Flow                         │
└─────────────────────────────────────────────────────────────────────────┘

1. APPLICATION AUTHENTICATION (OAuth2 Client Credentials)
   ┌──────────┐                                    ┌──────────────┐
   │  Client  │──── POST /oauth2/token ───────────▶│ OAuth2       │
   │  App     │     grant_type=client_credentials  │ Server       │
   └──────────┘     Basic Auth: client_id:secret   └──────────────┘
        │                                                   │
        │                                                   │
        │◀────── access_token (JWT) ────────────────────────┘
        │         expires_in: 3600
        │
        │
2. API REQUEST WITH DUAL AUTHENTICATION
        │
        ▼
   ┌──────────┐
   │  Client  │
   │  App     │──┐
   └──────────┘  │
                 │  POST /notify
                 │  Headers:
                 │    - Authorization: Bearer <access_token>  ◄── App Auth
                 │    - Content-Type: application/json
                 │  Body:
                 │    {
                 │      "smtp_host": "smtp.gmail.com",
                 │      "smtp_port": 587,
                 │      "smtp_username": "user@gmail.com",      ◄─┐
                 │      "smtp_password": "user_app_password",     │ User Auth
                 │      "smtp_sender": "user@gmail.com",        ◄─┘
                 │      "recipient_email": "to@example.com"
                 │    }
                 │
                 ▼
        ┌────────────────┐
        │  API Server    │
        │  (PingMailer)  │
        └────────────────┘
                 │
                 │
3. VALIDATION STEPS
                 │
                 ├─▶ Validate Bearer Token ────────┐
                 │   - Extract from Authorization   │
                 │   - Call introspection endpoint  │
                 │   - Verify active=true           │
                 │   - Check expiration             │
                 │                                  │
                 │   POST /oauth2/introspect        │
                 │   ─────────────────────────────▶ │
                 │                                  │
                 │   {                              │
                 │     "active": true,              │
                 │     "client_id": "...",          │
                 │     "exp": 1771499415            │
                 │   }                              │
                 │   ◀─────────────────────────────┘
                 │
                 │   If Invalid → 401 Unauthorized
                 │
                 │   If Valid ↓
                 │
                 ├─▶ Validate Request Body ────────┐
                 │   - Check required fields        │
                 │   - Validate email formats       │
                 │                                  │
                 │   ◀────── Valid/Invalid ─────────┘
                 │
                 │   If Invalid → 400 Bad Request
                 │
                 │   If Valid ↓
                 │
4. EMAIL SENDING (Asynchronous)
                 │
                 ├─▶ Queue Email ──────────────────┐
                 │                                  │
                 └─▶ Return 200 OK                 │
                                                    │
                     ┌──────────────────────────────┘
                     │
                     ▼
              ┌──────────────┐
              │  Go Routine  │
              │  (Async)     │
              └──────────────┘
                     │
                     │  Connect to SMTP Server
                     │  Using user credentials:
                     │    - smtp_username
                     │    - smtp_password
                     │
                     ▼
              ┌──────────────┐
              │ SMTP Server  │
              │ (Gmail, etc) │
              └──────────────┘
                     │
                     │  Authenticate User ◄── User-level Auth
                     │
                     ├─▶ Success → Email Sent
                     │
                     └─▶ Failure → Logged to server logs
```

## Component Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         System Components                           │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────┐
│   Client            │  Examples: Web App, Mobile App, CLI Tool
│   Applications      │  Responsibilities:
└─────────────────────┘  - Obtain OAuth2 token
          │              - Make authenticated API calls
          │              - Provide user SMTP credentials
          │
          │ (1) Request Access Token
          │     POST /oauth2/token
          │     Basic Auth: client_id:client_secret
          │
          ▼
┌─────────────────────┐
│   OAuth2 Server     │  Responsibilities:
│   (Port 8090)       │  - Issue access tokens
└─────────────────────┘  - Validate client credentials
          │              - Manage token lifecycle
          │
          │ (2) Return access_token
          │
          ▼
┌─────────────────────┐
│   Client            │
│   Applications      │
└─────────────────────┘
          │
          │ (3) POST /notify
          │     Authorization: Bearer <token>
          │     Body: { smtp_*, recipient_* }
          │
          ▼
┌─────────────────────┐
│   API Server        │  Components:
│   (Port 8080/8443)  │  ┌─────────────────────┐
└─────────────────────┘  │ auth.go             │
          │              │ - extractBearerToken│
          │              │ - validateAccessToken│
          │              │ - authMiddleware    │
          │              │ - Token caching     │
          │              └─────────────────────┘
          │              ┌─────────────────────┐
          ├─────────────▶│ routes.go           │
          │              │ - /notify (auth)    │
          │              │ - /health (no auth) │
          │              └─────────────────────┘
          │              ┌─────────────────────┐
          │              │ handlers.go         │
          │              │ - handleNotify      │
          │              │ - handleHealth      │
          │              │ - Validation        │
          │              └─────────────────────┘
          │              ┌─────────────────────┐
          │              │ emailer/            │
          │              │ - Mailer            │
          │              │ - Templates         │
          │              └─────────────────────┘
          │
          │ (4) Connect & Authenticate
          │     Using user SMTP credentials
          │
          ▼
┌─────────────────────┐
│   SMTP Server       │  Examples: Gmail, SendGrid, Silver SMTP
│   (Port 587/465)    │  Responsibilities:
└─────────────────────┘  - Authenticate user (smtp_username/password)
                         - Send email
                         - Return success/failure
```

## Security Layers

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Security Layers                            │
└─────────────────────────────────────────────────────────────────────┘

Layer 1: TRANSPORT SECURITY
┌─────────────────────────────────────────────────────────────────────┐
│  HTTPS/TLS                                                          │
│  - Encrypts all data in transit                                     │
│  - Protects tokens and credentials                                  │
└─────────────────────────────────────────────────────────────────────┘

Layer 2: APPLICATION AUTHENTICATION
┌─────────────────────────────────────────────────────────────────────┐
│  OAuth2 Bearer Token                                                │
│  - Validates calling application                                    │
│  - Ensures request from trusted app                                 │
│  - Prevents unauthorized apps from using API                        │
│                                                                     │
│  Validation:                                                        │
│    1. Extract token from Authorization header                       │
│    2. Compare with valid application token                          │
│    3. Check expiration                                              │
│    4. Reject if invalid → 401 Unauthorized                          │
└─────────────────────────────────────────────────────────────────────┘

Layer 3: USER AUTHENTICATION
┌─────────────────────────────────────────────────────────────────────┐
│  SMTP Credentials                                                   │
│  - Authenticates end user                                           │
│  - Validates against SMTP server                                    │
│  - User-specific sending permissions                                │
│                                                                     │
│  Credentials in Request Body:                                       │
│    - smtp_username                                                  │
│    - smtp_password                                                  │
│                                                                     │
│  Validation:                                                        │
│    1. SMTP server authenticates user                                │
│    2. Verifies sending permissions                                  │
│    3. Reject if invalid → Email sending fails                       │
└─────────────────────────────────────────────────────────────────────┘

Layer 4: INPUT VALIDATION
┌─────────────────────────────────────────────────────────────────────┐
│  Request Validation                                                 │
│  - Required field checks                                            │
│  - Email format validation                                          │
│  - Data type validation                                             │
│  - Reject if invalid → 400 Bad Request                              │
└─────────────────────────────────────────────────────────────────────┘
```

## Token Lifecycle

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Access Token Lifecycle                           │
└─────────────────────────────────────────────────────────────────────┘

1. TOKEN ACQUISITION
   Client App → OAuth2 Server
   ┌─────────────────────────────────────────┐
   │ POST /oauth2/token                      │
   │ grant_type=client_credentials           │
   │ Basic Auth: client_id:client_secret     │
   └─────────────────────────────────────────┘
                    ↓
   ┌─────────────────────────────────────────┐
   │ Response:                               │
   │ {                                       │
   │   "access_token": "eyJ...",             │
   │   "token_type": "Bearer",               │
   │   "expires_in": 3600                    │
   │ }                                       │
   └─────────────────────────────────────────┘

2. TOKEN CACHING (Server-side)
   API Server caches token internally
   ┌─────────────────────────────────────────┐
   │ tokenCache = {                          │
   │   Token: "eyJ...",                      │
   │   ExpiresAt: now + (expires_in * 90%)   │
   │ }                                       │
   │                                         │
   │ Cache duration: 90% of expires_in       │
   │ Example: 3600s * 90% = 3240s = 54min    │
   └─────────────────────────────────────────┘

3. TOKEN USAGE
   Client App → API Server
   ┌─────────────────────────────────────────┐
   │ POST /notify                            │
   │ Authorization: Bearer eyJ...            │
   └─────────────────────────────────────────┘
                    ↓
   API Server validates token:
   ┌─────────────────────────────────────────┐
   │ 1. Extract from header                  │
   │ 2. Compare with cached token            │
   │ 3. Check expiration                     │
   │                                         │
   │ Valid? → Process request                │
   │ Invalid/Expired? → 401 Unauthorized     │
   └─────────────────────────────────────────┘

4. TOKEN REFRESH (Automatic)
   When cached token expires:
   ┌─────────────────────────────────────────┐
   │ Time > ExpiresAt?                       │
   │   Yes → Fetch new token from OAuth2     │
   │   No  → Use cached token                │
   └─────────────────────────────────────────┘

5. TOKEN EXPIRATION
   ┌─────────────────────────────────────────┐
   │ Client must get new token when:         │
   │ - Client's token expires                │
   │ - OAuth2 server invalidates token       │
   │ - Client receives 401 from API          │
   └─────────────────────────────────────────┘
```

## Error Handling Flow

```
Request → API Server
   │
   ├─ No Authorization header? → 401 "missing Authorization header"
   │
   ├─ Invalid header format? → 401 "invalid Authorization header format"
   │
   ├─ Invalid/expired token? → 401 "invalid or expired token"
   │
   ├─ Missing required fields? → 400 "Missing required field: X"
   │
   ├─ Invalid email format? → 400 "Invalid X email format"
   │
   ├─ Invalid JSON? → 400 "Invalid request body"
   │
   └─ All valid? → 200 OK (email queued)
                      │
                      └─ Async email sending
                            │
                            ├─ SMTP auth failure → Logged (not returned to client)
                            │
                            └─ SMTP success → Email sent
```

## Data Flow

```
┌────────────┐         ┌────────────┐         ┌────────────┐
│   Client   │         │  OAuth2    │         │    API     │
│    App     │         │  Server    │         │   Server   │
└────────────┘         └────────────┘         └────────────┘
      │                      │                       │
      │  1. Get Token        │                       │
      │─────────────────────▶│                       │
      │                      │                       │
      │  2. Token Response   │                       │
      │◀─────────────────────│                       │
      │                      │                       │
      │  3. API Request      │                       │
      │  (Bearer + SMTP)     │                       │
      │──────────────────────────────────────────────▶│
      │                      │                       │
      │                      │  4. Validate Token    │
      │                      │◀──────────────────────│
      │                      │                       │
      │                      │  (Server fetches own  │
      │                      │   token if needed)    │
      │                      │                       │
      │  5. Response (200)   │                       │
      │◀──────────────────────────────────────────────│
      │                      │                       │
      │                      │                       │ 6. Async
      │                      │                       │    Email
      │                      │                       │─────┐
      │                      │                       │     │
      │                      │                       │◀────┘
      │                      │                       │
                                                     │
                                                     │ 7. SMTP
                                                     │
                                              ┌──────▼──────┐
                                              │    SMTP     │
                                              │   Server    │
                                              └─────────────┘
```
