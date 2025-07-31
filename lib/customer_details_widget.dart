// lib/customer_details_widget.dart

import 'package:flutter/material.dart';
import 'package:epos/models/order_models.dart';
import 'package:epos/services/order_api_service.dart';
import 'package:epos/models/customer_search_model.dart';


class CustomerDetailsWidget extends StatefulWidget {
  final double subtotal;
  final String orderType;
  final Function(CustomerDetails) onCustomerDetailsSubmitted;
  final VoidCallback? onBack;

  const CustomerDetailsWidget({
    super.key,
    required this.subtotal,
    required this.orderType,
    required this.onCustomerDetailsSubmitted,
    this.onBack,
  });

  @override
  State<CustomerDetailsWidget> createState() => _CustomerDetailsWidgetState();
}

class _CustomerDetailsWidgetState extends State<CustomerDetailsWidget> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();

  bool _isSearching = false; // New state variable for loading indicator

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  final RegExp _nameRegExp = RegExp(r"^[a-zA-Z\s-']+$");

  final RegExp _emailRegExp = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");

  // --- REVISED _validateUKPhoneNumber FUNCTION USING REGEX ---
  bool _validateUKPhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) return false;

    // Remove any spaces, hyphens, or parentheses for a cleaner check
    String cleanedNumber = phoneNumber.replaceAll(RegExp(r'[()\s-]'), '');

    // Regex for common UK phone numbers:
    // ^                           Start of the string
    // (?:(?:\+|00)44|0)          Starts with +44, 0044, or 0 (non-capturing group)
    // \d{9,10}                    Followed by 9 or 10 digits (total 10-11 digits after 0, or 11-12 after +44/0044)
    // $                           End of the string
    final RegExp finalUkPhoneRegex = RegExp(r'^(?:(?:\+|00)44|0)\d{9,10}$');

    return finalUkPhoneRegex.hasMatch(cleanedNumber);
  }
  // --- END REVISED _validateUKPhoneNumber FUNCTION ---


  Future<void> _searchCustomer() async {
    // Validate phone number field first
    if (_phoneController.text.isEmpty || !_validateUKPhoneNumber(_phoneController.text)) {
      // If validation fails, show the error message in the TextFormField
      _formKey.currentState?.validate();
      return;
    }

    setState(() {
      _isSearching = true; // Show loading indicator
    });

    // Clean the phone number before sending to the API.
    // The regex ensures it's already in a mostly clean format,
    // but remove any remaining spaces/hyphens for the API call.
    String phoneNumberToSend = _phoneController.text.trim().replaceAll(RegExp(r'[()\s-]'), '');

    try {
      final CustomerSearchResponse? customer =
      await OrderApiService.searchCustomerByPhoneNumber(phoneNumberToSend);

      if (customer != null) {
        // Customer found, fill the fields
        _nameController.text = customer.name;
        _emailController.text = customer.email ?? ''; // Use empty string if email is null
        _phoneController.text = customer.phoneNumber; // Use backend's cleaned number

        if (widget.orderType.toLowerCase() == 'delivery') {
          if (customer.address != null) {
            _addressController.text = customer.address!.street;
            _cityController.text = customer.address!.city;
            // county is optional, currently not used in UI but can be added if needed
            _postalCodeController.text = customer.address!.postalCode;
          } else {
            // Clear address fields if no address returned even for a delivery order
            _addressController.clear();
            _cityController.clear();
            _postalCodeController.clear();
          }
        } else {
          // If it's not a delivery order, always clear address fields after search
          _addressController.clear();
          _cityController.clear();
          _postalCodeController.clear();
        }


        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer found and details filled!')),
        );
      } else {
        // Customer not found (API returned null/empty response or 404)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number not found. Please enter details manually.')),
        );
        // Clear all relevant fields for manual entry, but keep phone number
        _nameController.clear();
        _emailController.clear();
        if (widget.orderType.toLowerCase() == 'delivery') {
          _addressController.clear();
          _cityController.clear();
          _postalCodeController.clear();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching customer: ${e.toString()}')),
      );
      debugPrint('Error searching customer: $e');
    } finally {
      setState(() {
        _isSearching = false; // Hide loading indicator
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    // Wrap the entire Column with GestureDetector
    return GestureDetector(
      onTap: () {
        // This line unfocuses the current focus node, effectively closing the keyboard.
        FocusScope.of(context).unfocus();
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 20.0, bottom: 16.0),
            child: Row(
              children: [
                if (widget.onBack != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 3.0),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      iconSize: 26,
                      onPressed: widget.onBack,
                    ),
                  ),
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3D9FF),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        'Customer Details  (${widget.orderType.toUpperCase()})',
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),

          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 42.0),
            child: Divider(
              thickness: 2,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 30),

          // Form content in center
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Phone Field (moved to top)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontFamily: 'Poppins',
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Phone Number *',
                                  hintText: 'e.g., 07123456789 or +44 7123 456789',
                                  labelStyle: const TextStyle(
                                    fontSize: 16,
                                    fontFamily: 'Poppins',
                                    color: Colors.grey,
                                  ),
                                  hintStyle: const TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'Poppins',
                                    color: Colors.grey,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: const BorderSide(color: Colors.grey, width: 1),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: const BorderSide(color: Color(0xFFCB6CE6), width: 2.0),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                                ),
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter phone number';
                                  }
                                  if (!_validateUKPhoneNumber(value)) {
                                    return 'Please enter a valid UK phone number';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              height: 60,
                              width: 60,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: IconButton(
                                icon: _isSearching // Show CircularProgressIndicator if searching
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Icon(
                                  Icons.search,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onPressed: _isSearching ? null : _searchCustomer, // Disable button if searching
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Name Field
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        child: TextFormField(
                          controller: _nameController,
                          style: const TextStyle(
                            fontSize: 18,
                            fontFamily: 'Poppins',
                          ),
                          decoration: InputDecoration(
                            labelText: 'Customer Name *',
                            labelStyle: const TextStyle(
                              fontSize: 16,
                              fontFamily: 'Poppins',
                              color: Colors.grey,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(color: Colors.grey, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(color: Color(0xFFCB6CE6), width: 2.0),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter customer name';
                            }
                            // Validate for characters only
                            if (!_nameRegExp.hasMatch(value)) {
                              return 'Name can only contain letters, spaces, hyphens, or apostrophes';
                            }
                            return null;
                          },
                        ),
                      ),

                      // Email Field
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        child: TextFormField(
                          controller: _emailController,
                          style: const TextStyle(
                            fontSize: 18,
                            fontFamily: 'Poppins',
                          ),
                          decoration: InputDecoration(
                            labelText: widget.orderType.toLowerCase() == 'delivery' ? 'Email *' : 'Email (Optional)',
                            labelStyle: const TextStyle(
                              fontSize: 16,
                              fontFamily: 'Poppins',
                              color: Colors.grey,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(color: Colors.grey, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(color: Color(0xFFCB6CE6), width: 2.0),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (widget.orderType.toLowerCase() == 'delivery' && (value == null || value.isEmpty)) {
                              return 'Email is required for delivery';
                            }
                            if (value != null && value.isNotEmpty) {
                              // Validate for email format only if not empty
                              if (!_emailRegExp.hasMatch(value)) {
                                return 'Enter a valid email address';
                              }
                            }
                            return null;
                          },
                        ),
                      ),

                      // Address fields (only for delivery)
                      if (widget.orderType.toLowerCase() == 'delivery') ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          child: TextFormField(
                            controller: _addressController,
                            style: const TextStyle(
                              fontSize: 18,
                              fontFamily: 'Poppins',
                            ),
                            decoration: InputDecoration(
                              labelText: 'Street Address *',
                              labelStyle: const TextStyle(
                                fontSize: 16,
                                fontFamily: 'Poppins',
                                color: Colors.grey,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey, width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Color(0xFFCB6CE6), width: 2.0),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter street address';
                              }
                              return null;
                            },
                          ),
                        ),

                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          child: TextFormField(
                            controller: _cityController,
                            style: const TextStyle(
                              fontSize: 18,
                              fontFamily: 'Poppins',
                            ),
                            decoration: InputDecoration(
                              labelText: 'City *',
                              labelStyle: const TextStyle(
                                fontSize: 16,
                                fontFamily: 'Poppins',
                                color: Colors.grey,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey, width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Color(0xFFCB6CE6), width: 2.0),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter city';
                              }
                              return null;
                            },
                          ),
                        ),

                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          child: TextFormField(
                            controller: _postalCodeController,
                            style: const TextStyle(
                              fontSize: 18,
                              fontFamily: 'Poppins',
                            ),
                            decoration: InputDecoration(
                              labelText: 'Postal Code *',
                              labelStyle: const TextStyle(
                                fontSize: 16,
                                fontFamily: 'Poppins',
                                color: Colors.grey,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey, width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Color(0xFFCB6CE6), width: 2.0),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter postal code';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          // --- ADD THE HORIZONTAL DIVIDER  ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 55.0),
            child: Divider(
              height: 0,
              thickness: 3,
              color: const Color(0xFFB2B2B2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //   children: [
                //     const Text(
                //       'Subtotal',
                //       style: TextStyle(
                //         fontSize: 22,
                //         fontWeight: FontWeight.w600,
                //         fontFamily: 'Poppins',
                //       ),
                //     ),
                //     Text(
                //       '£${widget.subtotal.toStringAsFixed(2)}',
                //       style: const TextStyle(
                //         fontSize: 22,
                //         fontFamily: 'Poppins',
                //       ),
                //     ),
                //   ],
                // ),
                // const SizedBox(height: 8),

                Row( // This Row now contains only the "Next" button
                  children: [
                    Expanded( // The "Next" button will now expand to fill the entire row
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            if (_formKey.currentState!.validate()) {
                              final customerDetails = CustomerDetails(
                                name: _nameController.text.trim(),
                                phoneNumber: _phoneController.text.trim(),
                                email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
                                streetAddress: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
                                city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
                                postalCode: _postalCodeController.text.trim().isEmpty ? null : _postalCodeController.text.trim(),
                              );
                              widget.onCustomerDetailsSubmitted(customerDetails);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 20), // Increased vertical padding here
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Center(
                              child: Text(
                                'Next',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Removed SizedBox(width: 8) and Image.asset('assets/images/men.png')
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}