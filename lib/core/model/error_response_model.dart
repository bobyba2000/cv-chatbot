import 'package:json_annotation/json_annotation.dart';

part 'error_response_model.g.dart';

@JsonSerializable()
class ErrorResponseModel {
  ErrorResponseModel(this.message);

  factory ErrorResponseModel.fromJson(Map<String, dynamic> json) =>
      _$ErrorResponseModelFromJson(json);
  final String message;

  Map<String, dynamic> toJson() => _$ErrorResponseModelToJson(this);
}
