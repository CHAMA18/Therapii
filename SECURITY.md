# Security Best Practices for Therapii

## Overview
This document outlines security best practices for maintaining the Therapii application, with a focus on protecting sensitive data and API keys.

## 🔐 API Keys & Secrets Management

### ✅ DO:
- Store all API keys in **Firebase Secret Manager**
- Use environment variables for configuration
- Configure secrets through Admin Settings UI when appropriate
- Rotate keys regularly (every 90 days recommended)
- Use separate keys for development and production
- Monitor API usage through provider dashboards

### ❌ DON'T:
- Never commit API keys to source control
- Never hardcode secrets in source code
- Never share secrets via email or chat
- Never use production keys in development
- Never log full API keys (only last 4 characters if needed)

## 🔒 Exposed Key Response Protocol

If an API key is accidentally exposed:

1. **Immediate Action (Within 1 hour)**
   - Revoke the exposed key in the service provider dashboard
   - Generate a new key
   - Update Firebase secrets with the new key
   - Deploy updated functions

2. **Investigation (Within 24 hours)**
   - Review logs for unauthorized usage
   - Check for financial impact (for payment keys)
   - Identify how the exposure occurred

3. **Prevention (Within 1 week)**
   - Update processes to prevent recurrence
   - Review all other keys for potential exposure
   - Update team training if needed

## 🛡️ Current Security Implementation

### Stripe Integration
- ✅ Secret key stored in Firebase Secret Manager (`STRIPE_SECRET_KEY`)
- ✅ Checkout sessions created server-side via Cloud Functions
- ✅ Client never sees or handles secret keys
- ✅ Price IDs are safe to expose (public identifiers)

### OpenAI Integration
- ✅ API key fetched from environment variables or Firestore
- ✅ Requests proxied through Cloud Functions
- ✅ Client never directly calls OpenAI API
- ✅ Admin-only configuration through secure UI

### Firebase
- ✅ Security rules enforce proper access control
- ✅ Authentication required for sensitive operations
- ✅ User data access restricted to authorized users
- ✅ Therapist-patient relationships validated

## 📋 Security Checklist

Before deploying to production:

- [ ] All API keys removed from source code
- [ ] Firebase secrets configured for all required services
- [ ] .gitignore properly configured
- [ ] Security rules tested and validated
- [ ] Admin access properly restricted
- [ ] User authentication flows tested
- [ ] Payment flows tested in Stripe test mode
- [ ] Error messages don't expose sensitive information
- [ ] Logs don't contain sensitive data

## 🔍 Regular Security Audits

Perform these checks monthly:

- [ ] Review Firebase console for unusual activity
- [ ] Check Stripe dashboard for suspicious transactions
- [ ] Verify OpenAI usage is within expected parameters
- [ ] Review Cloud Function logs for errors or attacks
- [ ] Update dependencies to patch security vulnerabilities
- [ ] Rotate API keys if any team member leaves

## 📞 Security Incident Contact

If you discover a security vulnerability:

1. **Do not** create a public GitHub issue
2. Email security concerns to: [Your security contact email]
3. Include detailed information about the vulnerability
4. Allow 48 hours for initial response

## 🔗 Additional Resources

- [Firebase Security Documentation](https://firebase.google.com/docs/rules)
- [Stripe Security Best Practices](https://stripe.com/docs/security)
- [OWASP Top Ten](https://owasp.org/www-project-top-ten/)
- [Firebase Secret Manager](https://firebase.google.com/docs/functions/config-env#secret-manager)

---

**Last Updated:** December 2024  
**Review Schedule:** Quarterly
