const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const { Resend } = require('resend');

admin.initializeApp();

// Resend API configuration
const RESEND_API_KEY = process.env.RESEND_API_KEY || 're_EkWubvjF_N4qqb9JD1BHkTuNZ2acKEwD9';
const RESEND_FROM_EMAIL = 'updates@updates.trytherapii.com';

/**
 * Get Stripe instance with secret key from environment
 * IMPORTANT: Never hardcode API keys in source code
 */
function getStripe() {
  const secretKey = process.env.STRIPE_SECRET_KEY;
  if (!secretKey || secretKey.trim().length === 0) {
    throw new Error('STRIPE_SECRET_KEY environment variable is not configured. Please set it using Firebase secrets.');
  }
  return require('stripe')(secretKey);
}

const OPENAI_BASE_URL = (process.env.OPENAI_BASE_URL || 'https://api.openai.com/v1').replace(/\/$/, '');

/**
 * Fetch OpenAI API key from environment or Firestore admin settings
 * Never hard-code secrets in source. Prefer env var, then Firestore.
 */
async function getOpenAiApiKey() {
  // 1) Prefer environment variable configured on Functions runtime
  const envKey = typeof process.env.OPENAI_API_KEY === 'string' ? process.env.OPENAI_API_KEY.trim() : '';
  if (envKey) return envKey;

  // 2) Then look for an admin-configured key stored in Firestore
  try {
    const doc = await admin.firestore()
      .collection('admin_settings')
      .doc('openai_config')
      .get();

    if (doc.exists) {
      const data = doc.data();
      const firestoreKey = (data?.api_key || '').toString().trim();
      if (firestoreKey) return firestoreKey;
    }
  } catch (error) {
    console.error('Failed to fetch OpenAI API key from Firestore:', error);
  }

  // 3) No key found
  return '';
}

/**
 * Fetch email configuration from Firestore admin settings
 * Used to determine the sender email address for invitations
 */
async function getEmailConfig() {
  try {
    const doc = await admin.firestore()
      .collection('admin_settings')
      .doc('email_config')
      .get();
    
    if (doc.exists) {
      const data = doc.data();
      const fromEmail = (data?.from_email || '').toString().trim();
      const fromName = (data?.from_name || '').toString().trim();
      const enabled = typeof data?.enabled === 'boolean' ? data.enabled : true;
      
      return {
        fromEmail: fromEmail || 'noreply@therapii.app',
        fromName: fromName || 'Therapii',
        enabled,
      };
    }
    
    return {
      fromEmail: process.env.EMAIL_FROM || 'noreply@therapii.app',
      fromName: process.env.EMAIL_FROM_NAME || 'Therapii',
      enabled: true,
    };
  } catch (error) {
    console.error('Failed to fetch email config from Firestore:', error);
    return {
      fromEmail: process.env.EMAIL_FROM || 'noreply@therapii.app',
      fromName: process.env.EMAIL_FROM_NAME || 'Therapii',
      enabled: true,
    };
  }
}

function safeJsonStringify(value) {
  if (value === null || value === undefined) {
    return null;
  }

  if (typeof value === 'string') {
    return value;
  }

  try {
    return JSON.stringify(value);
  } catch (error) {
    return `unserializable: ${error?.message || error}`;
  }
}

/**
 * Generate a random 5-digit code
 */
function generateCode() {
  return Math.floor(10000 + Math.random() * 90000).toString();
}

/**
 * Check if invitation code already exists in Firestore
 */
async function codeExists(code) {
  const snapshot = await admin.firestore()
    .collection('invitation_codes')
    .where('code', '==', code)
    .limit(1)
    .get();
  return !snapshot.empty;
}

/**
 * Cloud Function to create invitation and send email
 * This handles both code generation and email delivery
 */
