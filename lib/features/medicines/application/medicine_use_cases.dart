import 'package:pharmacy/core/result/result.dart';
import 'package:pharmacy/core/error/failures.dart';
import '../domain/medicine.dart';
import '../domain/medicine_repository.dart';

class CreateMedicineUseCase {
  final MedicineRepository _repository;
  const CreateMedicineUseCase(this._repository);

  Future<Result<Medicine>> execute(Medicine medicine) async {
    if (medicine.name.trim().isEmpty) {
      return const Failure(ValidationFailure(message: 'Medicine name is required.'));
    }
    if (medicine.name.trim().length < 2) {
      return const Failure(ValidationFailure(message: 'Medicine name must be at least 2 characters.'));
    }
    if (medicine.sellingPrice.paisa < 0) {
      return const Failure(ValidationFailure(message: 'Selling price cannot be negative.'));
    }
    if (medicine.purchasePrice.paisa < 0) {
      return const Failure(ValidationFailure(message: 'Purchase price cannot be negative.'));
    }
    if (medicine.mrp.paisa < 0) {
      return const Failure(ValidationFailure(message: 'MRP cannot be negative.'));
    }
    if (!medicine.isPriceValid) {
      return const Failure(ValidationFailure(message: 'Selling price cannot exceed MRP.'));
    }
    if (medicine.boxSize < 1) {
      return const Failure(ValidationFailure(message: 'Box size must be at least 1.'));
    }
    return _repository.createMedicine(medicine);
  }
}

class UpdateMedicineUseCase {
  final MedicineRepository _repository;
  const UpdateMedicineUseCase(this._repository);

  Future<Result<Medicine>> execute(Medicine medicine) async {
    if (medicine.name.trim().isEmpty) {
      return const Failure(ValidationFailure(message: 'Medicine name is required.'));
    }
    if (!medicine.isPriceValid) {
      return const Failure(ValidationFailure(message: 'Selling price cannot exceed MRP.'));
    }
    return _repository.updateMedicine(medicine);
  }
}

class GetMedicinesUseCase {
  final MedicineRepository _repository;
  const GetMedicinesUseCase(this._repository);

  Future<Result<List<Medicine>>> execute({
    MedicineFilter filter = const MedicineFilter(),
  }) async {
    return _repository.getMedicines(filter: filter);
  }
}

class GetMedicineByIdUseCase {
  final MedicineRepository _repository;
  const GetMedicineByIdUseCase(this._repository);

  Future<Result<Medicine>> execute(MedicineId id) async {
    return _repository.getMedicineById(id);
  }
}

class DeleteMedicineUseCase {
  final MedicineRepository _repository;
  const DeleteMedicineUseCase(this._repository);

  Future<Result<void>> execute(MedicineId id) async {
    return _repository.deleteMedicine(id);
  }
}