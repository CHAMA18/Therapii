# Therapii App Architecture

## Overview
Therapii is a Flutter-based mental health platform connecting therapists with patients through AI-enhanced conversations, voice check-ins, and secure messaging.

## Tech Stack
- **Frontend**: Flutter (cross-platform: iOS, Android, Web)
- **Backend**: Firebase (Authentication, Firestore, Cloud Functions, Storage)
- **AI Integration**: OpenAI API (via Cloud Functions for security)
- **Audio**: just_audio package (web-friendly)

## User Roles
1. **Therapist**: Manages patients, reviews voice check-ins, trains AI companion, sends invitations
2. **Patient**: Records voice check-ins, chats with therapist and AI companion, completes onboarding

## Core Features

### Authentication & Onboarding
- **Auth Flow**: Firebase Authentication with email verification
- **Therapist Onboarding**: Psychology Today integration, specialization selection, practice personalization, therapeutic models
- **Patient Onboarding**: Invitation code system, payment integration, dashboard setup

### Voice Check-ins
- **Recording**: Cross-platform audio recording (mobile & web)
- **Storage**: Firebase Storage for audio files
- **Playback**: In-app audio player with progress tracking
- **Access**: Therapists can create voice check-ins for patients; both can view/play recordings

### AI Companion
- **Configuration**: OpenAI API accessed via Cloud Functions (`generateAiChatCompletion`)
- **Training**: Therapists provide custom instructions to personalize AI responses
- **Conversations**: Real-time chat interface for patients with AI summaries

### Messaging
- **Direct Chat**: Patient-therapist messaging via Firestore
- **Real-time**: Stream-based conversation updates

### Patient Management
- **Invitations**: Unique invitation codes for new patients
- **Patient List**: Active patients view with "See All" expansion (10 records initially)
- **Sessions**: Track therapy sessions with timestamps

## Data Models

### User
- `id`, `email`, `displayName`, `role` (therapist/patient)
- `createdAt`, `updatedAt`
- Methods: `toJson()`, `fromJson()`, `copyWith()`

### Therapist
- Links to User
- Specializations, practice details, therapeutic models
- Training instructions for AI

### VoiceCheckin
- `id`, `patientId`, `therapistId`, `audioUrl`, `duration`
- `recordedAt`, `createdAt`, `updatedAt`
- Transcription and AI analysis data

### ChatConversation & ChatMessage
- Patient-therapist messaging
- Timestamp tracking, read status

### TherapySession
- Session scheduling and tracking
- Links patient and therapist

### InvitationCode
- Unique codes for patient signup
- Expiration and usage tracking

### AiConversationSummary
- AI chat summaries
- Links to patient and therapist

## Services Layer

### UserService
- User CRUD operations
- Role-based data retrieval

### TherapistService
- Therapist profile management
- Patient relationship tracking

### VoiceCheckinService
- Audio upload to Firebase Storage
- Firestore metadata management
- Playback retrieval

### ChatService
- Real-time messaging
- Conversation management

### AiConversationService
- AI chat history
- Summary generation

### TherapySessionService
- Session scheduling and tracking

### InvitationService
- Code generation and validation
- Patient signup flow

### OpenAITrainer
- Cloud Function integration for secure API access
- AI training configuration

## Firebase Configuration

### Firestore Collections
- `users`, `therapists`, `patients`
- `voiceCheckins`, `chatConversations`, `chatMessages`
- `therapySessions`, `invitationCodes`
- `aiConversationSummaries`

### Storage Rules
- Voice check-ins: Therapist can create for patients; both can read
- Patient-specific folders for audio files

### Cloud Functions
- `generateAiChatCompletion`: Proxy for OpenAI API requests (keeps API key secure)

## UI Architecture

### Theme System
- Centralized color palette in `theme.dart`
- Theme colors referenced throughout (no hardcoded colors)
- Dark/light mode support via `ThemeModeController`

### Reusable Widgets
- `PrimaryButton`: Consistent button styling
- `FormFields`: Custom text input fields
- `AppDrawer`: Main navigation drawer
- `CommonSettingsDrawer`: Settings and profile access
- `ShimmerWidgets`: Loading state placeholders

### Key Pages

**Therapist Pages:**
- `MyPatientsPage`: Active patients list (10 max, "See All" expansion), invitations sent
- `TherapistVoiceConversationPage`: Record voice check-ins for patients with playback preview
- `TherapistTrainingPage`: Configure AI companion instructions
- `TherapistCodesPage`: Manage invitation codes

**Patient Pages:**
- `PatientDashboardPage`: Voice recording preview, latest check-in playback, messaging
- `PatientChatPage`: Direct messaging with therapist
- `AiTherapistChatPage`: AI companion conversations
- `PatientVoiceConversationPage`: Record and manage voice check-ins

**Shared Pages:**
- `HomePage`: Role-based navigation hub
- `EditProfilePage`: Profile management with email verification
- `BillingPage`: Payment and subscription management
- `SupportCenterPage`: Help and resources

## Security & Permissions

### Firestore Rules
- Voice check-ins: Therapist can create for patients; patient and therapist can read their own records
- Role-based access control for all collections

### App Permissions
- Microphone: Voice recording
- Storage: Audio file access (mobile)
- Internet: API and Firebase connectivity

## Platform-Specific Notes

### Web
- Audio recording uses web-compatible packages
- File picker for cross-platform file uploads
- No `dart:io` usage

### Mobile (iOS/Android)
- Native audio recording capabilities
- Platform-specific permissions in configuration files

## App Icon
- Uses `assets/images/therapii_logo_blue.png`
- Applied via `flutter_launcher_icons` package during publish

## Deployment

### Firebase Functions
- Requires Node 20 runtime
- `package.json` and `package-lock.json` in `functions/` directory
- Deploy via Firebase CLI or Dreamflow publish

### App Publishing
- Dreamflow Publish button for web, App Store, Google Play Store
- Download code for local APK/IPA builds

## Future Considerations
- Offline mode for voice recordings
- Enhanced AI training with conversation feedback
- Group therapy session support
- Analytics and insights dashboard for therapists