exports.createInvitationAndSendEmail = functions.https.onCall(async (data, context) => {
  // Ensure user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to create invitations'
    );
  }

  // Validate input
  if (!data.therapistId || !data.patientEmail || !data.patientFirstName) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required fields: therapistId, patientEmail, or patientFirstName'
    );
  }

  const {
    therapistId,
    patientEmail,
    patientFirstName,
    patientLastName = '',
  } = data;

  // Ensure the authenticated user matches the therapist ID
  if (context.auth.uid !== therapistId) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'You can only create invitations for yourself'
    );
  }

  let invitationRef = null;
  const errorContext = { therapistId, patientEmail };

  try {
    // Generate unique code
    let code = generateCode();
    let exists = await codeExists(code);
    
    // Regenerate if code already exists
    while (exists) {
      code = generateCode();
      exists = await codeExists(code);
    }

    // Create invitation record
    const now = admin.firestore.Timestamp.now();
    const expiresAt = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 48 * 60 * 60 * 1000) // 48 hours
    );

    invitationRef = admin.firestore().collection('invitation_codes').doc();
    const invitation = {
      id: invitationRef.id,
      code: code,
      therapist_id: therapistId,
      patient_email: patientEmail,
      patient_first_name: patientFirstName,
      patient_last_name: patientLastName,
      is_used: false,
      created_at: now,
      expires_at: expiresAt,
    };

    // Save to Firestore
    await invitationRef.set(invitation);

    let emailSent = false;
    
    try {
      // Build email HTML body with professional styling
      const emailHtml = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background: linear-gradient(135deg, #1e3a5f 0%, #2d5a87 100%); padding: 30px; border-radius: 12px 12px 0 0; text-align: center;">
    <h1 style="color: white; margin: 0; font-size: 24px;">Welcome to Therapii</h1>
  </div>
  <div style="background: #ffffff; padding: 30px; border: 1px solid #e0e0e0; border-top: none; border-radius: 0 0 12px 12px;">
    <p style="font-size: 16px;">Hello ${patientFirstName},</p>
    <p style="font-size: 16px;">We're glad to be part of your journey toward better mental well-being.</p>
    <p style="font-size: 16px;">To connect securely with your therapist in the app, please use the one-time connection code below:</p>
    <div style="background: #f5f7fa; border-radius: 8px; padding: 20px; text-align: center; margin: 25px 0;">
      <p style="margin: 0 0 10px 0; font-size: 14px; color: #666;">🔐 Your Connection Code</p>
      <p style="font-size: 32px; font-weight: bold; color: #1e3a5f; letter-spacing: 8px; margin: 0;">${code}</p>
    </div>
    <p style="font-size: 16px; font-weight: 600;">Here's how to use it:</p>
    <ol style="font-size: 16px; padding-left: 20px;">
      <li style="margin-bottom: 8px;">Open the Therapii mobile app.</li>
      <li style="margin-bottom: 8px;">Tap "Connect with Therapist."</li>
      <li style="margin-bottom: 8px;">Enter the 5-digit code shown above.</li>
    </ol>
    <p style="font-size: 16px;">Once you submit the code, your account will be linked directly to your therapist, allowing you to securely exchange messages, schedule sessions, and share updates.</p>
    <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 25px 0;">
    <p style="font-size: 14px; color: #666;">If you did not request this code, please ignore this email or contact us immediately at <a href="mailto:support@therapii.com" style="color: #2d5a87;">support@therapii.com</a>.</p>
    <p style="font-size: 16px; margin-top: 25px;">Warm regards,<br><strong>The Therapii Team</strong></p>
  </div>
</body>
</html>`;

      const emailText = `Hello ${patientFirstName},

Welcome to Therapii – we're glad to be part of your journey toward better mental well-being.

To connect securely with your therapist in the app, please use the one-time connection code below:

Your Code: ${code}

Here's how to use it:

1. Open the Therapii mobile app.
2. Tap "Connect with Therapist."
3. Enter the 5-digit code shown above.

Once you submit the code, your account will be linked directly to your therapist, allowing you to securely exchange messages, schedule sessions, and share updates.

If you did not request this code, please ignore this email or contact us immediately at support@therapii.com.

Warm regards,
The Therapii Team`;

      // Send email using Resend API
      const resend = new Resend(RESEND_API_KEY);
      const { data, error } = await resend.emails.send({
        from: `Therapii <${RESEND_FROM_EMAIL}>`,
        to: [patientEmail],
        subject: 'Your Unique Therapii Connection Code',
        html: emailHtml,
        text: emailText,
      });

      if (error) {
        console.error('Resend API error:', JSON.stringify(error, null, 2));
        // Log the specific error to Firestore for debugging
        try {
          await admin.firestore().collection('email_errors').add({
            type: 'resend_api_error',
            patientEmail,
            therapistId,
            error: JSON.stringify(error),
            errorName: error?.name || null,
            errorMessage: error?.message || null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } catch (logErr) {
          console.error('Failed to log email error:', logErr);
        }
        // Log error but don't fail - invitation is already created
      } else {
        emailSent = true;
        console.log(`Email sent successfully via Resend for ${patientEmail}`, data);
      }
    } catch (emailError) {
      console.error('Failed to send email via Resend:', emailError?.message || emailError);
      // Log the catch error to Firestore for debugging
      try {
        await admin.firestore().collection('email_errors').add({
          type: 'resend_catch_error',
          patientEmail,
          therapistId,
          error: emailError?.message || String(emailError),
          stack: emailError?.stack || null,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (logErr) {
        console.error('Failed to log email catch error:', logErr);
      }
      // Don't fail the entire function if email fails - invitation is already created
      // The user can still manually share the code
    }

    // Return invitation data
    return {
      success: true,
      invitationId: invitation.id,
      emailSent,
      invitation: {
        id: invitation.id,
        code: invitation.code,
        therapistId: invitation.therapist_id,
        patientEmail: invitation.patient_email,
        patientFirstName: invitation.patient_first_name,
        patientLastName: invitation.patient_last_name || '',
        isUsed: invitation.is_used,
        createdAt: invitation.created_at.toDate().toISOString(),
        expiresAt: invitation.expires_at.toDate().toISOString(),
      }
    };
  } catch (error) {
    console.error('Error creating invitation:', error);

    const baselineErrorMessage = 'Failed to create invitation';
    let detailedMessage = error && error.message ? error.message : baselineErrorMessage;

    try {
      if (invitationRef) {
        await invitationRef.delete();
      }
    } catch (cleanupError) {
      console.error('Failed to delete invitation after error:', cleanupError);
    }

    // Persist error context for debugging so the client can surface actionable info
    try {
      const errorLog = {
        therapistId: errorContext.therapistId,
        patientEmail: errorContext.patientEmail,
        message: detailedMessage,
        rawMessage: error?.message ?? null,
        responseBody: error?.response?.body ?? null,
        responseStatus: error?.code ?? error?.response?.statusCode ?? null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      await admin.firestore().collection('invitation_errors').add(errorLog);
    } catch (logError) {
      console.error('Failed to persist invitation error context:', logError);
    }

    const userMessage = detailedMessage && detailedMessage !== baselineErrorMessage
      ? `Failed to create invitation: ${detailedMessage}`
      : baselineErrorMessage;

    throw new functions.https.HttpsError(
      'failed-precondition',
      userMessage,
      {
        message: detailedMessage,
        responseBody: error?.response?.body ?? null,
        responseStatus: error?.code ?? error?.response?.statusCode ?? null,
      }
    );
  }
});

/**
 * Securely save an AI conversation summary (auth required)
 * - Validates the caller is the patient
 * - Confirms the patient is linked to the provided therapistId
 * - Defaults "share_summaries_with_therapist" to true when missing
 */
exports.saveAiConversationSummary = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  }

  const patientId = context.auth.uid;
  const therapistId = typeof data?.therapistId === 'string' ? data.therapistId.trim() : '';
  const summary = typeof data?.summary === 'string' ? data.summary.trim() : '';
  const rawTranscript = Array.isArray(data?.transcript) ? data.transcript : [];

  if (!therapistId) {
    throw new functions.https.HttpsError('invalid-argument', 'therapistId is required');
  }
  if (!summary) {
    throw new functions.https.HttpsError('invalid-argument', 'summary is required');
  }

  try {
    const db = admin.firestore();
    // Load patient profile to validate therapist link and sharing preference
    const userSnap = await db.collection('users').doc(patientId).get();
    if (!userSnap.exists) {
      throw new functions.https.HttpsError('failed-precondition', 'User profile not found');
    }

    const profile = userSnap.data() || {};
    const linkedTherapistId = profile.therapist_id || '';
    if (!linkedTherapistId || linkedTherapistId !== therapistId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'You are not linked to this therapist.'
      );
    }

    const onboarding = profile.patient_onboarding_data || {};
    const sharePref = typeof onboarding.share_summaries_with_therapist === 'boolean'
      ? onboarding.share_summaries_with_therapist
      : true; // default true

    // Sanitize transcript into {role, text} pairs only
    const transcript = rawTranscript
      .filter((part) => part && typeof part === 'object')
      .map((part) => ({
        role: typeof part.role === 'string' ? part.role : '',
        text: typeof part.text === 'string' ? part.text : '',
      }))
      .filter((p) => p.text);

    const payload = {
      patient_id: patientId,
      therapist_id: therapistId,
      summary,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      transcript,
      share_with_therapist: !!sharePref,
    };

    const ref = await db.collection('ai_conversation_summaries').add(payload);
    return { id: ref.id };
  } catch (err) {
    if (err instanceof functions.https.HttpsError) {
      throw err;
    }
    throw new functions.https.HttpsError('unknown', `Failed to save summary: ${err?.message || err}`);
  }
});

exports.generateAiChatCompletion = functions
  .runWith({
    timeoutSeconds: 120,
    memory: '512MB',
  })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'You must be signed in to contact the AI companion.',
      );
    }

    // Fetch API key from Firestore
    const OPENAI_API_KEY = await getOpenAiApiKey();
    
    if (!OPENAI_API_KEY || OPENAI_API_KEY.trim().length === 0) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'AI companion not configured. Please ask an admin to configure the OpenAI API key in Admin Settings.',
      );
    }

    const rawMessages = Array.isArray(data?.messages) ? data.messages : null;
    if (!rawMessages || rawMessages.length === 0) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Expected a non-empty messages array.',
      );
    }

    const messages = rawMessages.map((entry, index) => {
      const role = typeof entry?.role === 'string' ? entry.role.trim() : '';
      const content = typeof entry?.content === 'string' ? entry.content : '';
      if (!role) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          `messages[${index}].role must be a non-empty string`,
        );
      }
      if (!content || content.trim().length === 0) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          `messages[${index}].content must be a non-empty string`,
        );
      }
      return { role, content };
    });

    const model = typeof data?.model === 'string' && data.model.trim().length > 0
      ? data.model.trim()
      : 'gpt-4o-mini';

    const rawMaxTokens = Number(data?.maxOutputTokens ?? data?.max_tokens ?? 800);
    const maxTokens = Number.isFinite(rawMaxTokens)
      ? Math.max(1, Math.min(Math.trunc(rawMaxTokens), 2000))
      : 800;

    const rawTemperature = Number(data?.temperature ?? 0.7);
    const temperature = Number.isFinite(rawTemperature)
      ? Math.max(0, Math.min(rawTemperature, 2))
      : 0.7;

    try {
      const response = await axios.post(
        `${OPENAI_BASE_URL}/chat/completions`,
        {
          model,
          messages,
          max_tokens: maxTokens,
          temperature,
        },
        {
          headers: {
            Authorization: `Bearer ${OPENAI_API_KEY}`,
            'Content-Type': 'application/json',
          },
          timeout: 90000,
          validateStatus: () => true,
        },
      );

      const status = response.status;
      const responseData = response.data;
      const serializedBody = typeof responseData === 'string'
        ? responseData
        : JSON.stringify(responseData);

      if (status < 200 || status >= 300) {
        let errorMessage = 'OpenAI request failed.';
        if (responseData && typeof responseData === 'object') {
          if (typeof responseData.error?.message === 'string') {
            errorMessage = responseData.error.message;
          } else if (typeof responseData.message === 'string') {
            errorMessage = responseData.message;
          }
        } else if (typeof responseData === 'string' && responseData.trim().length > 0) {
          errorMessage = responseData.trim();
        }

        functions.logger.error('OpenAI chat completion failed', {
          status,
          error: errorMessage,
        });

        const failureCode = status >= 500 ? 'unavailable' : 'failed-precondition';

        throw new functions.https.HttpsError(
          failureCode,
          errorMessage,
          {
            message: errorMessage,
            status,
            body: serializedBody || null,
          },
        );
      }

      let payload = responseData;
      if (!payload || typeof payload !== 'object') {
        try {
          payload = JSON.parse(serializedBody || '{}');
        } catch (parseError) {
          functions.logger.error('Failed to parse OpenAI response JSON', {
            error: parseError?.message,
          });
          throw new functions.https.HttpsError(
            'unknown',
            'OpenAI returned an unreadable response.',
            {
              message: 'OpenAI returned an unreadable response.',
            },
          );
        }
      }

      const choice = Array.isArray(payload?.choices) ? payload.choices[0] : null;
      const messageContent = choice?.message?.content;
      const text = typeof messageContent === 'string' ? messageContent.trim() : '';

      if (!text) {
        throw new functions.https.HttpsError(
          'unknown',
          'OpenAI did not return any message content.',
        );
      }

      return {
        text,
        id: payload?.id ?? null,
        model: payload?.model ?? model,
        usage: payload?.usage ?? null,
      };
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      const isAxiosError = !!error?.isAxiosError;
      if (isAxiosError) {
        const status = error?.response?.status ?? null;
        const responseData = error?.response?.data;
        const serializedBody = safeJsonStringify(responseData);
        let failureCode = status != null ? (status >= 500 ? 'unavailable' : 'failed-precondition') : 'internal';

        let errorMessage = 'OpenAI request failed.';
        if (typeof responseData?.error?.message === 'string' && responseData.error.message.trim()) {
          errorMessage = responseData.error.message.trim();
        } else if (typeof responseData?.message === 'string' && responseData.message.trim()) {
          errorMessage = responseData.message.trim();
        } else if (typeof error?.message === 'string' && error.message.trim()) {
          errorMessage = error.message.trim();
        }

        switch (error?.code) {
          case 'ENOTFOUND':
            errorMessage = 'Firebase Functions could not reach OpenAI. Ensure outbound networking is enabled (Blaze plan) and retry.';
            failureCode = 'unavailable';
            break;
          case 'ECONNABORTED':
          case 'ETIMEDOUT':
            errorMessage = 'The OpenAI request timed out before it could finish. Please try again.';
            failureCode = 'unavailable';
            break;
          case 'ECONNREFUSED':
          case 'ECONNRESET':
            errorMessage = 'The connection to OpenAI was interrupted. Please try again in a moment.';
            failureCode = 'unavailable';
            break;
          default:
            break;
        }

        functions.logger.error('Axios error while calling OpenAI', {
          status,
          code: error?.code ?? null,
          message: errorMessage,
          body: serializedBody,
        });

        throw new functions.https.HttpsError(
          failureCode,
          errorMessage,
          {
            message: errorMessage,
            status,
            reason: error?.code ?? null,
            body: serializedBody,
          },
        );
      }

      functions.logger.error('Unexpected error while calling OpenAI', {
        message: error?.message || error,
        stack: error?.stack ?? null,
      });

      throw new functions.https.HttpsError(
        'internal',
        'The AI companion is currently unavailable. Please try again.',
        {
          message: error?.message || 'Unexpected error while calling OpenAI.',
        },
      );
    }
  });

/**
 * List therapist invitations (authenticated therapist only)
 */
exports.getTherapistInvitations = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  }

  const therapistId = (data && data.therapistId) || context.auth.uid;
  if (therapistId !== context.auth.uid) {
    throw new functions.https.HttpsError('permission-denied', 'You can only view your own invitations.');
  }

  try {
    const snap = await admin
      .firestore()
      .collection('invitation_codes')
      .where('therapist_id', '==', therapistId)
      .get();

    const list = snap.docs
      .map((d) => d.data())
      .filter(Boolean)
      .map((inv) => ({
        id: inv.id,
        code: inv.code,
        therapistId: inv.therapist_id,
        patientEmail: inv.patient_email,
        patientFirstName: inv.patient_first_name,
        patientLastName: inv.patient_last_name || '',
        isUsed: !!inv.is_used,
        createdAt: (inv.created_at?.toDate?.() || new Date(0)).toISOString(),
        expiresAt: (inv.expires_at?.toDate?.() || new Date(0)).toISOString(),
        usedAt: inv.used_at?.toDate ? inv.used_at.toDate().toISOString() : null,
        patientId: inv.patient_id || null,
      }));

    // Sort server-side by createdAt desc
    list.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    return { invitations: list };
  } catch (err) {
    throw new functions.https.HttpsError('unknown', `Failed to fetch invitations: ${err?.message || err}`);
  }
});

/**
 * Preview an invitation by code (no auth required)
 * Returns sanitized data only when code is unused and not expired.
 */
exports.previewInvitationByCode = functions.https.onCall(async (data, context) => {
  const code = typeof data?.code === 'string' ? data.code.trim() : '';
  if (!code || !/^\d{5}$/.test(code)) {
    throw new functions.https.HttpsError('invalid-argument', 'code must be a 5-digit string');
  }

  try {
    const snap = await admin
      .firestore()
      .collection('invitation_codes')
      .where('code', '==', code)
      .limit(1)
      .get();

    if (snap.empty) return { invitation: null };
    const inv = snap.docs[0].data();

    const isUsed = !!inv.is_used;
    const now = new Date();
    const expiresAt = inv.expires_at?.toDate ? inv.expires_at.toDate() : new Date(0);
    if (isUsed || expiresAt <= now) {
      return { invitation: null };
    }

    return {
      invitation: {
        id: inv.id,
        code: inv.code,
        therapistId: inv.therapist_id,
        patientEmail: inv.patient_email,
        patientFirstName: inv.patient_first_name,
        patientLastName: inv.patient_last_name || '',
        isUsed: false,
        createdAt: (inv.created_at?.toDate?.() || new Date(0)).toISOString(),
        expiresAt: expiresAt.toISOString(),
      }
    };
  } catch (err) {
    throw new functions.https.HttpsError('unknown', `Failed to preview code: ${err?.message || err}`);
  }
});

/**
 * Validate and consume an invitation code (auth required)
 */
exports.validateAndUseInvitation = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  }

  const code = typeof data?.code === 'string' ? data.code.trim() : '';
  if (!code || !/^\d{5}$/.test(code)) {
    throw new functions.https.HttpsError('invalid-argument', 'code must be a 5-digit string');
  }

  const patientId = context.auth.uid;

  try {
    const db = admin.firestore();
    const query = await db.collection('invitation_codes')
      .where('code', '==', code)
      .limit(1)
      .get();

    if (query.empty) {
      return { invitation: null };
    }

    const doc = query.docs[0];
    const ref = doc.ref;

    const result = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) return null;
      const inv = snap.data();
      const isUsed = !!inv.is_used;
      const now = new Date();
      const expiresAt = inv.expires_at?.toDate ? inv.expires_at.toDate() : new Date(0);

      if (isUsed || expiresAt <= now) return null;

      tx.update(ref, {
        is_used: true,
        used_at: admin.firestore.FieldValue.serverTimestamp(),
        patient_id: patientId,
      });

      return {
        id: inv.id,
        code: inv.code,
        therapistId: inv.therapist_id,
        patientEmail: inv.patient_email,
        patientFirstName: inv.patient_first_name,
        patientLastName: inv.patient_last_name || '',
        isUsed: true,
        createdAt: (inv.created_at?.toDate?.() || new Date(0)).toISOString(),
        expiresAt: (inv.expires_at?.toDate?.() || new Date(0)).toISOString(),
        usedAt: new Date().toISOString(),
        patientId,
      };
    });

    return { invitation: result };
  } catch (err) {
    throw new functions.https.HttpsError('unknown', `Failed to validate code: ${err?.message || err}`);
  }
});

/**
 * Delete an invitation (therapist only; cannot delete used)
 */
exports.deleteInvitation = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  }

  const invitationId = typeof data?.invitationId === 'string' ? data.invitationId : '';
  if (!invitationId) {
    throw new functions.https.HttpsError('invalid-argument', 'invitationId is required');
  }

  const therapistId = context.auth.uid;

  try {
    const ref = admin.firestore().collection('invitation_codes').doc(invitationId);
    const snap = await ref.get();
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'Invitation not found');
    }
    const inv = snap.data();
    if (inv.therapist_id !== therapistId) {
      throw new functions.https.HttpsError('permission-denied', 'Cannot delete this invitation');
    }
    if (inv.is_used) {
      throw new functions.https.HttpsError('failed-precondition', 'Invitation already used');
    }
    await ref.delete();
    return { success: true };
  } catch (err) {
    if (err instanceof functions.https.HttpsError) throw err;
    throw new functions.https.HttpsError('unknown', `Failed to delete invitation: ${err?.message || err}`);
  }
});

/**
 * List accepted invitations for a therapist (auth required)
 */
exports.getAcceptedInvitationsForTherapist = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  }
  const therapistId = (data && data.therapistId) || context.auth.uid;
  if (therapistId !== context.auth.uid) {
    throw new functions.https.HttpsError('permission-denied', 'You can only view your own accepted invitations.');
  }
  try {
    const snap = await admin
      .firestore()
      .collection('invitation_codes')
      .where('therapist_id', '==', therapistId)
      .where('is_used', '==', true)
      .get();

    const list = snap.docs.map((d) => d.data()).filter(Boolean).map((inv) => ({
      id: inv.id,
      code: inv.code,
      therapistId: inv.therapist_id,
      patientEmail: inv.patient_email,
      patientFirstName: inv.patient_first_name,
      patientLastName: inv.patient_last_name || '',
      isUsed: !!inv.is_used,
      createdAt: (inv.created_at?.toDate?.() || new Date(0)).toISOString(),
      expiresAt: (inv.expires_at?.toDate?.() || new Date(0)).toISOString(),
      usedAt: inv.used_at?.toDate ? inv.used_at.toDate().toISOString() : null,
      patientId: inv.patient_id || null,
    }));

    // Sort by usedAt desc then createdAt desc
    list.sort((a, b) => {
      const au = a.usedAt ? new Date(a.usedAt).getTime() : 0;
      const bu = b.usedAt ? new Date(b.usedAt).getTime() : 0;
      if (bu !== au) return bu - au;
      return new Date(b.createdAt) - new Date(a.createdAt);
    });
    return { invitations: list };
  } catch (err) {
    throw new functions.https.HttpsError('unknown', `Failed to fetch accepted invitations: ${err?.message || err}`);
  }
});

/**
 * List accepted invitations for a patient (auth required)
 */
exports.getAcceptedInvitationsForPatient = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  }
  const patientId = (data && data.patientId) || context.auth.uid;
  if (patientId !== context.auth.uid) {
    throw new functions.https.HttpsError('permission-denied', 'You can only view your own invitations.');
  }
  try {
    const snap = await admin
      .firestore()
      .collection('invitation_codes')
      .where('patient_id', '==', patientId)
      .where('is_used', '==', true)
      .get();

    const list = snap.docs.map((d) => d.data()).filter(Boolean).map((inv) => ({
      id: inv.id,
      code: inv.code,
      therapistId: inv.therapist_id,
      patientEmail: inv.patient_email,
      patientFirstName: inv.patient_first_name,
      patientLastName: inv.patient_last_name || '',
      isUsed: !!inv.is_used,
      createdAt: (inv.created_at?.toDate?.() || new Date(0)).toISOString(),
      expiresAt: (inv.expires_at?.toDate?.() || new Date(0)).toISOString(),
      usedAt: inv.used_at?.toDate ? inv.used_at.toDate().toISOString() : null,
      patientId: inv.patient_id || null,
    }));

    list.sort((a, b) => {
      const au = a.usedAt ? new Date(a.usedAt).getTime() : 0;
      const bu = b.usedAt ? new Date(b.usedAt).getTime() : 0;
      if (bu !== au) return bu - au;
      return new Date(b.createdAt) - new Date(a.createdAt);
    });
    return { invitations: list };
  } catch (err) {
    throw new functions.https.HttpsError('unknown', `Failed to fetch patient invitations: ${err?.message || err}`);
  }
});

/**
 * Create Stripe Checkout Session for subscription
 * Keeps secret key secure server-side
 */
exports.createStripeCheckoutSession = functions
  .runWith({ secrets: ['STRIPE_SECRET_KEY'] })
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  }

  const userId = context.auth.uid;
  const email = context.auth.token.email || '';
  const priceId = data?.priceId || 'price_1SOt2aL9fA3Th1kO32maIqxk';

  try {
    const stripe = getStripe();
    
    // Get or create Stripe customer
    let customerId = null;
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const userData = userDoc.exists ? userDoc.data() : {};
    
    if (userData.stripe_customer_id) {
      customerId = userData.stripe_customer_id;
    } else {
      // Create new customer
      const customer = await stripe.customers.create({
        email: email,
        metadata: { userId: userId },
      });
      customerId = customer.id;
      
      // Save customer ID to user document
      await admin.firestore().collection('users').doc(userId).update({
        stripe_customer_id: customerId,
      });
    }

    // Create Stripe Checkout Session
    const session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      payment_method_types: ['card'],
      line_items: [
        {
          price: priceId,
          quantity: 1,
        },
      ],
      customer: customerId,
      client_reference_id: userId,
      success_url: `${data?.successUrl || 'https://therapii.app/success'}?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: data?.cancelUrl || 'https://therapii.app/billing',
      metadata: {
        userId: userId,
      },
      subscription_data: {
        metadata: {
          userId: userId,
        },
      },
    });

    return {
      sessionId: session.id,
      url: session.url,
    };
  } catch (error) {
    console.error('Error creating Stripe Checkout session:', error);
    
    // Check if error is due to missing Stripe key
    if (error?.message?.includes('STRIPE_SECRET_KEY')) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Stripe is not configured. Please configure STRIPE_SECRET_KEY in Firebase secrets.'
      );
    }
    
    throw new functions.https.HttpsError(
      'internal',
      `Failed to create checkout session: ${error?.message || error}`
    );
  }
});

