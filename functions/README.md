Therapii Cloud Functions — Deployment Guide

This folder contains Firebase Cloud Functions for invitations, AI chat, and related backend tasks. All secrets are now loaded from environment/config and no secrets are stored in source code.

Functions overview (all are HTTPS Callable):
- createInvitationAndSendEmail: Auth required. Creates an invitation and optionally emails the patient.
- deleteInvitation: Auth required. Therapist deletes an unused invitation they own.
- getTherapistInvitations: Auth required. Lists invitations for the signed-in therapist.
- getAcceptedInvitationsForTherapist: Auth required. Lists accepted invitations for therapist.
- getAcceptedInvitationsForPatient: Auth required. Lists accepted invitations for patient.
- previewInvitationByCode: Public. Returns sanitized info when the code is unused and not expired.
- validateAndUseInvitation: Auth required. Atomically consumes a valid invitation code.
- saveAiConversationSummary: Auth required. Saves AI summary for a patient linked to a therapist.
- generateAiChatCompletion: Auth required. Calls OpenAI Chat Completions.

Before you begin
- Firebase project is already connected to the app.
- Node.js 20 is required (engines.node=20 is set).
- Blaze plan is recommended to allow outbound networking (SendGrid/OpenAI).
- SendGrid sender identity must be verified (From address must be verified).

1) Install dependencies
- From the functions directory:
  - npm install

2) Configure runtime settings (no secrets in code)
- Option A: Firebase Runtime Config (recommended here and used by index.js):
  - firebase functions:config:set \
      sendgrid.key="YOUR_SENDGRID_API_KEY" \
      sendgrid.from="verified-sender@example.com" \
      openai.key="YOUR_OPENAI_API_KEY" \
      openai.base_url="https://api.openai.com/v1" \
      app.email_delivery_enabled="true"

- Option B: Environment variables (supported by index.js):
  - SENDGRID_API_KEY=...  SENDGRID_FROM_EMAIL=...  OPENAI_API_KEY=...  OPENAI_BASE_URL=...  EMAIL_DELIVERY_ENABLED=true
  - Note: When deploying with Firebase CLI, prefer Option A. Generic env vars are primarily for local runs.

3) Deploy
- From the project root (where firebase.json exists):
  - Deploy all functions: firebase deploy --only functions
  - Or deploy individual functions: firebase deploy --only functions:createInvitationAndSendEmail

4) Verify deployment
- In Firebase Console > Build > Functions, ensure functions are Active.
- Check Logs for any startup/config errors.

Email delivery toggle
- index.js respects a boolean flag:
  - app.email_delivery_enabled=true (via functions:config) OR
  - EMAIL_DELIVERY_ENABLED=true (env var)
- If disabled or SendGrid config is missing, the function will create the invitation but skip the email.

Security and data
- All callable functions enforce Firebase Authentication.
- createInvitationAndSendEmail ensures the caller’s uid matches therapistId.
- No composite indexes are required by these queries (sorting is done server-side after fetch).

Local testing (optional)
- Start only the Functions emulator: firebase emulators:start --only functions
- Point the Flutter app to the emulator in debug builds if needed.

Troubleshooting
- PermissionDenied: Ensure the caller is authenticated; check therapistId matches auth uid.
- OpenAI errors: Confirm openai.key and that outbound networking is allowed (Blaze plan).
- SendGrid errors: Verify sender address/domain and API key permissions.

Notes
- Secrets must not be committed to version control. They are provided via config/env only.
- Region defaults to us-central1. If you need a different region, wrap exports with functions.region('your-region').
