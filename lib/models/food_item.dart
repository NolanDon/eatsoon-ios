import 'package:flutter/material.dart';

/// Food categories with a display label and an icon each.
enum FoodCategory { dairy, meat, produce, bakery, frozen, other }

extension FoodCategoryUi on FoodCategory {
  String get label {
    switch (this) {
      case FoodCategory.dairy:
        return 'Dairy';
      case FoodCategory.meat:
        return 'Meat';
      case FoodCategory.produce:
        return 'Produce';
      case FoodCategory.bakery:
        return 'Bakery';
      case FoodCategory.frozen:
        return 'Frozen';
      case FoodCategory.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case FoodCategory.dairy:
        return Icons.local_drink;
      case FoodCategory.meat:
        return Icons.dinner_dining;
      case FoodCategory.produce:
        return Icons.eco;
      case FoodCategory.bakery:
        return Icons.bakery_dining;
      case FoodCategory.frozen:
        return Icons.ac_unit;
      case FoodCategory.other:
        return Icons.shopping_basket;
    }
  }
}

/// A single tracked food item. [expiryDate] is stored date-only.
class FoodItem {
  FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.expiryDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String name;
  final FoodCategory category;
  final DateTime expiryDate;
  final DateTime createdAt;

  FoodItem copyWith({
    String? name,
    FoodCategory? category,
    DateTime? expiryDate,
  }) {
    return FoodItem(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      expiryDate: expiryDate ?? this.expiryDate,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'expiryDate': expiryDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: FoodCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => FoodCategory.other,
      ),
      expiryDate: DateTime.parse(json['expiryDate'] as String),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Validates raw user input before an item is created.
  /// Returns an error message, or null when valid.
  static String? validateName(String name) {
    if (name.trim().isEmpty) return 'Give your item a name';
    if (name.trim().length > 60) return 'Keep the name under 60 characters';
    return null;
  }
}
