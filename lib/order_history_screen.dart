// lib/order_history_screen.dart

import 'package:flutter/material.dart';
import 'package:epos/models/order.dart';
import 'package:epos/providers/order_history_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  DateTime? _selectedDate;
  Order? _selectedOrder;

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _selectedOrder = null;
      });

      final provider = Provider.of<OrderHistoryProvider>(
        context,
        listen: false,
      );
      await provider.fetchOrdersByDate(picked);
    }
  }

  String _formatOrderDate(DateTime dateTime) {
    return DateFormat('dd MMM yyyy').format(dateTime);
  }

  String _formatOrderTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  /// Map status to display text (case-sensitive)
  String _getStatusDisplayText(String status) {
    switch (status) {
      case 'yellow':
        return 'PENDING';
      case 'green':
        return 'READY';
      case 'blue':
        return 'COMPLETED';
      default:
        return status.toUpperCase();
    }
  }

  /// Get background color for status badge
  Color _getStatusBackgroundColor(String status) {
    switch (status) {
      case 'yellow':
        return Colors.yellow.shade100;
      case 'green':
        return Colors.green.shade100;
      case 'blue':
        return Colors.blue.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  /// Get text color for status badge
  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'yellow':
        return Colors.orange.shade900;
      case 'green':
        return Colors.green.shade900;
      case 'blue':
        return Colors.blue.shade900;
      default:
        return Colors.grey.shade700;
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_back_ios,
                color: Colors.grey.shade600,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Order History title
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Order History",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: InkWell(
        onTap: _selectDate,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.black, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedDate != null
                      ? _formatOrderDate(_selectedDate!)
                      : 'Select a date to view orders',
                  style: TextStyle(
                    fontSize: 16,
                    color:
                        _selectedDate != null
                            ? Colors.black
                            : Colors.grey.shade600,
                    fontWeight:
                        _selectedDate != null
                            ? FontWeight.w500
                            : FontWeight.normal,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(OrderHistoryProvider provider) {
    final paidFilter = provider.paidStatusFilter;
    final sourceOptions = provider.availableOrderSourceOptions;
    final paymentOptions = provider.availablePaymentTypeOptions;
    final orderTypeOptions = provider.availableOrderTypeOptions;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Payment Status',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        PaidStatusFilter.values
                            .map(
                              (filter) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _buildChoiceChip(
                                  label: _paidStatusLabel(filter),
                                  isSelected: paidFilter == filter,
                                  onSelected:
                                      () =>
                                          provider.setPaidStatusFilter(filter),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
              ),
            ],
          ),
          if (sourceOptions.isNotEmpty ||
              paymentOptions.isNotEmpty ||
              orderTypeOptions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDropdownSection(
              sourceOptions: sourceOptions,
              paymentOptions: paymentOptions,
              orderTypeOptions: orderTypeOptions,
              provider: provider,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (!selected) return;
        onSelected();
      },
      visualDensity: VisualDensity.compact,
      selectedColor: Colors.black,
      backgroundColor: Colors.grey.shade200,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: isSelected ? Colors.black : Colors.transparent),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<FilterOption> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String?>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w500,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black),
        ),
      ),
      icon: const Icon(Icons.arrow_drop_down),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('All')),
        ...options.map(
          (option) => DropdownMenuItem<String?>(
            value: option.value,
            child: Text(option.label),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildDropdownSection({
    required List<FilterOption> sourceOptions,
    required List<FilterOption> paymentOptions,
    required List<FilterOption> orderTypeOptions,
    required OrderHistoryProvider provider,
  }) {
    final dropdownBuilders = <Widget Function()>[];

    void addDropdown({
      required String label,
      required String? value,
      required List<FilterOption> options,
      required ValueChanged<String?> onChanged,
    }) {
      dropdownBuilders.add(
        () => _buildDropdown(
          label: label,
          value: value,
          options: options,
          onChanged: onChanged,
        ),
      );
    }

    if (sourceOptions.isNotEmpty) {
      addDropdown(
        label: 'Order Source',
        value: provider.orderSourceFilter,
        options: sourceOptions,
        onChanged: provider.setOrderSourceFilter,
      );
    }

    if (paymentOptions.isNotEmpty) {
      addDropdown(
        label: 'Payment Type',
        value: provider.paymentTypeFilter,
        options: paymentOptions,
        onChanged: provider.setPaymentTypeFilter,
      );
    }

    if (orderTypeOptions.isNotEmpty) {
      addDropdown(
        label: 'Order Type',
        value: provider.orderTypeFilter,
        options: orderTypeOptions,
        onChanged: provider.setOrderTypeFilter,
      );
    }

    if (dropdownBuilders.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;
        if (isCompact) {
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children:
                dropdownBuilders
                    .map(
                      (builder) => ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: 180,
                          maxWidth:
                              constraints.maxWidth < 260
                                  ? constraints.maxWidth
                                  : 260,
                        ),
                        child: builder(),
                      ),
                    )
                    .toList(),
          );
        }

        final children = <Widget>[];
        for (var i = 0; i < dropdownBuilders.length; i++) {
          children.add(
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: i == dropdownBuilders.length - 1 ? 0 : 12,
                ),
                child: dropdownBuilders[i](),
              ),
            ),
          );
        }

        return Row(children: children);
      },
    );
  }

  String _paidStatusLabel(PaidStatusFilter filter) {
    switch (filter) {
      case PaidStatusFilter.all:
        return 'All';
      case PaidStatusFilter.paid:
        return 'Paid';
      case PaidStatusFilter.unpaid:
        return 'Unpaid';
    }
  }

  Widget _buildOrdersList(List<Order> orders) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final isSelected = _selectedOrder?.orderId == order.orderId;

        return GestureDetector(
          onTap: () {
            _showOrderDetails(order);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? Colors.grey.shade100 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.black : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            'Order #${order.displayOrderNumber}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusBackgroundColor(order.status),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getStatusDisplayText(order.status),
                              style: TextStyle(
                                color: _getStatusTextColor(order.status),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatOrderTime(order.createdAt),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (order.isEdited) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Edited',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.customerName.isNotEmpty
                              ? order.customerName
                              : 'No Name',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.orderType,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '£${order.orderTotalPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOrderDetails(Order order) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.85,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order #${order.displayOrderNumber}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  _formatOrderDate(order.createdAt),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                if (order.isEdited) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Edited',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Customer Info
                          _buildSection('Customer Information', [
                            _buildRow(
                              'Name',
                              order.customerName.isNotEmpty
                                  ? order.customerName
                                  : 'N/A',
                            ),
                            if (order.phoneNumber != null &&
                                order.phoneNumber!.isNotEmpty)
                              _buildRow('Phone', order.phoneNumber!),
                            if (order.customerEmail != null &&
                                order.customerEmail!.isNotEmpty)
                              _buildRow('Email', order.customerEmail!),
                          ]),
                          const SizedBox(height: 20),
                          // Order Info
                          _buildSection('Order Details', [
                            _buildRow('Type', order.orderType),
                            _buildRow('Source', order.orderSource),
                            _buildRow(
                              'Status',
                              _getStatusDisplayText(order.status),
                            ),
                            _buildRow('Payment', order.paymentType),
                            _buildRow('Paid', order.paidStatus ? 'Yes' : 'No'),
                            if (order.streetAddress != null &&
                                order.streetAddress!.isNotEmpty)
                              _buildRow('Address', order.streetAddress!),
                          ]),
                          const SizedBox(height: 20),
                          // Items
                          const Text(
                            'Order Items',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...order.items.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            return _buildItemCard(item, index);
                          }).toList(),
                          const SizedBox(height: 20),
                          // Show discount if present
                          if (order.discountPercentage != null &&
                              order.discountPercentage! > 0) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Discount (${order.discountPercentage!.toStringAsFixed(1)}%)',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '- £${(order.discountAmount ?? 0).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF90EE90),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          // Total
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '£${order.orderTotalPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSection(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(OrderItem item, int index) {
    // Parse options from description
    List<String> options = [];
    if (item.description.isNotEmpty) {
      final lines = item.description.split('\n');
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isNotEmpty) {
          options.add(line);
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (options.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...options
                      .map(
                        (option) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $option',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '×${item.quantity}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '£${item.totalPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildDateSelector(),
            Expanded(
              child: Consumer<OrderHistoryProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (provider.error != null) {
                    return _buildEmptyState(
                      provider.error!,
                      Icons.error_outline,
                    );
                  }

                  if (provider.selectedDate == null) {
                    return _buildEmptyState(
                      'Select a date to view order history',
                      Icons.calendar_today,
                    );
                  }

                  final hasAnyOrders = provider.totalOrdersCount > 0;
                  final hasFilteredOrders = provider.orders.isNotEmpty;

                  final Widget content;
                  if (!hasAnyOrders) {
                    content = _buildEmptyState(
                      'No orders found for ${_formatOrderDate(provider.selectedDate!)}',
                      Icons.inbox,
                    );
                  } else if (!hasFilteredOrders) {
                    content = _buildEmptyState(
                      'No orders match the selected filters',
                      Icons.filter_list,
                    );
                  } else {
                    content = _buildOrdersList(provider.orders);
                  }

                  return Column(
                    children: [
                      _buildFilters(provider),
                      const SizedBox(height: 12),
                      Expanded(child: content),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
