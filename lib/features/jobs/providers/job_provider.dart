import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/job_model.dart';
import '../data/job_repository.dart';

// 1. Worker Job Stats Provider
final jobStatsProvider = FutureProvider.autoDispose<JobStatsModel>((ref) async {
  return ref.watch(jobRepositoryProvider).fetchWorkerStats();
});

// 2. Jobs List by Status Provider
final jobsByStatusProvider = FutureProvider.autoDispose
    .family<PaginatedJobsResponse, String>((ref, status) async {
      return ref.watch(jobRepositoryProvider).fetchJobsByStatus(status: status);
    });

// 3. Single Job Detail Provider
final jobDetailProvider = FutureProvider.autoDispose.family<JobModel, String>((
  ref,
  jobId,
) async {
  return ref.watch(jobRepositoryProvider).fetchSingleJob(jobId);
});

// 4. Job Action Controller (Accept, Reject, Complete, Dispute)
final jobActionControllerProvider =
    StateNotifierProvider.autoDispose<JobActionController, AsyncValue<void>>(
      (ref) => JobActionController(ref),
    );

class JobActionController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  JobActionController(this._ref) : super(const AsyncValue.data(null));

  JobRepository get _repo => _ref.read(jobRepositoryProvider);

  void _refreshAll(String jobId) {
    _ref.invalidate(jobStatsProvider);
    _ref.invalidate(jobsByStatusProvider);
    _ref.invalidate(jobDetailProvider(jobId));
  }

  Future<bool> acceptJob({
    required String jobId,
    required double agreedBudget,
    required String commentary,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.acceptJob(
        jobId: jobId,
        agreedBudget: agreedBudget,
        commentary: commentary,
      );
      _refreshAll(jobId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> rejectJob(String jobId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.rejectJob(jobId);
      _refreshAll(jobId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> completeJob({
    required String jobId,
    required List<File> localPhotos,
    String? commentary,
  }) async {
    state = const AsyncValue.loading();
    try {
      final List<String> uploadedUrls = [];
      for (final file in localPhotos) {
        final url = await _repo.uploadCompletionPhoto(file, jobId);
        uploadedUrls.add(url);
      }

      await _repo.completeJob(
        jobId: jobId,
        photos: uploadedUrls,
        commentary: commentary,
      );
      _refreshAll(jobId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> disputeJob(String jobId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.disputeJob(jobId);
      _refreshAll(jobId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}
