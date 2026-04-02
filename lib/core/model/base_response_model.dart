import 'dart:convert';

import '../dependencies/app.dart';
import 'error_response_model.dart';

class ResponseResult<T extends BaseResponseModel> {
  factory ResponseResult.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      if (json['message'] != null) {
        final error = ErrorResponseModel(json['message'].toString());
        return ResponseResult(isSuccessful: false, error: error);
      }
      if (json['data'] != null) {
        T? responseData = AppDependencies.injector.get<T>();
        if (json['data'] is List) {
          responseData = responseData.fromJson(json) as T;
        } else {
          responseData = responseData.fromJson(json['data']) as T;
        }
        return ResponseResult(data: responseData, isSuccessful: true);
      }
    }

    throw UnimplementedError();
  }
  ResponseResult({this.data, required this.isSuccessful, this.error});
  final T? data;
  final bool isSuccessful;
  final ErrorResponseModel? error;
}

abstract class BaseResponseModel {
  BaseResponseModel fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();

  BaseResponseModel copyWith() {
    return fromJson(jsonDecode(jsonEncode(toJson())));
  }
}

class PaginationData {
  factory PaginationData.fromJson(Map<String, dynamic> json) {
    return PaginationData(
      page: json['page'],
      pageSize: json['pageSize'],
      totalItems: json['totalItems'],
      totalPages: json['totalPages'],
    );
  }
  PaginationData({this.page, this.pageSize, this.totalItems, this.totalPages});
  int? page;
  int? pageSize;
  int? totalItems;
  int? totalPages;

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'pageSize': pageSize,
      'totalItems': totalItems,
      'totalPages': totalPages,
    };
  }
}

class ListResponseModel<T extends BaseResponseModel> extends BaseResponseModel {
  ListResponseModel({this.data, this.pagination});
  List<T>? data;
  PaginationData? pagination;

  @override
  BaseResponseModel fromJson(Map<String, dynamic> json) {
    if (json['data'] != null) {
      final List<T> parseData = <T>[];
      json['data'].forEach((v) {
        T? responseData = AppDependencies.injector.get<T>();
        responseData = responseData.fromJson(v) as T;
        parseData.add(responseData);
      });
      data = parseData;
    }
    if (json['pagination'] != null) {
      pagination = PaginationData.fromJson(json['pagination']);
    }

    return ListResponseModel(data: data, pagination: pagination);
  }

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (this.data != null) {
      data['data'] = this.data!.map((v) => (v as dynamic).toJson()).toList();
    }
    if (this.pagination != null) {
      data['pagination'] = this.pagination!.toJson();
    }
    return data;
  }
}

class VoidResponseModel extends BaseResponseModel {
  @override
  VoidResponseModel fromJson(Map<String, dynamic> json) {
    return VoidResponseModel();
  }

  @override
  Map<String, dynamic> toJson() {
    return {};
  }
}
