import '../domain/medicine.dart';
import '../../../core/domain/value_object.dart';
import '../domain/value_objects.dart';

class MedicineModel {
  final String id;
  final String name;
  final String genericName;
  final String manufacturer;
  final String dosageForm;
  final String strength;
  final String category;
  final String unit;
  final String rackLocation;
  final String drugSchedule;
  final String storageInstructions;
  final String? barcode;
  final int prescriptionRequired;
  final int minStockLevel;
  final int purchasePrice;
  final int sellingPrice;
  final int mrp;
  final int boxSize;
  final int boxPrice;
  final String status;
  final String createdAt;
  final String updatedAt;

  const MedicineModel({
    required this.id,
    required this.name,
    required this.genericName,
    required this.manufacturer,
    required this.dosageForm,
    required this.strength,
    required this.category,
    required this.unit,
    required this.rackLocation,
    required this.drugSchedule,
    required this.storageInstructions,
    this.barcode,
    required this.prescriptionRequired,
    required this.minStockLevel,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.mrp,
    required this.boxSize,
    required this.boxPrice,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MedicineModel.fromMap(Map<String, dynamic> map) {
    return MedicineModel(
      id: map['id'] as String,
      name: map['name'] as String,
      genericName: (map['generic_name'] as String?) ?? '',
      manufacturer: (map['manufacturer'] as String?) ?? '',
      dosageForm: (map['dosage_form'] as String?) ?? 'tablet',
      strength: (map['strength'] as String?) ?? '',
      category: (map['category'] as String?) ?? '',
      unit: (map['unit'] as String?) ?? 'Tab',
      rackLocation: (map['rack_location'] as String?) ?? '',
      drugSchedule: (map['drug_schedule'] as String?) ?? '',
      storageInstructions: (map['storage_instructions'] as String?) ?? '',
      barcode: map['barcode'] as String?,
      prescriptionRequired: (map['prescription_required'] as int?) ?? 0,
      minStockLevel: (map['min_stock_level'] as int?) ?? 0,
      purchasePrice: (map['purchase_price'] as int?) ?? 0,
      sellingPrice: (map['selling_price'] as int?) ?? 0,
      mrp: (map['mrp'] as int?) ?? 0,
      boxSize: (map['box_size'] as int?) ?? 1,
      boxPrice: (map['box_price'] as int?) ?? 0,
      status: (map['status'] as String?) ?? 'active',
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'generic_name': genericName,
      'manufacturer': manufacturer,
      'dosage_form': dosageForm,
      'strength': strength,
      'category': category,
      'unit': unit,
      'rack_location': rackLocation,
      'drug_schedule': drugSchedule,
      'storage_instructions': storageInstructions,
      'barcode': barcode,
      'prescription_required': prescriptionRequired,
      'min_stock_level': minStockLevel,
      'purchase_price': purchasePrice,
      'selling_price': sellingPrice,
      'mrp': mrp,
      'box_size': boxSize,
      'box_price': boxPrice,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Medicine toDomain() {
    return Medicine(
      id: MedicineId(id),
      name: name,
      genericName: genericName,
      manufacturer: manufacturer,
      dosageForm: _parseDosageForm(dosageForm),
      strength: strength,
      category: category,
      unit: unit,
      rackLocation: rackLocation,
      drugSchedule: _parseDrugSchedule(drugSchedule),
      storageInstructions: storageInstructions,
      barcode: barcode != null && barcode!.isNotEmpty
          ? Barcode.unsafe(barcode!)
          : null,
      prescriptionRequired: prescriptionRequired == 1,
      minStockLevel: Quantity.create(minStockLevel),
      purchasePrice: Money(paisa: purchasePrice),
      sellingPrice: Money(paisa: sellingPrice),
      mrp: Money(paisa: mrp),
      boxSize: boxSize,
      boxPrice: Money(paisa: boxPrice),
      status: _parseStatus(status),
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }

  factory MedicineModel.fromDomain(Medicine m) {
    return MedicineModel(
      id: m.id.value,
      name: m.name,
      genericName: m.genericName,
      manufacturer: m.manufacturer,
      dosageForm: m.dosageForm.name,
      strength: m.strength,
      category: m.category,
      unit: m.unit,
      rackLocation: m.rackLocation,
      drugSchedule: m.drugSchedule.name,
      storageInstructions: m.storageInstructions,
      barcode: m.barcode?.value,
      prescriptionRequired: m.prescriptionRequired ? 1 : 0,
      minStockLevel: m.minStockLevel.value,
      purchasePrice: m.purchasePrice.paisa,
      sellingPrice: m.sellingPrice.paisa,
      mrp: m.mrp.paisa,
      boxSize: m.boxSize,
      boxPrice: m.boxPrice.paisa,
      status: m.status.name,
      createdAt: m.createdAt.toIso8601String(),
      updatedAt: m.updatedAt.toIso8601String(),
    );
  }

  static DosageForm _parseDosageForm(String value) {
    return DosageForm.values.firstWhere(
          (e) => e.name == value,
      orElse: () => DosageForm.other,
    );
  }

  static DrugSchedule _parseDrugSchedule(String value) {
    return DrugSchedule.values.firstWhere(
          (e) => e.name == value,
      orElse: () => DrugSchedule.none,
    );
  }

  static MedicineStatus _parseStatus(String value) {
    return MedicineStatus.values.firstWhere(
          (e) => e.name == value,
      orElse: () => MedicineStatus.active,
    );
  }
}