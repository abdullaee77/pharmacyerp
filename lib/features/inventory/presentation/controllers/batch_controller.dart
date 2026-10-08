import 'package:flutter/material.dart';
import '../../../medicines/domain/medicine.dart';
import '../../domain/batch.dart';
import '../../domain/batch_repository.dart';
import '../../application/batch_use_cases.dart';

class BatchController extends ChangeNotifier {
  final GetBatchesUseCase _getBatches;
  final CreateBatchUseCase _createBatch;
  final UpdateBatchUseCase _updateBatch;
  final DeleteBatchUseCase _deleteBatch;

  BatchController({required BatchRepository repository})
      : _getBatches = GetBatchesUseCase(repository),
        _createBatch = CreateBatchUseCase(repository),
        _updateBatch = UpdateBatchUseCase(repository),
        _deleteBatch = DeleteBatchUseCase(repository);

  List<Batch> _batches = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  BatchStatus? _statusFilter;

  List<Batch> get batches => _batches;
  bool get isLoading => _isLoading;
  String? get error => _error;
  BatchStatus? get statusFilter => _statusFilter;

  Future<void> loadBatches({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    final result = await _getBatches.execute(
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      status: _statusFilter,
    );

    result.fold(
      onSuccess: (data) {
        _batches = data;
        _error = null;
        _isLoading = false;
        notifyListeners();
      },
      onFailure: (f) {
        _error = f.message;
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void search(String query) {
    _searchQuery = query;
    loadBatches();
  }

  void filterByStatus(BatchStatus? status) {
    _statusFilter = status;
    loadBatches();
  }

  Future<String?> createBatch(Batch batch) async {
    final result = await _createBatch.execute(batch);
    return result.fold(
      onSuccess: (_) {
        loadBatches();
        return null;
      },
      onFailure: (f) => f.message,
    );
  }

  Future<String?> updateBatch(Batch batch) async {
    final result = await _updateBatch.execute(batch);
    return result.fold(
      onSuccess: (_) {
        loadBatches();
        return null;
      },
      onFailure: (f) => f.message,
    );
  }

  Future<String?> deleteBatch(BatchId id) async {
    final result = await _deleteBatch.execute(id);
    return result.fold(
      onSuccess: (_) {
        loadBatches();
        return null;
      },
      onFailure: (f) => f.message,
    );
  }
}