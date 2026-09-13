import 'package:seyra/core/errors/failures.dart';

sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;

  @override
  bool operator ==(Object other) {
    return other is Success<T> && other.value == value;
  }

  @override
  int get hashCode => Object.hash(Success, value);
}

final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) {
    return other is FailureResult<T> && other.failure == failure;
  }

  @override
  int get hashCode => Object.hash(FailureResult, failure);
}
