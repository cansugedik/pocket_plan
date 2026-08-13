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
}