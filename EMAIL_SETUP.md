# Email Setup with Firebase Extension + Resend

This app uses the **Firebase "Trigger Email from Firestore" Extension** with **Resend SMTP** for sending invitation emails.

## Why This Approach?

- ✅ No SendGrid costs or complexity
- ✅ Generous Resend free tier (3,000 emails/month)
- ✅ Simple SMTP configuration
- ✅ Automatic retry logic via Firebase Extension
- ✅ Email delivery monitoring in Firebase Console

## Setup Instructions

### 1. Create Resend Account

1. Sign up at [resend.com](https://resend.com)
2. Go to **API Keys** → Create new API key
3. Copy your API key (starts with `re_`)

**Resend SMTP Credentials:**
- Host: `smtp.resend.com`
- Port: `465` (SSL) or `587` (TLS)
- Username: `resend`
- Password: Your API key

### 2. Install Firebase Extension

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to **Extensions** → **Install Extension**
4. Search for **"Trigger Email from Firestore"**
5. Click **Install**

### 3. Configure the Extension

During installation, provide these settings:

| Setting | Value |
|---------|-------|
| **Collection path** | `mail` |
| **SMTP connection URI** | `smtps://resend:YOUR_API_KEY@smtp.resend.com:465` |
| **Email documents collection** | `mail` |
| **Default FROM address** | `noreply@yourdomain.com` |
| **Users collection** | `users` (optional) |
| **Templates collection** | Leave empty |

**SMTP Connection URI Format:**
```
smtps://resend:YOUR_RESEND_API_KEY@smtp.resend.com:465
```

Replace `YOUR_RESEND_API_KEY` with your actual Resend API key.

### 4. Verify Domain (Production Only)

For production, verify your domain in Resend:

1. In Resend Dashboard → **Domains**
2. Click **Add Domain**
3. Add your domain (e.g., `therapii.app`)
4. Add the DNS records shown to your domain provider
5. Wait for verification (usually < 5 minutes)

For development/testing, you can use Resend's test domain (`@resend.dev`) without verification.

### 5. Configure App Settings

1. Open the app and sign in as admin
2. Navigate to **Admin Dashboard** → **Admin Settings**
3. Scroll to **Email Configuration**
4. Enter:
   - **From Email**: `noreply@yourdomain.com` (must match verified domain)
   - **From Name**: `Therapii` (or your app name)
5. Enable **Email delivery**
6. Click **Save Email Config**

### 6. Deploy Cloud Functions

The Cloud Functions have been updated to write email documents to the `mail` collection instead of calling SendGrid directly.

Deploy the updated functions:

```bash
firebase deploy --only functions
```

Or if you have specific functions to deploy:

```bash
firebase deploy --only functions:createInvitationAndSendEmail
```

## How It Works

1. **Therapist creates invitation** → Cloud Function generates code
2. **Function writes email document** to `mail` collection in Firestore
3. **Firebase Extension monitors** `mail` collection
4. **Extension sends email** via Resend SMTP
5. **Extension updates document** with delivery status

### Email Document Structure

```javascript
{
  to: ["patient@example.com"],
  message: {
    subject: "Your Unique Therapii Connection Code",
    text: "Hello...",
    html: "<p>Hello...</p>"
  },
  from: "Therapii <noreply@therapii.app>",
  createdAt: Timestamp,
  metadata: {
    invitationId: "abc123",
    code: "12345",
    patientFirstName: "John"
  }
}
```

After the extension processes the email, it adds:
- `delivery.state`: "SUCCESS" | "ERROR"
- `delivery.error`: error message (if failed)
- `delivery.attempts`: number of retry attempts

## Testing

1. Create a test invitation from the app
2. Check Firestore `mail` collection for the email document
3. Monitor the document for `delivery` field updates
4. Check Resend Dashboard → **Emails** for delivery logs

## Troubleshooting

### Emails not sending?

1. **Check Extension logs:**
   - Firebase Console → Extensions → View logs
   
2. **Verify SMTP credentials:**
   - Test SMTP connection: `telnet smtp.resend.com 465`
   - Confirm API key is valid in Resend Dashboard

3. **Check Firestore Security Rules:**
   - Extension needs write access to `mail` collection
   - Add rule: `allow write: if request.auth != null;`

4. **Review email document:**
   - Check `mail` collection in Firestore
   - Look for `delivery.error` field for error messages

### Common Issues

**"Authentication failed"**
- Wrong API key in SMTP URI
- API key expired or revoked
- Check Resend Dashboard → API Keys

**"Domain not verified"**
- Using unverified domain in production
- Verify domain in Resend or use `@resend.dev` for testing

**"Rate limit exceeded"**
- Exceeded Resend free tier (3,000/month)
- Upgrade Resend plan or throttle invitations

## Cost Comparison

| Provider | Free Tier | Cost After |
|----------|-----------|------------|
| **Resend** | 3,000 emails/month | \$20/month for 50,000 |
| SendGrid | 100 emails/day | \$19.95/month for 50,000 |

## Support

- Resend Docs: [resend.com/docs](https://resend.com/docs)
- Firebase Extension: [extensions.dev/extensions/firebase/firestore-send-email](https://extensions.dev/extensions/firebase/firestore-send-email)
- Therapii Support: support@therapii.com
