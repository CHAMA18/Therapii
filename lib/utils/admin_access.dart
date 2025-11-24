class AdminAccess {
  AdminAccess._();

  static const List<String> _adminEmails = [
    'chungu424@gmail.com',
    'emacbean@gmail.com',
    'chungu@thestackone.com',
  ];

  static bool isAdminEmail(String? email) {
    if (email == null) return false;
    final normalized = email.trim().toLowerCase();
    return _adminEmails.contains(normalized);
  }

  static String? maybeNormalize(String? email) {
    return email?.trim().toLowerCase();
  }
}