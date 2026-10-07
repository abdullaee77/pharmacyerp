import '../../../core/result/result.dart';
import 'report_models.dart';

abstract class ReportRepository {
  Future<Result<ReportResult>> generateReport(
      ReportType type,
      ReportFilter filter,
      );

  Future<Result<BusinessMetrics>> getBusinessMetrics();
}