/**
 * Fetch billing details from Stripe for the authenticated user
 * Returns subscription status, credit balance, payment method, and coupon info
 */
exports.getStripeBillingDetails = functions
  .runWith({ secrets: ['STRIPE_SECRET_KEY'] })
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  }

  const userId = context.auth.uid;

  try {
    const stripe = getStripe();
    
    // Get user's Stripe customer ID
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return {
        isPaidUser: false,
        planName: 'Free Plan',
        creditBalance: 0,
        paymentMethod: null,
        subscriptionStatus: null,
        nextBillingDate: null,
        appliedCoupon: null,
      };
    }

    const userData = userDoc.data();
    const customerId = userData.stripe_customer_id;

    if (!customerId) {
      return {
        isPaidUser: false,
        planName: 'Free Plan',
        creditBalance: 0,
        paymentMethod: null,
        subscriptionStatus: null,
        nextBillingDate: null,
        appliedCoupon: null,
      };
    }

    // Fetch customer data including credit balance
    const customer = await stripe.customers.retrieve(customerId, {
      expand: ['sources', 'invoice_settings.default_payment_method'],
    });

    // Fetch active subscriptions
    const subscriptions = await stripe.subscriptions.list({
      customer: customerId,
      status: 'active',
      limit: 1,
    });

    const hasActiveSubscription = subscriptions.data.length > 0;
    const subscription = subscriptions.data[0] || null;

    // Get payment method details
    let paymentMethod = null;
    if (customer.invoice_settings?.default_payment_method) {
      const pm = typeof customer.invoice_settings.default_payment_method === 'string'
        ? await stripe.paymentMethods.retrieve(customer.invoice_settings.default_payment_method)
        : customer.invoice_settings.default_payment_method;
      
      if (pm && pm.card) {
        paymentMethod = {
          brand: pm.card.brand,
          last4: pm.card.last4,
          expMonth: pm.card.exp_month,
          expYear: pm.card.exp_year,
        };
      }
    }

    // Get applied coupon/discount
    let appliedCoupon = null;
    if (subscription?.discount?.coupon) {
      const coupon = subscription.discount.coupon;
      appliedCoupon = {
        code: subscription.discount.promotion_code || coupon.id,
        name: coupon.name || coupon.id,
        percentOff: coupon.percent_off,
        amountOff: coupon.amount_off ? coupon.amount_off / 100 : null,
      };
    }

    // Credit balance is stored as negative cents in Stripe (negative = credit)
    const creditBalance = customer.balance ? Math.abs(customer.balance) / 100 : 0;

    return {
      isPaidUser: hasActiveSubscription,
      planName: hasActiveSubscription ? 'Platinum Plan' : 'Free Plan',
      creditBalance: creditBalance,
      paymentMethod: paymentMethod,
      subscriptionStatus: subscription?.status || null,
      nextBillingDate: subscription?.current_period_end 
        ? new Date(subscription.current_period_end * 1000).toISOString() 
        : null,
      appliedCoupon: appliedCoupon,
    };
  } catch (error) {
    console.error('Error fetching Stripe billing details:', error);
    
    if (error?.message?.includes('STRIPE_SECRET_KEY')) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Stripe is not configured. Please configure STRIPE_SECRET_KEY in Firebase secrets.'
      );
    }
    
    throw new functions.https.HttpsError(
      'internal',
      `Failed to fetch billing details: ${error?.message || error}`
    );
  }
});

