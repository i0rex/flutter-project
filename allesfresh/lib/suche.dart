import 'package:allesfresh/main.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'bewertung.dart'; // Import der bewertung.dart Datei
import 'profil.dart';
import 'package:geocoding/geocoding.dart';

class Suche extends StatefulWidget {
  @override
  _SucheState createState() => _SucheState();
}

class _SucheState extends State<Suche> {
  String? selectedTag;
  String? sortOption;
  final List<String> sortOptions = ['Rating abst.', 'Rating aufst.', 'alphabetisch', 'Entfernung'];
  List<String> tags = [];
  Position? currentPosition;
  final geo = GeoFlutterFire();
  bool sortAscending = true;
  double? searchRadius; // State für den Suchradius

  @override
  void initState() {
    super.initState();
    _fetchTags();
    _getCurrentLocation();
    sortOption = sortOptions[0];
  }

  // Funktion zum Abrufen der Tags aus der Firestore-Datenbank
  Future<void> _fetchTags() async {
    var productSnapshot = await FirebaseFirestore.instance.collection('produkte').get();
    var tagList = productSnapshot.docs
        .map((doc) => (doc.data()['tags'] as List<dynamic>).cast<String>())
        .expand((tags) => tags)
        .toSet()
        .toList();
    setState(() {
      tags = tagList;
    });
  }

