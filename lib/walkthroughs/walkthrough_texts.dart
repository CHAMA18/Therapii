class WalkthroughTexts {
  // Patient Dashboard Walkthrough
  static const Map<String, String> patientDashboard = {
    'menu': 'Tap here to access Settings, Billing, Support, and manage your therapist connections.',
    'header': 'Your personalized dashboard! Here you\'ll see your therapist info, recent conversations, and quick actions.',
    'refresh': 'Refresh your dashboard data to see the latest updates from your therapist.',
    'openChat': 'Start a text conversation with your therapist. Messages are private and secure.',
    'voiceCheckin': 'Record voice updates for your therapist. Great for sharing how you\'re feeling between sessions.',
    'therapistCard': 'Your connected therapist! View their profile, bio, and specialization here.',
    'aiToggle': 'Switch between chatting with your human therapist or KAI for 24/7 support.',
    'aiCompanion': 'KAI is always available for check-ins, reflections, and coping strategies.'
  };

  // Therapist "My Patients" Page Walkthrough
  static const Map<String, String> myPatients = {
    'menu': 'Access Settings, Admin tools (if applicable), and account preferences.',
    'tabs': 'Switch between "My Patients" to manage your patient list and "Listen" to review voice check-ins.',
    'inviteNew': 'Invite a new patient! Enter their info and we\'ll send them a secure invitation code via email.',
    'activePatients': 'Your active patients are listed here. Click any patient to view their profile and message history.',
    'patientTile': 'Each patient card shows their last message date. Tap "Message History" to open the chat or view their details.',
    'pendingInvites': 'Track invitations you\'ve sent. Codes expire after 7 days. Delete expired invites from here.',
  };

  // Therapist "Listen" Page Walkthrough
  static const Map<String, String> listen = {
    'menu': 'Access your settings and account preferences.',
    'tabs': 'Navigate between "My Patients" and "Listen" tabs.',
    'recordButton': 'Start recording voice notes for a specific patient. Select the patient, then begin recording.',
    'voiceCheckins': 'View all recent voice check-ins from your patients. Tap any recording to play it.',
    'transcripts': 'AI-generated summaries of patient conversations with the AI companion. Review to stay aligned with patient progress.',
  };

  // KAI Chat Walkthrough
  static const Map<String, String> aiChat = {
    'header': 'KAI provides 24/7 support between human therapy sessions.',
    'personalization': 'KAI is personalized based on your therapy goals, focus areas, and preferences from onboarding.',
    'endConversation': 'When you finish, tap "End Conversation" to save a summary that your therapist can review.',
    'messageInput': 'Type your thoughts, feelings, or questions here. KAI responds with empathy and actionable guidance.',
    'messages': 'Your conversation appears here. KAI keeps responses concise (under 6 sentences) and aligned with your therapist.',
  };

  // Voice Conversation Walkthrough
  static const Map<String, String> voiceConversation = {
    'header': 'Record short voice updates for your therapist. They\'ll receive notifications when you share recordings.',
    'recordButton': 'Tap the microphone to start recording. Tap the stop button when finished. Your recording will be saved locally.',
    'timer': 'Track your recording duration. Keep it brief and focused on what you want to share.',
    'shareButton': 'Upload and share your recording with your therapist. They can listen at their convenience.',
    'chatButton': 'Prefer texting? Open the chat to message your therapist directly instead.',
  };

  // New Patient Info Walkthrough
  static const Map<String, String> newPatient = {
    'header': 'Invite a new patient to join Therapii. We\'ll send them a secure invitation code via email.',
    'nameField': 'Enter the patient\'s full name. We\'ll use their first name in personalized communications.',
    'emailField': 'Enter the patient\'s email address. They\'ll receive an invitation with a unique 5-digit code.',
    'credits': 'Optionally offer free months (credits) to help your patient get started.',
    'notes': 'Add personalized notes about the patient. This helps the AI companion tailor its approach to their needs.',
    'submit': 'Click Submit to send the invitation email. Your patient will receive their code within minutes.',
  };

  // Additional helpful texts
  static const String skipWalkthrough = 'You can always access help from the Support section in Settings.';
  static const String welcomeMessage = 'Welcome to Therapii! Let\'s take a quick tour of the key features.';
}
