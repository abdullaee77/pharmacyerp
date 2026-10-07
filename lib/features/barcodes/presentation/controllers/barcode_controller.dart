import 'package:flutter/material.dart';
import '../../../medicines/domain/medicine.dart';
import '../../../medicines/domain/medicine_repository.dart';
import '../../application/barcode_use_cases.dart';
import '../../domain/barcode_label.dart';

/// Presentation controller for barcode scanning, assignment, and printing.
class BarcodeController extends ChangeNotifier {
  final ScanBarcodeUseCase _scan;
  final GenerateBarcodeUseCase _generate;
  final AssignBarcodeUseCase _assign;
  final MedicineRepository _medicineRepository;

  BarcodeController({required MedicineRepository medicineRepository})
      : _medicineRepository = medicineRepository,
        _scan = ScanBarcodeUseCase(medicineRepository),
        _generate = const GenerateBarcodeUseCase(),
        _assign = AssignBarcodeUseCase(medicineRepository);

  List<Medicine> _medicines = [];
  Medicine? _selectedMedicine;
  BarcodeLabel? _activeLabel;
  bool _isLoading = false;
  String? _error;

  List<Medicine> get medicines => _medicines;
  Medicine? get selectedMedicine => _selectedMedicine;
  BarcodeLabel? get activeLabel => _activeLabel;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadMedicines() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _medicineRepository.getMedicines();
    result.fold(
      onSuccess: (data) {
        _medicines = data;
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

  Future<Medicine?> scanBarcode(String code) async {
    final result = await _scan.execute(code);
    return result.fold(
      onSuccess: (m) => m,
      onFailure: (_) => null,
    );
  }

  String generateNewBarcode() => _generate.execute();

  Future<String?> assignBarcode(MedicineId medicineId, String barcode) async {
    final result = await _assign.execute(medicineId, barcode);
    return result.fold(
      onSuccess: (_) {
        loadMedicines();
        return null;
      },
      onFailure: (f) => f.message,
    );
  }

  void selectMedicine(Medicine medicine) {
    _selectedMedicine = medicine;
    _activeLabel = BarcodeLabel(
      barcode: medicine.barcode?.value ?? generateNewBarcode(),
      medicineName: medicine.name,
      price: medicine.sellingPrice.display,
      strength: medicine.strength,
    );
    notifyListeners();
  }

  void updateLabel(BarcodeLabel label) {
    _activeLabel = label;
    notifyListeners();
  }

  void clearSelection() {
    _selectedMedicine = null;
    _activeLabel = null;
    notifyListeners();
  }
}