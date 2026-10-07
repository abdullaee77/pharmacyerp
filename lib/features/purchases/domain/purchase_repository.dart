import '../../../core/result/result.dart';
import 'purchase.dart';
import 'purchase_return.dart';

abstract class PurchaseRepository {
  // Purchases
  Future<Result<Purchase>> createPurchase(Purchase purchase);
  Future<Result<List<Purchase>>> getPurchases({String? searchQuery});
  Future<Result<Purchase>> getPurchaseById(PurchaseId id);

  // Purchase Returns
  Future<Result<PurchaseReturn>> createPurchaseReturn(PurchaseReturn returnDoc);
  Future<Result<List<PurchaseReturn>>> getReturnsForPurchase(PurchaseId id);
  Future<Result<Map<String, int>>> getReturnedQuantities(PurchaseId id);
}