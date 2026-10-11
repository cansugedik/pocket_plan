
import 'package:flutter/material.dart';

class Transaction {
  final String title;
  final String category;
  final double amount;
  final IconData icon;
  final bool isIncome;

  const Transaction({
    required this.title,
    required this.category,
    required this.amount,
    required this.icon,
    required this.isIncome,
  });

  // İşlemi JSON formatına dönüştürür.
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'category': category,
      'amount': amount,
      'icon': icon.codePoint,
      'isIncome': isIncome,
    };
  }

  // JSON verisinden Transaction oluşturur.
  factory Transaction.fromJson(Map<String, dynamic> json) {
    final isIncome = json['isIncome'] as bool;

    return Transaction(
      title: json['title'] as String,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      icon: isIncome
          ? Icons.account_balance_wallet
          : Icons.shopping_cart,
      isIncome: isIncome,
    );
  }
}
