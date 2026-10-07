import 'dart:math';
import '../../../core/domain/entity.dart';
import '../../../core/domain/value_object.dart';
import 'value_objects.dart';

class MedicineId extends ValueObject {
  final String value;
  const MedicineId(this.value);

  factory MedicineId.generate() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(99999).toString().padLeft(5, '0');
    return MedicineId('med_${ts}_$rand');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is MedicineId && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

enum MedicineStatus {
  active(label: 'Active'),
  inactive(label: 'Inactive'),
  discontinued(label: 'Discontinued');

  final String label;
  const MedicineStatus({required this.label});
}

enum DosageForm {
  tablet(label: 'Tablet'),
  capsule(label: 'Capsule'),
  syrup(label: 'Syrup'),
  injection(label: 'Injection'),
  cream(label: 'Cream'),
  ointment(label: 'Ointment'),
  drops(label: 'Drops'),
  inhaler(label: 'Inhaler'),
  suppository(label: 'Suppository'),
  powder(label: 'Powder'),
  gel(label: 'Gel'),
  spray(label: 'Spray'),
  solution(label: 'Solution'),
  suspension(label: 'Suspension'),
  sachet(label: 'Sachet'),
  lotion(label: 'Lotion'),
  shampoo(label: 'Shampoo'),
  soap(label: 'Soap'),
  other(label: 'Other');

  final String label;
  const DosageForm({required this.label});
}

/// Pakistan drug schedules (Abu Zarr style)
enum DrugSchedule {
  none(label: 'None'),
  scheduleG(label: 'Schedule G'),
  scheduleH(label: 'Schedule H'),
  scheduleI(label: 'Schedule I'),
  scheduleJ(label: 'Schedule J'),
  scheduleK(label: 'Schedule K'),
  scheduleL(label: 'Schedule L'),
  scheduleM(label: 'Schedule M'),
  scheduleN(label: 'Schedule N');

  final String label;
  const DrugSchedule({required this.label});
}

class Medicine extends Entity<MedicineId> {
  final String name;
  final String genericName;
  final String manufacturer;
  final DosageForm dosageForm;
  final String strength;
  final String category;
  final String unit;
  final String rackLocation;
  final DrugSchedule drugSchedule;
  final String storageInstructions;
  final Barcode? barcode;
  final bool prescriptionRequired;
  final Quantity minStockLevel;
  final Money purchasePrice;
  final Money sellingPrice;
  final Money mrp;
  final int boxSize;
  final Money boxPrice;
  final MedicineStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Medicine({
    required super.id,
    required this.name,
    required this.genericName,
    required this.manufacturer,
    required this.dosageForm,
    required this.strength,
    required this.category,
    this.unit = 'Tab',
    this.rackLocation = '',
    this.drugSchedule = DrugSchedule.none,
    this.storageInstructions = '',
    this.barcode,
    this.prescriptionRequired = false,
    required this.minStockLevel,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.mrp,
    this.boxSize = 1,
    this.boxPrice = const Money(paisa: 0),
    this.status = MedicineStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  int get packSize => boxSize;

  Money get effectiveSellingPrice {
    if (sellingPrice.paisa > 0) return sellingPrice;
    if (boxPrice.paisa > 0 && boxSize > 0) {
      return Money(paisa: boxPrice.paisa ~/ boxSize);
    }
    return sellingPrice;
  }

  Money get effectivePurchasePrice {
    if (purchasePrice.paisa > 0) return purchasePrice;
    if (boxPrice.paisa > 0 && boxSize > 0) {
      return Money(paisa: boxPrice.paisa ~/ boxSize);
    }
    return purchasePrice;
  }

  Money get profitPerUnit => effectiveSellingPrice - effectivePurchasePrice;
  bool get isPriceValid => sellingPrice.paisa <= mrp.paisa || mrp.isZero;

  Medicine copyWith({
    String? name,
    String? genericName,
    String? manufacturer,
    DosageForm? dosageForm,
    String? strength,
    String? category,
    String? unit,
    String? rackLocation,
    DrugSchedule? drugSchedule,
    String? storageInstructions,
    Barcode? barcode,
    bool? prescriptionRequired,
    Quantity? minStockLevel,
    Money? purchasePrice,
    Money? sellingPrice,
    Money? mrp,
    int? boxSize,
    Money? boxPrice,
    MedicineStatus? status,
    DateTime? updatedAt,
  }) {
    return Medicine(
      id: id,
      name: name ?? this.name,
      genericName: genericName ?? this.genericName,
      manufacturer: manufacturer ?? this.manufacturer,
      dosageForm: dosageForm ?? this.dosageForm,
      strength: strength ?? this.strength,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      rackLocation: rackLocation ?? this.rackLocation,
      drugSchedule: drugSchedule ?? this.drugSchedule,
      storageInstructions: storageInstructions ?? this.storageInstructions,
      barcode: barcode ?? this.barcode,
      prescriptionRequired: prescriptionRequired ?? this.prescriptionRequired,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      mrp: mrp ?? this.mrp,
      boxSize: boxSize ?? this.boxSize,
      boxPrice: boxPrice ?? this.boxPrice,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() => 'Medicine($name, ${dosageForm.label}, $strength)';
}