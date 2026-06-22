import 'package:flutter/material.dart';

class OutfitCard extends StatelessWidget {

  final String title;
  final String image;
  final String price;
  final String brand;
  final VoidCallback onTap;

  const OutfitCard({

    super.key,

    required this.title,

    required this.image,

    required this.price,

    required this.brand,

    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {

    return GestureDetector(

      onTap: onTap,

      child: Card(

        elevation: 6,

        shape:
        RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(20),
        ),

        child: Column(

          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [

            /// IMAGE
            Expanded(

              child: Stack(

                children: [

                  ClipRRect(

                    borderRadius:
                    const BorderRadius.vertical(
                      top:
                      Radius.circular(20),
                    ),

                    child: Image.network(

                      image,

                      fit: BoxFit.cover,

                      width:
                      double.infinity,
                    ),
                  ),

                  /// PRICE BADGE
                  Positioned(

                    top: 10,

                    right: 10,

                    child: Container(

                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),

                      decoration:
                      BoxDecoration(

                        color:
                        Colors.pink,

                        borderRadius:
                        BorderRadius.circular(
                          20,
                        ),
                      ),

                      child: Text(

                        price,

                        style:
                        const TextStyle(
                          color:
                          Colors.white,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            /// DETAILS
            Padding(

              padding:
              const EdgeInsets.all(12),

              child: Column(

                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [

                  Text(

                    title,

                    style:
                    const TextStyle(

                      fontSize: 16,

                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(

                    brand,

                    style:
                    TextStyle(
                      color:
                      Colors.grey.shade700,
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// BUTTON
                  SizedBox(

                    width: double.infinity,

                    child: ElevatedButton(

                      onPressed: onTap,

                      style:
                      ElevatedButton.styleFrom(

                        backgroundColor:
                        Colors.pink,

                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(
                            15,
                          ),
                        ),
                      ),

                      child: const Text(

                        "Explore",

                        style: TextStyle(
                          color:
                          Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}