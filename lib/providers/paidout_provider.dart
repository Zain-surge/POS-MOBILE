// lib/providers/paidout_provider.dart

import 'package:flutter/material.dart';
import '../models/paidout_models.dart';
import '../services/api_service.dart';

class PaidOutProvider with ChangeNotifier {
  List<PaidOutRecord> _todaysPaidOuts = [];
  bool _isLoading = false;
  String? _error;

  List<PaidOutRecord> get todaysPaidOuts => _todaysPaidOuts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get totalTodaysAmount {
    return _todaysPaidOuts.fold(0.0, (sum, record) => sum + record.amount);
  }

  Future<void> fetchTodaysPaidOuts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _todaysPaidOuts = await ApiService.getTodaysPaidOuts();
      _error = null;
    } catch (e) {
      _error = e.toString();
      print('Error fetching today\'s paid outs: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> submitPaidOuts(List<PaidOut> paidOuts) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await ApiService.submitPaidOuts(paidOuts);
      // Refresh the list after successful submission
      await fetchTodaysPaidOuts();
      _error = null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow; // Re-throw to let the UI handle the error
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
