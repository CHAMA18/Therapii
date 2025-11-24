const functions = require('firebase-functions');
const admin = require('firebase-admin');
const sgMail = require('@sendgrid/mail');
const axios = require('axios');

admin.initializeApp();

// Default sender email (fallback only)
const SENDER_EMAIL = process.env.SENDGRID_FROM_EMAIL || functions.config().sendgrid?.from || 'no-reply@therapii.app';

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

// No hard-coded SendGrid defaults. Use env or Firestore configuration only.

/**
 * Fetch SendGrid configuration from Firestore admin settings
 * Falls back to environment variables if not configured
 */
async function getSendGridConfig() {
  try {
    const doc = await admin.firestore()
      .collection('admin_settings')
      .doc('sendgrid_config')
      .get();
    
    if (doc.exists) {
      const data = doc.data();
      const apiKey = data?.api_key || '';
      const apiKeyId = data?.api_key_id || '';
      const fromEmail = (data?.from_email || '').toString().trim();
      const enabledFlag = typeof data?.enabled === 'boolean' ? !!data.enabled : true;
      
      // Return Firestore config if API key is present
      if (apiKey && apiKey.trim().length > 0) {
        return {
          apiKey: apiKey.trim(),
          apiKeyId: apiKeyId ? apiKeyId.trim() : '',
          enabled: enabledFlag,
          fromEmail: fromEmail || null,
        };
      }
    }
    // Fallback to environment variables only (no hard-coded secrets)
    const envApiKey = (process.env.SENDGRID_API_KEY || '').toString().trim();
    const envApiKeyId = (process.env.SENDGRID_API_KEY_ID || '').toString().trim();
    const envFrom = process.env.SENDGRID_FROM_EMAIL || functions.config().sendgrid?.from || SENDER_EMAIL;
    return {
      apiKey: envApiKey,
      apiKeyId: envApiKeyId,
      enabled: !!envApiKey, // enable only if a key is present
      fromEmail: envFrom,
    };
  } catch (error) {
    console.error('Failed to fetch SendGrid config from Firestore:', error);
    // Return env on error
    const envApiKey = (process.env.SENDGRID_API_KEY || '').toString().trim();
    const envApiKeyId = (process.env.SENDGRID_API_KEY_ID || '').toString().trim();
    const envFrom = process.env.SENDGRID_FROM_EMAIL || functions.config().sendgrid?.from || SENDER_EMAIL;
    return {
      apiKey: envApiKey,
      apiKeyId: envApiKeyId,
      enabled: !!envApiKey,
      fromEmail: envFrom,
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
    
    // Fetch SendGrid configuration from Firestore/env
    const sendGridConfig = await getSendGridConfig();
    
    if (sendGridConfig.enabled) {
      try {
        // Configure SendGrid with the API key from Firestore
        sgMail.setApiKey(sendGridConfig.apiKey);
        
        // Build email body
        const emailBody = `Hello ${patientFirstName},

Welcome to Therapii – we're glad to be part of your journey toward better mental well-being.

To connect securely with your therapist in the app, please use the one-time connection code below:

🔐 Your Code: ${code}

Here's how to use it:

1. Open the Therapii mobile app.
2. Tap "Connect with Therapist."
3. Enter the 5-digit code shown above.

Once you submit the code, your account will be linked directly to your therapist, allowing you to securely exchange messages, schedule sessions, and share updates.

If you did not request this code, please ignore this email or contact us immediately at support@therapii.com.

Warm regards,
The Therapii Team`;

        // Determine sender email
        const sender = (sendGridConfig.fromEmail || SENDER_EMAIL).toString().trim();
        if (!sender) {
          console.warn('SendGrid configured without a from_email; skipping email delivery.');
        } else {
          // Prepare SendGrid message
        const msg = {
          to: patientEmail,
            from: sender,
          subject: 'Your Unique Therapii Connection Code',
          text: emailBody,
        };

          await sgMail.send(msg);
          emailSent = true;
          console.log(`Email sent successfully to ${patientEmail} (from: ${sender})`);
        }
      } catch (emailError) {
        console.error('Failed to send email via SendGrid:', emailError);
        // Don't fail the entire function if email fails - invitation is already created
        // The user can still manually share the code
      }
    } else {
      console.log('SendGrid not configured in Admin Settings; skipping email delivery.');
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

    if (error.response) {
      console.error('SendGrid response error:', error.response.body);
      const responseErrors = error.response.body && error.response.body.errors;
      if (Array.isArray(responseErrors) && responseErrors.length > 0) {
        detailedMessage = responseErrors.map((err) => err.message).join(' | ');
      }
    }

    try {
      if (invitationRef) {
        await invitationRef.delete();
      }
    } catch (cleanupError) {
      console.error('Failed to delete invitation after SendGrid error:', cleanupError);
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