  // Funktion zum Abrufen der aktuellen Position des Benutzers
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }

    // Aktuelle Position abrufen
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    setState(() {
      currentPosition = position;
    });

    // Update Firestore with the current location
    var userDocRef = UserSession().userDocRef;
    if (userDocRef != null) {
      GeoFirePoint myLocation = geo.point(latitude: currentPosition!.latitude, longitude: currentPosition!.longitude);
      await userDocRef.update({'position': myLocation.data});
    }
  }

  // Funktion zum Abrufen der Produkte nach Tag und Sortieroption
  Future<List<QueryDocumentSnapshot<Object?>>> _fetchProductsByTag(String? tag, String? sortOption) async {
    Query query = FirebaseFirestore.instance.collection('produkte');

    if (tag != null) {
      query = query.where('tags', arrayContains: tag);
    }

    var productSnapshot = await query.get();
    var products = productSnapshot.docs;

    if (sortOption == 'Rating aufst.') {
      products.sort((a, b) => (a.data() as Map<String, dynamic>)['bewertung'].compareTo((b.data() as Map<String, dynamic>)['bewertung']));
    } else if (sortOption == 'Rating abst.') {
      products.sort((a, b) => (b.data() as Map<String, dynamic>)['bewertung'].compareTo((a.data() as Map<String, dynamic>)['bewertung']));
    } else if (sortOption == 'Alphabetisch') {
      products.sort((a, b) => (a.data() as Map<String, dynamic>)['name'].compareTo((b.data() as Map<String, dynamic>)['name']));
    } else if (sortOption == 'Entfernung' && currentPosition != null) {
      List<Map<String, dynamic>> productsWithDistance = [];

      for (var product in products) {
        var data = product.data() as Map<String, dynamic>;
        var userRef = data['user'] as DocumentReference;
        var userSnapshot = await userRef.get();
        var userData = userSnapshot.data() as Map<String, dynamic>;
        var userGeoPoint = userData['geopoint'] as GeoPoint?;

        if (userGeoPoint != null) {
          double distance = _calculateDistance(
            currentPosition!.latitude,
            currentPosition!.longitude,
            userGeoPoint.latitude,
            userGeoPoint.longitude,
          );
          if (searchRadius == null || distance <= searchRadius!) {
            productsWithDistance.add({
              'product': product,
              'distance': distance,
            });
          }
        }
      }

      productsWithDistance.sort((a, b) => a['distance'].compareTo(b['distance']));
      products = productsWithDistance.map((p) => p['product'] as QueryDocumentSnapshot<Object?>).toList();
    }

    return products;
  }

  // Dialog zum Eingeben des Suchradius
  void _showSearchRadiusDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        TextEditingController radiusController = TextEditingController();
        return AlertDialog(
          title: const Text('Suchradius eingeben'),
          content: TextField(
            controller: radiusController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Radius in km'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Abbrechen'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                setState(() {
                  searchRadius = double.tryParse(radiusController.text);
                  _fetchProductsByTag(selectedTag, sortOption);
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Funktion zum Abrufen der Produkte nach Sortieroption
  Future<List<DocumentSnapshot>> _fetchProductsSorted(String? sortOption) async {
    Query query = FirebaseFirestore.instance.collection('produkte');
    
    if (sortOption == 'Rating aufst.') {
      query = query.orderBy('bewertung', descending: false);
    } else if (sortOption == 'Rating abst.') {
      query = query.orderBy('bewertung', descending: true);
    } else if (sortOption == 'Alphabetisch') {
      query = query.orderBy('name', descending: false);
    }
    
    var productSnapshot = await query.get();
    return productSnapshot.docs;
  }

  // Funktion zum Abrufen der Benutzerbewertung
  Future<Map<String, dynamic>> _fetchUserRating(DocumentReference userRef) async {
    var ratingSnapshot = await FirebaseFirestore.instance.collection('bewertung').where('bauer', isEqualTo: userRef).get();
    var ratings = ratingSnapshot.docs.map((doc) => doc.data()['bewertung'] as int).toList();
    var ratingSum = ratings.fold(0, (sum, rating) => sum + rating);
    var ratingCount = ratings.length;
    var averageRating = ratingCount > 0 ? ratingSum / ratingCount : 0.0;
    return {'averageRating': averageRating, 'ratingCount': ratingCount};
  }

  // Funktion zum Abrufen aller Produkte
  Future<List<DocumentSnapshot>> _fetchAllProducts() async {
    var productSnapshot = await FirebaseFirestore.instance.collection('produkte').get();
    return productSnapshot.docs;
  }

  // Funktion zur Umwandlung von Koordinaten in eine Adresse
  Future<String> _getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        return "${place.locality}, ${place.country}";
      }
    } catch (e) {
      print(e);
    }
    return "Ort nicht gefunden";
  }

  // Funktion zur Berechnung der Entfernung zwischen zwei Punkten
  double _calculateDistance(double startLatitude, double startLongitude, double endLatitude, double endLongitude) {
    return Geolocator.distanceBetween(startLatitude, startLongitude, endLatitude, endLongitude) / 1000; // Entfernung in Kilometern
  }

  @override
  Widget build(BuildContext context) {
    DocumentReference? userDocRef = UserSession().userDocRef;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suche'),
        backgroundColor: const Color.fromRGBO(185, 228, 182, 1),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchRadiusDialog,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_alt),
            onSelected: (value) {
              setState(() {
                selectedTag = value == 'Alle anzeigen' ? null : value;
                _fetchProductsByTag(selectedTag, sortOption);
              });
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'Alle anzeigen',
                  child: Text('Alle anzeigen'),
                ),
                ...tags.map((String tag) {
                  return PopupMenuItem<String>(
                    value: tag,
                    child: Text(tag),
                  );
                })
              ];
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                sortOption = value;
                _fetchProductsByTag(selectedTag, sortOption);
              });
            },
            itemBuilder: (BuildContext context) {
              return sortOptions.map((String option) {
                return PopupMenuItem<String>(
                  value: option,
                  child: Text(option),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Column(
          children: [
            userDocRef != null
                ? FutureBuilder<DocumentSnapshot>(
                      future: userDocRef.get(),
                      builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }
                        if (snapshot.hasError) {
                          return const Text("Fehler beim Laden der Benutzerdaten");
                        }
                        if (snapshot.hasData && !snapshot.data!.exists) {
                          return const Text("Benutzerdokument nicht gefunden");
                        }
                        if (snapshot.hasData) {
                          var data = snapshot.data!.data() as Map<String, dynamic>;
                          var userName = data['name'] ?? "Kein Name verfügbar";
                          String addressText = 'Ort wird geladen...';

                          if (currentPosition != null) {
                            return FutureBuilder<String>(
                              future: _getAddressFromCoordinates(currentPosition!.latitude, currentPosition!.longitude),
                              builder: (context, AsyncSnapshot<String> addressSnapshot) {
                                if (addressSnapshot.connectionState == ConnectionState.waiting) {
                                  addressText = 'Ort wird geladen...';
                                } else if (addressSnapshot.hasError) {
                                  addressText = 'Fehler beim Laden des Ortes';
                                } else if (addressSnapshot.hasData) {
                                  addressText = addressSnapshot.data!;
                                } else {
                                  addressText = 'Ort nicht gefunden';
                                }

                                return Column(
                                  children: [
                                    Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min, // Minimale Größe, damit der Inhalt zentriert wird
                                        children: [
                                          const Icon(Icons.person), // Icon.person hinzufügen
                                          const SizedBox(width: 8), // Abstand zwischen Icon und Text
                                          Text(userName),
                                          const SizedBox(width: 20),
                                          const Icon(Icons.home), // Icon.person hinzufügen
                                          const SizedBox(width: 8),
                                          Text(addressText),
                                        ],
                                      ),
                                    ),                                   
                                  ],
                                );
                              },
                            );
                          } else {
                            return Column(
                                  children: [
                                    Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min, // Minimale Größe, damit der Inhalt zentriert wird
                                        children: [
                                          const Icon(Icons.person), // Icon.person hinzufügen
                                          const SizedBox(width: 8), // Abstand zwischen Icon und Text
                                          Text(userName),
                                          const SizedBox(width: 20),
                                          const Icon(Icons.home), // Icon.person hinzufügen
                                          const SizedBox(width: 8),
                                          const Text('Ort nicht verfügbar'),
                                        ],
                                      ),
                                    ),                                   
                                  ],
                                );
                          }
                        }
                        return const Text('Keine Daten gefunden');
                      },
                    )
                : const Text('Nicht angemeldet'),
            Expanded(
              child: FutureBuilder<List<DocumentSnapshot>>(
                future: _fetchProductsByTag(selectedTag, sortOption),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || snapshot.data == null) {
                    return Center(child: Text('Error: ${snapshot.error ?? "Snapshot data is null"}'));
                  }

                  var products = snapshot.data!;
                  return ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      var data = products[index].data() as Map<String, dynamic>;
                      var userRef = data['user'] as DocumentReference;

                      return FutureBuilder<Map<String, dynamic>>(
                        future: _fetchUserRating(userRef),
                        builder: (context, ratingSnapshot) {
                          if (ratingSnapshot.connectionState == ConnectionState.waiting) {
                            return _buildListTile(data, const CircularProgressIndicator());
                          }
                          if (ratingSnapshot.hasError) {
                            return _buildListTile(data, const Text('Fehler beim Laden der Bewertungen'));
                          }

                          var ratingData = ratingSnapshot.data!;
                          var averageRating = ratingData['averageRating'] ?? 0.0;
                          var ratingCount = ratingData['ratingCount'] ?? 0;

                          return FutureBuilder<DocumentSnapshot>(
                            future: userRef.get(),
                            builder: (context, userSnapshot) {
                              if (userSnapshot.connectionState == ConnectionState.waiting) {
                                return _buildListTile(data, const CircularProgressIndicator());
                              }
                              if (userSnapshot.hasError) {
                                return _buildListTile(data, const Text('Fehler beim Laden des Benutzer-Namens'));
                              }

                              var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                              var userName = userData['name'] ?? 'Unbekannter Benutzer';
                              var userGeoPoint = userData['geopoint'] as GeoPoint?;
                              double distance = 0.0;

                              if (currentPosition != null && userGeoPoint != null) {
                                distance = _calculateDistance(
                                  currentPosition!.latitude,
                                  currentPosition!.longitude,
                                  userGeoPoint.latitude,
                                  userGeoPoint.longitude,
                                );
                              }

                              return _buildListTile(data, const SizedBox.shrink(), userName, averageRating, ratingCount, distance);
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.black, width: 1.0), // Schwarzer Strich am oberen Ende
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: const Color.fromRGBO(185, 228, 182, 1), // Gleiche Farbe wie die AppBar
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Suche',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profil',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.logout),
              label: 'Logout',
            ),
          ],
          onTap: (index) {
            switch (index) {
              case 0:
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Suche()),
                );
                break;
              case 1:
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Profil()),
                );
                break;
              case 2:
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => MyApp()),
                  (Route<dynamic> route) => false, // Entfernt alle vorherigen Routen
                );
                break;
            }
          },
        ),
      ),
    );
  }

  // Hilfsfunktion zum Erstellen einer ListTile für ein Produkt
  Widget _buildListTile(Map<String, dynamic> data, Widget content, [String userName = '', double userRating = 0.0, int ratingCount = 0, double? distance]) {
    var tags = List<String>.from(data['tags'] ?? []);

    return Padding(
      padding: const EdgeInsets.all(8.0), // Abstand zum Bildschirmrand und zum nächsten Tile
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Bewertung(anbieter: userName),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 2.0), // Schwarze Umrandung
            borderRadius: BorderRadius.circular(12.0), // Abgerundete Ecken
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0), // Innenabstand im Container
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name'] ?? '',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (data['bild'] != null) ...[
                      Expanded(
                        flex: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0), // Radius für die abgerundeten Ecken
                          child: Image.network(
                            data['bild'],
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (data['beschreibung'] != null) ...[
                            Text('${data['beschreibung']}'),
                          ],
                          Text(
                            'Preis: ${data['preis'] ?? 0}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 4.0,
                    runSpacing: 4.0,
                    children: tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text('#$tag', style: const TextStyle(color: Colors.black)),
                      );
                    }).toList(),
                  ),
                ],
                if (userName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person),
                      const SizedBox(width: 8),
                      Text(userName),
                    ],
                  ),
                  Row(
                    children: [
                      _buildRatingStars(userRating),
                      Text(' (${userRating.toStringAsFixed(1)} / 5.0,  $ratingCount Bewertungen)'),
                    ],
                  ),
                ],
                if (distance != null) ...[
                  const SizedBox(height: 8),
                  Text('Entfernung: ${distance.toStringAsFixed(2)} km'),
                ],
                const SizedBox(height: 8),
                content,
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Hilfsfunktion zum Erstellen von Bewertung-Sternen
  Widget _buildRatingStars(double rating) {
    int fullStars = rating.floor();
    int emptyStars = 5 - fullStars;
    bool hasHalfStar = rating % 1 != 0;

    List<Widget> stars = [];
    for (int i = 0; i < fullStars; i++) {
      stars.add(const Icon(Icons.star, color: Colors.yellow));
    }
    if (hasHalfStar) {
      stars.add(const Icon(Icons.star_half, color: Colors.yellow));
      emptyStars--;
    }
    for (int i = 0; i < emptyStars; i++) {
      stars.add(const Icon(Icons.star_border, color: Colors.yellow));
    }
    return Row(children: stars);
  }
}