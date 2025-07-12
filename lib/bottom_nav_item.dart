import 'package:flutter/material.dart';

class BottomNavItem extends StatelessWidget {
  final String image;
  final int index;
  final VoidCallback onTap;
  final String? notification;
  final Color? color;
  final int selectedIndex;

  const BottomNavItem({
    super.key,
    required this.image,
    required this.index,
    required this.onTap,
    required this.selectedIndex,
    this.notification,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    bool isSelected = selectedIndex == index;
    String displayImage = image;


    if (isSelected && image != 'home.png' && !image.contains('white.png')) {
      displayImage = image.replaceAll('.png', 'white.png');
    } else if (!isSelected && image.contains('white.png')) {
      displayImage = image.replaceAll('white.png', '.png');
    }

    if (index == 0) {
      displayImage = isSelected ? 'TakeAwaywhite.png' : 'TakeAway.png';
    } else if (index == 1) {
      displayImage = isSelected ? 'DineInwhite.png' : 'DineIn.png';
    } else if (index == 2) {
      displayImage = isSelected ? 'Deliverywhite.png' : 'Delivery.png';
    } else if (index == 3) {
      displayImage = isSelected ? 'webwhite.png' : 'web.png';
    } else if (index == 4) {
      displayImage = 'home.png';
    } else if (index == 5) {
      displayImage = isSelected ? 'Morewhite.png' : 'More.png';
    }



    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          print("Nav item at index $index tapped.");
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [

              Image.asset(
                'assets/images/$displayImage',
                width: index == 2 ? 92 : 60,
                height: index == 2 ? 92 : 60,
                color: isSelected  ? Colors.white : const Color(0xFF616161),
              ),

              if (notification != null && notification!.isNotEmpty)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: color ?? Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      notification!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}