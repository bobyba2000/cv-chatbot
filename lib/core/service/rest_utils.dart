import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

import '../../generated/l10n.dart';
import '../dependencies/app.dart';
import '../model/base_request_model.dart';
import '../model/base_response_model.dart';
import 'result.dart';

enum Method { get, post, put, delete }

class RestUtils {
  RestUtils(this.baseUrl);
  var logger = AppDependencies.injector.get<Logger>();
  String baseUrl;

  Uri _buildUri(String urlPath, {Map<String, String>? queryParameters}) {
    if (queryParameters != null) {
      final Map<String, String> query = {};
      for (final param in queryParameters.entries) {
        final value = param.value.toString();
        if (value != '') {
          query[param.key] = value;
        }
      }
      if (kDebugMode) {
        return Uri.http(baseUrl, urlPath, query);
      }
      return Uri.https(baseUrl, urlPath, query);
    }

    if (kDebugMode) {
      return Uri.http(baseUrl, urlPath);
    }
    return Uri.https(baseUrl, urlPath);
  }

  Future<Result<Map<String, dynamic>>> sendRawRequest(
    Method method,
    String urlPath, {
    Map<String, dynamic>? jsonData,
    Map<String, String>? queryParameters,
  }) async {
    try {
      final uri = _buildUri(urlPath, queryParameters: queryParameters);
      final headers = {'Content-Type': 'application/json'};
      final body = jsonData == null ? null : jsonEncode(jsonData);

      http.Response response;
      switch (method) {
        case Method.get:
          response = await http.get(uri, headers: headers);
          break;
        case Method.post:
          response = await http.post(uri, headers: headers, body: body);
          break;
        case Method.put:
          response = await http.put(uri, headers: headers, body: body);
          break;
        case Method.delete:
          response = await http.delete(uri, headers: headers, body: body);
          break;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        final message = 'Unexpected response format';
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return Failed<Map<String, dynamic>>(
            response.statusCode.toString(),
            message,
          );
        }
        return Failed<Map<String, dynamic>>(
          response.statusCode.toString(),
          message,
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Success<Map<String, dynamic>>(decoded);
      }
      return Failed<Map<String, dynamic>>(
        response.statusCode.toString(),
        decoded['message']?.toString() ?? S.current.unknownError,
      );
    } catch (e) {
      logger.e('❌ RESPONSE[null] => PATH: $urlPath \n ErrMessage: $e');
      return Failed<Map<String, dynamic>>('500', S.current.unknownError);
    }
  }

  Future<Result<Map<String, dynamic>>> sendMultipartRequest(
    String urlPath, {
    required String fileField,
    required List<int> fileBytes,
    required String filename,
    Map<String, String>? fields,
  }) async {
    try {
      final uri = _buildUri(urlPath);
      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          http.MultipartFile.fromBytes(
            fileField,
            fileBytes,
            filename: filename,
          ),
        );

      if (fields != null) {
        request.fields.addAll(fields);
      }

      final response = await request.send();
      final body = await response.stream.bytesToString();
      final decoded = jsonDecode(body);

      if (decoded is! Map<String, dynamic>) {
        final message = 'Unexpected response format';
        return Failed<Map<String, dynamic>>(
          response.statusCode.toString(),
          message,
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Success<Map<String, dynamic>>(decoded);
      }
      return Failed<Map<String, dynamic>>(
        response.statusCode.toString(),
        decoded['message']?.toString() ?? S.current.unknownError,
      );
    } catch (e) {
      logger.e(
        '❌ MULTIPART_RESPONSE[null] => PATH: $urlPath \n ErrMessage: $e',
      );
      return Failed<Map<String, dynamic>>('500', S.current.unknownError);
    }
  }

  Future<Result<T>> sendRequest<T extends BaseResponseModel>(
    Method method,
    String urlPath, {
    BaseRequestModel? data,
    Map<String, dynamic>? jsonData,
    List<dynamic>? jsonListData,
    Map<String, String>? queryParameters,
  }) async {
    try {
      final uri = _buildUri(urlPath, queryParameters: queryParameters);
      // final token = AppDependencies.injector.get<LocalService>().getString(
      //   LocalKeyConstants.token,
      // );

      final headers = {
        'Content-Type': 'application/json',
        // if (token != null && urlPath != AppPath.login)
        //   'Authorization': 'Bearer $token',
      };
      final String? jsonBody =
          jsonData == null && data == null && jsonListData == null
          ? null
          : json.encode(jsonData ?? data?.toJson() ?? jsonListData);
      if (method == Method.get) {
        logger.d('✈️ REQUEST[${method.toString()}] => PATH: $uri \n');
      } else {
        try {
          logger.d(
            '✈️ REQUEST[${method.toString()}] => PATH: $uri \n DATA: ${jsonEncode(data)}',
          );
        } catch (e) {
          logger.e('✈️ REQUEST[$method] => PATH: $uri \n DATA: $data');
        }
      }
      final encoding = Encoding.getByName('utf-8');
      http.Response? response;
      switch (method) {
        case Method.get:
          response = await http
              .get(uri, headers: headers)
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  return http.Response(timeoutError, 500);
                },
              );
          break;
        case Method.post:
          response = await http
              .post(uri, headers: headers, encoding: encoding, body: jsonBody)
              .timeout(
                const Duration(seconds: 60),
                onTimeout: () {
                  return http.Response(timeoutError, 500);
                },
              );
          break;
        case Method.delete:
          response = await http
              .delete(uri, headers: headers, body: jsonBody, encoding: encoding)
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () {
                  return http.Response(timeoutError, 500);
                },
              );
          break;
        case Method.put:
          response = await http
              .put(uri, headers: headers, body: jsonBody, encoding: encoding)
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () {
                  return http.Response(timeoutError, 500);
                },
              );
          break;
      }
      final ResponseResult<T> result = ResponseResult<T>.fromJson(
        jsonDecode(response.body),
      );
      if (response.statusCode == 200) {
        logger.d('✅ RESPONSE[200] => PATH: $uri\n DATA: ${response.body}');
        return Success<T>(result.data);
      } else {
        logger.e(
          '❌ RESPONSE[${response.statusCode}] => PATH: $uri\n ErrMessage: $response',
        );
        return Failed<T>(
          response.statusCode.toString(),
          result.error?.message ?? S.current.unknownError,
        );
      }
    } catch (e) {
      logger.e('❌ RESPONSE[null] => PATH: $urlPath \n ErrMessage: $e');
      return Failed<T>('500', S.current.unknownError);
    }
  }

  static String get timeoutError {
    final Map<String, dynamic> err = {
      'is_success': false,
      'data': '',
      'err_code': '500',
      'message': 'Time out request',
    };
    return jsonEncode(err);
  }
}