/**
 * Redeem a Stripe promotion/coupon code
 */
exports.redeemStripeCode = functions
  .runWith({ secrets: ['STRIPE_SECRET_KEY'] })
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  }

  const userId = context.auth.uid;
  const code = typeof data?.code === 'string' ? data.code.trim() : '';

  if (!code) {
    throw new functions.https.HttpsError('invalid-argument', 'code is required');
  }

  try {
    const stripe = getStripe();
    
    // Get user's Stripe customer ID
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('failed-precondition', 'User not found');
    }

    const userData = userDoc.data();
    let customerId = userData.stripe_customer_id;

    // Create customer if doesn't exist
    if (!customerId) {
      const customer = await stripe.customers.create({
        email: context.auth.token.email || '',
        metadata: { userId: userId },
      });
      customerId = customer.id;
      await admin.firestore().collection('users').doc(userId).update({
        stripe_customer_id: customerId,
      });
    }

    // Try to find promotion code first
    const promoCodes = await stripe.promotionCodes.list({
      code: code,
      active: true,
      limit: 1,
    });

    if (promoCodes.data.length > 0) {
      const promoCode = promoCodes.data[0];
      const coupon = promoCode.coupon;

      // Check if coupon gives credit (amount_off)
      if (coupon.amount_off) {
        // Add credit to customer balance
        await stripe.customers.update(customerId, {
          balance: -(coupon.amount_off), // Negative = credit in Stripe
        });

        return {
          success: true,
          type: 'credit',
          amount: coupon.amount_off / 100,
          message: `\$${(coupon.amount_off / 100).toFixed(2)} credit added to your account!`,
        };
      } else if (coupon.percent_off) {
        // This is a percentage discount, would need to apply to subscription
        return {
          success: true,
          type: 'discount',
          percentOff: coupon.percent_off,
          message: `${coupon.percent_off}% discount code validated! Apply it during checkout.`,
          promoCodeId: promoCode.id,
        };
      }
    }

    throw new functions.https.HttpsError('not-found', 'Invalid or expired code');
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    
    console.error('Error redeeming code:', error);
    
    if (error?.message?.includes('STRIPE_SECRET_KEY')) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Stripe is not configured. Please configure STRIPE_SECRET_KEY in Firebase secrets.'
      );
    }
    
    throw new functions.https.HttpsError(
      'internal',
      `Failed to redeem code: ${error?.message || error}`
    );
  }
});

