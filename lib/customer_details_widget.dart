import 'package:flutter/material.dart';
import 'package:epos/models/order_models.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

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

  bool _validateUKPhoneNumber(String phoneNumber) {
    try {
      // Remove all spaces and non-digit characters except +
      String cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

      // Parse the phone number for UK region
      PhoneNumber parsedNumber = PhoneNumber.parse(cleanedNumber, destinationCountry: IsoCode.GB);

      // Check if it's a valid UK number
      return parsedNumber.isValid() && parsedNumber.countryCode == '44';
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
                      style: TextStyle(
                        fontSize: 25,
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
                              icon: const Icon(
                                Icons.search,
                                color: Colors.white,
                                size: 28,
                              ),
                              onPressed: () {
                                // TODO: Implementation later - search functionality
                              },
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

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 42.0),
          child: Divider(thickness: 2, color: Colors.grey),
        ),

        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Subtotal',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    '£${widget.subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: MouseRegion( // Wrap the GestureDetector with MouseRegion
                      cursor: SystemMouseCursors.click, // Set cursor to hand pointer
                      child: GestureDetector(
                        onTap: () {
                          if (_formKey.currentState!.validate()) {
                            // If all validations pass, proceed with submission
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              'Next',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  MouseRegion( // Wrap the Image.asset with MouseRegion
                    cursor: SystemMouseCursors.click, // Set cursor to hand pointer
                    child: GestureDetector( // Add GestureDetector if you want the image to be tappable
                      onTap: () {
                        // You can add the same validation and submission logic here,
                        // or any other action you want when the men.png image is tapped.
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
                      child: Image.asset('assets/images/men.png', width: 40, height: 40),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }
}