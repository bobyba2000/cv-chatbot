abstract class Result<T> {
  Result(this.data);
  T? data;
  bool get isSuccessful => this is Success<T>;
}

class Success<T> extends Result<T> {
  Success(super.data);
}

class Failed<T> extends Result<T> {
  Failed(this.errorCode, this.message) : super(null);
  String? errorCode;
  String message;

  @override
  String toString() {
    return message;
  }
}
