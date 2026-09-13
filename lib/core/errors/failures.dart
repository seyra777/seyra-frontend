/// Domain-level failure. Keep this independent of Flutter and HTTP types.
abstract class Failure {
  const Failure(this.message);

  final String message;

  @override
  bool operator ==(Object other) {
    return other is Failure &&
        other.runtimeType == runtimeType &&
        other.message == message;
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'Unexpected error']);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}
