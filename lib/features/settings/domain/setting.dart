enum SettingCategory {
  pharmacy(label: 'Pharmacy Information'),
  invoice(label: 'Invoice & Receipt'),
  tax(label: 'Tax Configuration'),
  pos(label: 'POS Settings'),
  printer(label: 'Printer Settings'),
  network(label: 'Network & LAN'),
  notifications(label: 'Notifications'),
  backup(label: 'Backup & Data');

  final String label;
  const SettingCategory({required this.label});
}

class Setting {
  final String key;
  final String value;
  final SettingCategory category;
  final String label;
  final String? description;

  const Setting({
    required this.key,
    required this.value,
    required this.category,
    required this.label,
    this.description,
  });

  Setting copyWith({String? value}) => Setting(
    key: key, value: value ?? this.value,
    category: category, label: label, description: description,
  );
}