/**
 * Fetch invoices from Stripe for the authenticated user
 */
exports.getStripeInvoices = functions
  .runWith({ secrets: ['STRIPE_SECRET_KEY'] })
  .https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  }

  const userId = context.auth.uid;

  try {
    const stripe = getStripe();
    
    // Get user's Stripe customer ID
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return { invoices: [] };
    }

    const userData = userDoc.data();
    const customerId = userData.stripe_customer_id;

    if (!customerId) {
      // User has no Stripe customer ID, so no invoices
      return { invoices: [] };
    }

    // Fetch invoices from Stripe
    const invoices = await stripe.invoices.list({
      customer: customerId,
      limit: 10,
      status: 'paid', // Only fetch paid invoices
    });

    // Transform Stripe invoices to our format
    const transformedInvoices = invoices.data.map(invoice => ({
      id: invoice.number || invoice.id,
      amount: invoice.amount_paid / 100, // Convert from cents to dollars
      issuedAt: new Date(invoice.created * 1000).toISOString(),
      status: 'paid',
      invoiceUrl: invoice.invoice_pdf,
    }));

    return { invoices: transformedInvoices };
  } catch (error) {
    console.error('Error fetching Stripe invoices:', error);
    
    // Check if error is due to missing Stripe key
    if (error?.message?.includes('STRIPE_SECRET_KEY')) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Stripe is not configured. Please configure STRIPE_SECRET_KEY in Firebase secrets.'
      );
    }
    
    throw new functions.https.HttpsError(
      'internal',
      `Failed to fetch invoices: ${error?.message || error}`
    );
  }
});
