import '../../../core/result/result.dart';
import '../domain/report_models.dart';
import '../domain/report_repository.dart';

class GenerateReportUseCase {
  final ReportRepository _repo;
  const GenerateReportUseCase(this._repo);

  Future<Result<ReportResult>> execute(
      ReportType type,
      ReportFilter filter,
      ) {
    return _repo.generateReport(type, filter);
  }
}

class GetBusinessMetricsUseCase {
  final ReportRepository _repo;
  const GetBusinessMetricsUseCase(this._repo);

  Future<Result<BusinessMetrics>> execute() {
    return _repo.getBusinessMetrics();
  }
}