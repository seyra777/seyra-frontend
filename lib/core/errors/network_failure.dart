import 'package:seyra/core/errors/failures.dart';

/// Transport-level failure. Not specific to authentication.
final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network error']);
}