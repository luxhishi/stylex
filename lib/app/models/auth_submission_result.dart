class AuthSubmissionResult {
  const AuthSubmissionResult({
    required this.success,
    required this.message,
    required this.shouldShowStylePreference,
  });

  final bool success;
  final String message;
  final bool shouldShowStylePreference;
}
