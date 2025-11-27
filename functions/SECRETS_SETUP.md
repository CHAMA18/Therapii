# Firebase Secrets Configuration

## Overview
This document explains how to securely configure API keys and secrets for your Firebase Cloud Functions using Firebase's secret management system.

## Required Secrets

### 1. STRIPE_SECRET_KEY (Required)
Your Stripe secret key for payment processing.

**To set up:**
```bash
firebase functions:secrets:set STRIPE_SECRET_KEY
```

When prompted, paste your Stripe secret key (starts with `sk_live_` for production or `sk_test_` for testing).

**Important:** Never commit this key to source control!

### 2. OPENAI_API_KEY (Optional)
Your OpenAI API key for AI chat functionality.

**To set up:**
```bash
firebase functions:secrets:set OPENAI_API_KEY
```

When prompted, paste your OpenAI API key (starts with `sk-`).

**Note:** Alternatively, you can configure this through the Admin Settings page in your app, which stores it securely in Firestore.

## Deploying with Secrets

After setting secrets, deploy your functions:

```bash
firebase deploy --only functions
```

## Verifying Secrets

To view which secrets are configured (without seeing their values):

```bash
firebase functions:secrets:access
```

## Best Practices

1. **Never hardcode secrets** in your source code
2. **Use environment-specific secrets** (separate keys for development and production)
3. **Rotate secrets regularly** for security
4. **Limit access** to secrets to only the functions that need them
5. **Monitor usage** through your service provider dashboards (Stripe, OpenAI, etc.)

## Revoking Exposed Keys

If you accidentally exposed a key in your code:

1. **Immediately revoke** the exposed key in your service provider dashboard
2. **Generate a new key** in your provider dashboard
3. **Update the secret** using `firebase functions:secrets:set`
4. **Redeploy functions** with `firebase deploy --only functions`
5. **Remove the exposed key** from your code and commit history if possible

## Additional Resources

- [Firebase Secret Manager Documentation](https://firebase.google.com/docs/functions/config-env#secret-manager)
- [Stripe API Keys](https://dashboard.stripe.com/apikeys)
- [OpenAI API Keys](https://platform.openai.com/api-keys)
