import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/uploader_service.dart';
import 'job_model.dart';

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  return JobRepository(
    ref.watch(apiClientProvider),
    ref.watch(uploaderServiceProvider),
  );
});

class JobRepository {
  final ApiClient _api;
  final UploaderService _uploader;

  JobRepository(this._api, this._uploader);

  /// GET /jobs/for-worker/by-stats
  Future<JobStatsModel> fetchWorkerStats() async {
    final response = await _api.dio.get('/jobs/for-worker/by-stats');
    final raw = response.data;
    final Map<String, dynamic> statsMap = (raw is Map && raw['data'] is Map)
        ? Map<String, dynamic>.from(raw['data'] as Map)
        : Map<String, dynamic>.from(raw as Map);
    return JobStatsModel.fromJson(statsMap);
  }

  /// GET /jobs/for-worker/by-status?status=...&page=...&limit=...
  Future<PaginatedJobsResponse> fetchJobsByStatus({
    required String status,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _api.dio.get(
      '/jobs/for-worker/by-status',
      queryParameters: {
        'status': status,
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );
    return PaginatedJobsResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  /// GET /jobs/for-worker/single/:jobId
  Future<JobModel> fetchSingleJob(String jobId) async {
    final response = await _api.dio.get('/jobs/for-worker/single/$jobId');
    return JobModel.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  /// PATCH /jobs/for-worker/:jobId/accept
  Future<void> acceptJob({
    required String jobId,
    required double agreedBudget,
    required String commentary,
  }) async {
    await _api.dio.patch(
      '/jobs/for-worker/$jobId/accept',
      data: {'agreedBudget': agreedBudget, 'commentary': commentary},
    );
  }

  /// PATCH /jobs/for-worker/:jobId/reject
  Future<void> rejectJob(String jobId) async {
    await _api.dio.patch('/jobs/for-worker/$jobId/reject');
  }

  /// PATCH /jobs/for-worker/:jobId/complete
  Future<void> completeJob({
    required String jobId,
    required List<String> photos,
    String? commentary,
  }) async {
    await _api.dio.patch(
      '/jobs/for-worker/$jobId/complete',
      data: {
        'photos': photos,
        if (commentary != null && commentary.trim().isNotEmpty)
          'commentary': commentary.trim(),
      },
    );
  }

  /// PATCH /jobs/for-worker/:jobId/dispute
  Future<void> disputeJob(String jobId) async {
    await _api.dio.patch('/jobs/for-worker/$jobId/dispute');
  }

  /// Uploads a completion proof photo to MinIO/S3
  Future<String> uploadCompletionPhoto(File file, String jobId) async {
    return _uploader.uploadFileDirectly(
      file: file,
      endpoint: '/workers/profile/upload-url',
      payloadData: {'folder': 'jobs/$jobId/completion'},
      compress: true,
      imageContext: 'jobs',
      isGetRequest: false,
    );
  }
}
