# Therapii Walkthrough Guide

This document contains all the walkthrough texts for first-time users of the Therapii application.

## Overview

The walkthrough system guides new users through the key features of each page. Walkthroughs are shown only once per page and can be triggered again from the Support Center if needed.

---

## Patient Dashboard Walkthrough

**Welcome Message:**
> Welcome to your Therapii space! Let's take a quick tour of the key features available to you.

### Tour Points:

1. **Menu Button (Drawer Icon)**
   - "Tap here to access Settings, Billing, Support, and manage your therapist connections."

2. **Header Section**
   - "Your personalized dashboard! Here you'll see your therapist info, recent conversations, and quick actions."

3. **Refresh Button**
   - "Refresh your dashboard data to see the latest updates from your therapist."

4. **Open Chat Button**
   - "Start a text conversation with your therapist. Messages are private and secure."

5. **Voice Check-in Button**
   - "Record voice updates for your therapist. Great for sharing how you're feeling between sessions."

6. **Therapist Card**
   - "Your connected therapist! View their profile, bio, and specialization here."

7. **Chat Toggle (Human/AI)**
   - "Switch between chatting with your human therapist or KAI for 24/7 support."

8. **KAI Companion Section**
   - "KAI is always available for check-ins, reflections, and coping strategies."

---

## Therapist "My Patients" Page Walkthrough

**Welcome Message:**
> Welcome to your patient management hub! Here's how to manage your practice on Therapii.

### Tour Points:

1. **Menu Button**
   - "Access Settings, Admin tools (if applicable), and account preferences."

2. **Tab Navigation**
   - "Switch between 'My Patients' to manage your patient list and 'Listen' to review voice check-ins."

3. **Invite New Button**
   - "Invite a new patient! Enter their info and we'll send them a secure invitation code via email."

4. **Active Patients Section**
   - "Your active patients are listed here. Click any patient to view their profile and message history."

5. **Patient Card**
   - "Each patient card shows their last message date. Tap 'Message History' to open the chat or view their details."

6. **Pending Invites Section**
   - "Track invitations you've sent. Codes expire after 7 days. Delete expired invites from here."

---

## Therapist "Listen" Page Walkthrough

**Welcome Message:**
> The Listen page helps you review patient check-ins and AI conversation summaries.

### Tour Points:

1. **Menu Button**
   - "Access your settings and account preferences."

2. **Tab Navigation**
   - "Navigate between 'My Patients' and 'Listen' tabs."

3. **Record Button**
   - "Start recording voice notes for a specific patient. Select the patient, then begin recording."

4. **Voice Check-ins Section**
   - "View all recent voice check-ins from your patients. Tap any recording to play it."

5. **Transcripts Section**
   - "AI-generated summaries of patient conversations with KAI. Review to stay aligned with patient progress."

---

## KAI Chat Walkthrough

**Welcome Message:**
> KAI is here to provide support 24/7 between your human therapy sessions.

### Tour Points:

1. **Page Header**
   - "KAI provides 24/7 support between human therapy sessions."

2. **Personalization Banner**
   - "KAI is personalized based on your therapy goals, focus areas, and preferences from onboarding."

3. **End Conversation Button**
   - "When you finish, tap 'End Conversation' to save a summary that your therapist can review."

4. **Message Input Field**
   - "Type your thoughts, feelings, or questions here. KAI responds with empathy and actionable guidance."

5. **Chat Messages**
   - "Your conversation appears here. KAI keeps responses concise (under 6 sentences) and aligned with your therapist."

---

## Voice Conversation Walkthrough

**Welcome Message:**
> Record voice updates for your therapist. They're perfect for sharing feelings between sessions.

### Tour Points:

1. **Page Header**
   - "Record short voice updates for your therapist. They'll receive notifications when you share recordings."

2. **Record Button (Microphone)**
   - "Tap the microphone to start recording. Tap the stop button when finished. Your recording will be saved locally."

3. **Timer Display**
   - "Track your recording duration. Keep it brief and focused on what you want to share."

4. **Share Button**
   - "Upload and share your recording with your therapist. They can listen at their convenience."

5. **Chat Button**
   - "Prefer texting? Open the chat to message your therapist directly instead."

---

## New Patient Info Page Walkthrough

**Welcome Message:**
> Let's walk through inviting a new patient to Therapii.

### Tour Points:

1. **Page Header**
   - "Invite a new patient to join Therapii. We'll send them a secure invitation code via email."

2. **Name Field**
   - "Enter the patient's full name. We'll use their first name in personalized communications."

3. **Email Field**
   - "Enter the patient's email address. They'll receive an invitation with a unique 5-digit code."

4. **Credits Toggle**
   - "Optionally offer free months (credits) to help your patient get started."

5. **Notes Field**
   - "Add personalized notes about the patient. This helps the AI companion tailor its approach to their needs."

6. **Submit Button**
   - "Click Submit to send the invitation email. Your patient will receive their code within minutes."

---

## Implementation Notes

### When Walkthroughs Trigger:
- **First time only**: Each walkthrough is shown once per user per page
- **Stored locally**: Uses SharedPreferences to track which walkthroughs have been seen
- **Can be reset**: Admin settings or support can reset all walkthroughs

### Design Guidelines:
- **Keep it brief**: Each tooltip should be 1-2 sentences max
- **Action-oriented**: Tell users what they can DO, not just what things are
- **Contextual**: Show walkthroughs when users first land on a page
- **Skippable**: Always allow users to skip or dismiss the walkthrough

### Technical Details:
- Uses `tutorial_coach_mark` package for the overlay system
- Uses `shared_preferences` for persistence
- Each page has a unique walkthrough key
- Walkthroughs can be manually triggered from Support Center

---

## Support Center Integration

Users can access walkthroughs again through:
1. Settings → Support Center
2. "View App Tutorials" option
3. Select specific page tutorial to replay

---

## Future Enhancements

- **Context-aware help**: Show tips based on user actions
- **Video tutorials**: Embed short video guides
- **Interactive demos**: Guided practice sessions
- **Multilingual support**: Translate walkthroughs
- **Analytics**: Track which features users struggle with most

---

*Last Updated: [Current Date]*
*Version: 1.0*
