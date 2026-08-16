import 'dart:convert';

import 'package:http/http.dart' as http;

class ArchitectureSaveResult {
  const ArchitectureSaveResult({required this.id, required this.version});

  final String id;
  final int version;
}

class DeploymentRequestResult {
  const DeploymentRequestResult({
    required this.id,
    required this.status,
    required this.message,
    required this.endpoint,
  });

  final String id;
  final String status;
  final String message;
  final String endpoint;
}

class DeployedAgent {
  const DeployedAgent({
    required this.id,
    required this.name,
    required this.status,
    required this.endpoint,
    required this.architectureVersion,
    required this.runtimeVersion,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String status;
  final String endpoint;
  final int architectureVersion;
  final String runtimeVersion;
  final DateTime? createdAt;
}

class AgentInvocationResult {
  const AgentInvocationResult({
    required this.output,
    required this.model,
    required this.responseId,
    required this.usage,
    required this.apiResults,
  });

  final String output;
  final String model;
  final String? responseId;
  final Map<String, dynamic> usage;
  final List<ApiCallResult> apiResults;
}

class ApiCallResult {
  const ApiCallResult({
    required this.title,
    required this.statusCode,
    required this.body,
  });

  final String title;
  final int statusCode;
  final String body;
}

class AgentBuilderApi {
  AgentBuilderApi({String? baseUrl})
    : baseUrl = (baseUrl ?? '/api').replaceFirst(RegExp(r'/$'), '');

  final String baseUrl;

  Future<ArchitectureSaveResult> saveArchitecture(
    Map<String, dynamic> architecture, {
    String? architectureId,
  }) async {
    final uri = architectureId == null
        ? Uri.parse('$baseUrl/architectures')
        : Uri.parse('$baseUrl/architectures/$architectureId');
    final response = architectureId == null
        ? await http.post(
            uri,
            headers: _headers,
            body: jsonEncode(architecture),
          )
        : await http.put(
            uri,
            headers: _headers,
            body: jsonEncode(architecture),
          );
    final body = _decodeResponse(response);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AgentApiException.fromResponse(response.statusCode, body);
    }
    return ArchitectureSaveResult(
      id: body['id'] as String,
      version: body['version'] as int,
    );
  }

  Future<DeploymentRequestResult> requestDeployment(
    String architectureId,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/architectures/$architectureId/deploy'),
      headers: _headers,
    );
    final body = _decodeResponse(response);
    if (response.statusCode != 201) {
      throw AgentApiException.fromResponse(response.statusCode, body);
    }
    return DeploymentRequestResult(
      id: body['id'] as String,
      status: body['status'] as String,
      message: body['message'] as String? ?? '',
      endpoint: body['endpoint'] as String? ?? '',
    );
  }

  Future<List<DeployedAgent>> listDeployments({String search = ''}) async {
    final uri = Uri.parse('$baseUrl/deployments').replace(
      queryParameters: search.trim().isEmpty ? null : {'search': search.trim()},
    );
    final response = await http.get(uri, headers: _headers);
    final body = _decodeResponse(response);
    if (response.statusCode != 200) {
      throw AgentApiException.fromResponse(response.statusCode, body);
    }
    return (body['items'] as List? ?? []).map((item) {
      final value = Map<String, dynamic>.from(item as Map);
      return DeployedAgent(
        id: value['id'] as String,
        name: value['name'] as String? ?? 'Deployed agent',
        status: value['status'] as String? ?? 'unknown',
        endpoint: value['endpoint'] as String? ?? '',
        architectureVersion: value['architectureVersion'] as int? ?? 1,
        runtimeVersion: value['runtimeVersion'] as String? ?? '1.0',
        createdAt: DateTime.tryParse(value['createdAt'] as String? ?? ''),
      );
    }).toList();
  }

  Future<AgentInvocationResult> invokeDeployment(
    String deploymentId,
    String input,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/deployments/$deploymentId/invoke'),
      headers: _headers,
      body: jsonEncode({'input': input}),
    );
    final body = _decodeResponse(response);
    if (response.statusCode != 200) {
      throw AgentApiException.fromResponse(response.statusCode, body);
    }
    return AgentInvocationResult(
      output: body['output'] as String? ?? '',
      model: body['model'] as String? ?? '',
      responseId: body['responseId'] as String?,
      usage: Map<String, dynamic>.from(body['usage'] as Map? ?? {}),
      apiResults: (body['apiResults'] as List? ?? []).map((item) {
        final value = Map<String, dynamic>.from(item as Map);
        return ApiCallResult(
          title: value['title'] as String? ?? 'API call',
          statusCode: value['statusCode'] as int? ?? 0,
          body: value['body'] as String? ?? '',
        );
      }).toList(),
    );
  }

  static const _headers = {'Content-Type': 'application/json'};

  Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      throw AgentApiException(
        'The architecture API returned an unreadable response (${response.statusCode}).',
      );
    }
  }
}

class AgentApiException implements Exception {
  const AgentApiException(this.message);

  factory AgentApiException.fromResponse(
    int statusCode,
    Map<String, dynamic> body,
  ) {
    final details = (body['details'] as List?)?.join('\n');
    final message =
        body['error'] as String? ?? 'Architecture API request failed.';
    return AgentApiException(
      details == null ? '$message ($statusCode)' : '$message\n$details',
    );
  }

  final String message;

  @override
  String toString() => message;
}
