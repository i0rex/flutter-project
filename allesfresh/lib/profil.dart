import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';
import 'suche.dart';
import 'produkt.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class Profil extends StatefulWidget {
  @override
  _ProfilState createState() => _ProfilState();
}

class _ProfilState extends State<Profil> {
  // Zukünftige Variable zur Speicherung der Benutzerdaten
  late Future<DocumentSnapshot> _userFuture;
  // Zukünftige Variable zur Speicherung der Bewertungen
  late Future<List<Map<String, dynamic>>> _reviewsFuture;
  // Controller für die Textfelder
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _zipController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  // Variable zur Speicherung des ausgewählten Bildes
  File? _imageFile;
  // ImagePicker-Instanz zum Auswählen von Bildern
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _userFuture = _fetchUser(); // Benutzerinformationen abrufen
    _reviewsFuture = _fetchReviews(); // Bewertungen abrufen

    // Benutzerdaten in die Textfelder einfügen, wenn sie verfügbar sind
    _userFuture.then((userSnapshot) {
      final userData = userSnapshot.data() as Map<String, dynamic>;
      _streetController.text = userData['street'] ?? '';
      _zipController.text = userData['zip'] ?? '';
      _cityController.text = userData['city'] ?? '';
    });
  }

  // Funktion zum Abrufen der Benutzerdaten
  Future<DocumentSnapshot> _fetchUser() async {
    final DocumentReference? userDocRef = UserSession().userDocRef;

    if (userDocRef != null) {
      return await userDocRef.get();
    } else {
      throw Exception('User not found');
    }
  }

  // Funktion zum Abrufen der Bewertungen
  Future<List<Map<String, dynamic>>> _fetchReviews() async {
    final DocumentReference? userDocRef = UserSession().userDocRef;

    if (userDocRef != null) {
      final userSnapshot = await userDocRef.get();
      final userType = userSnapshot['typ'] ?? 'konsument';

      Query reviewsQuery = FirebaseFirestore.instance.collection('bewertung');

      if (userType == 'bauer') {
        reviewsQuery = reviewsQuery.where('bauer', isEqualTo: userDocRef);
      } else {
        reviewsQuery = reviewsQuery.where('konsument', isEqualTo: userDocRef);
      }

      final reviewsSnapshot = await reviewsQuery.get();

      List<Map<String, dynamic>> reviews = [];

      for (var reviewDoc in reviewsSnapshot.docs) {
        final reviewData = reviewDoc.data() as Map<String, dynamic>?;
        if (reviewData != null) {
          final bauerRef = reviewData['bauer'] as DocumentReference?;
          if (bauerRef != null) {
            final bauerSnapshot = await bauerRef.get();
            final bauerData = bauerSnapshot.data() as Map<String, dynamic>?;
            final bauerName = bauerData?['name'] ?? 'Unbekannter Anbieter';

            reviews.add({
              'bewertung': reviewData['bewertung'] ?? 0,
              'kommentar': reviewData['kommentar'] ?? '',
              'bauerName': bauerName,
              'bauer': bauerRef, // Hinzufügen der bauer-Referenz
            });
          }
        }
      }

      return reviews;
    } else {
      throw Exception('User not found');
    }
  }

  // Funktion zum Speichern der Adresse
  Future<void> _saveAddress() async {
    final DocumentReference? userDocRef = UserSession().userDocRef;

    if (userDocRef != null) {
      await userDocRef.update({
        'street': _streetController.text,
        'zip': _zipController.text,
        'city': _cityController.text,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adresse gespeichert')),
      );
    }
  }

  // Funktion zum Löschen des Profils
  Future<void> _deleteProfile() async {
    final DocumentReference? userDocRef = UserSession().userDocRef;

    if (userDocRef != null) {
      final userSnapshot = await userDocRef.get();
      final userType = userSnapshot['typ'] ?? 'konsument';

      if (userType == 'konsument') {
        // Bewertungen löschen, wo konsument der aktuelle Nutzer ist
        final ratingsSnapshot = await FirebaseFirestore.instance
            .collection('bewertung')
            .where('konsument', isEqualTo: userDocRef)
            .get();

        for (var doc in ratingsSnapshot.docs) {
          await doc.reference.delete();
        }
      } else if (userType == 'bauer') {
        // Produkte löschen, wo user der aktuelle Nutzer ist
        final productsSnapshot = await FirebaseFirestore.instance
            .collection('produkte')
            .where('user', isEqualTo: userDocRef)
            .get();

        for (var doc in productsSnapshot.docs) {
          await doc.reference.delete();
        }

        // Bewertungen löschen, wo bauer der aktuelle Nutzer ist
        final ratingsSnapshot = await FirebaseFirestore.instance
            .collection('bewertung')
            .where('bauer', isEqualTo: userDocRef)
            .get();

        for (var doc in ratingsSnapshot.docs) {
          await doc.reference.delete();
        }
      }

      // Benutzer aus der users Sammlung löschen
      await userDocRef.delete();

      // Benutzer aus Firebase Authentication löschen
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        await firebaseUser.delete();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil gelöscht')),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => MyApp()),
        (Route<dynamic> route) => false,
      );
    }
  }

  // Funktion zum Löschen einer Bewertung
  Future<void> _deleteReview(DocumentReference bauerRef) async {
    final DocumentReference? userDocRef = UserSession().userDocRef;

    if (userDocRef != null) {
      final reviewSnapshot = await FirebaseFirestore.instance
          .collection('bewertung')
          .where('konsument', isEqualTo: userDocRef)
          .where('bauer', isEqualTo: bauerRef)
          .get();

      for (var doc in reviewSnapshot.docs) {
        await doc.reference.delete();
      }

      setState(() {
        _reviewsFuture = _fetchReviews();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bewertung gelöscht')),
      );
    }
  }

  // Funktion zum Abrufen eines Bildes aus der Galerie
  Future<void> _getImageFromGallery() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _imageFile = File(pickedFile.path);
      } else {
        print('No image selected.');
      }
    });

    if (_imageFile != null) {
      _uploadProfileImage();
    }
  }

  // Funktion zum Hochladen des Profilbildes
  Future<void> _uploadProfileImage() async {
    try {
      FirebaseStorage storage = FirebaseStorage.instance;
      Reference ref = storage.ref().child('profile_pictures/${FirebaseAuth.instance.currentUser!.uid}');

      UploadTask uploadTask = ref.putFile(_imageFile!);
      await uploadTask.whenComplete(() => null);

      String imageUrl = await ref.getDownloadURL();

      final DocumentReference? userDocRef = UserSession().userDocRef;
      if (userDocRef != null) {
        await userDocRef.update({
          'bild': imageUrl,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profilbild aktualisiert')),
        );

        // Seite neu laden
        setState(() {
          _userFuture = _fetchUser();
        });
      }
    } catch (e) {
      print('Error uploading profile image: $e');
    }
  }

  // Dialog zum Bearbeiten des Profilbildes anzeigen
  void _showEditProfileImageDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Profilbild bearbeiten'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Bild ändern'),
                onTap: _getImageFromGallery,
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Bild löschen'),
                onTap: () async {
                  final DocumentReference? userDocRef = UserSession().userDocRef;
                  if (userDocRef != null) {
                    await userDocRef.update({
                      'bild': FieldValue.delete(),
                    });
                  }
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Abbrechen'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Dialog zum Bestätigen des Profil-Löschens anzeigen
  void _confirmDeleteProfile() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Profil löschen'),
          content: const Text('Sind Sie sicher, dass Sie Ihr Profil löschen möchten?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Abbrechen'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Löschen'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteProfile();
              },
            ),
          ],
        );
      },
    );
  }

  // Funktion zum Erstellen von Bewertung in Sternen
Widget _buildRatingStars(int rating) {
  List<Widget> stars = [];
  for (int i = 1; i <= 5; i++) {
    stars.add(Icon(
      i <= rating ? Icons.star : Icons.star_border,
      color: Colors.yellow,
    ));
  }
  return Row(children: stars);
}

  // Benutzeroberfläche bauen
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'), // Titel der AppBar
        backgroundColor: const Color.fromRGBO(185, 228, 182, 1),
        actions: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _confirmDeleteProfile,
                tooltip: 'Profil löschen',
              ),
              const Text(
                'Profil löschen',
                style: TextStyle(color: Colors.black, fontSize: 12),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.black,
            height: 1.0,
          ),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _userFuture,
        builder: (context, snapshot) {
          // Vorhandene Snapshot-Verarbeitungscode
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('User not found'));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final userName = userData['name'] ?? 'Nicht verfügbar';
          final userImageURL = userData['bild'] ?? '';
          final userType = userData['typ'] ?? 'konsument';

          _streetController.text = userData['street'] ?? '';
          _zipController.text = userData['zip'] ?? '';
          _cityController.text = userData['city'] ?? '';

          return SingleChildScrollView(
            child: Column(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _showEditProfileImageDialog,
                          child: CircleAvatar(
                            radius: 50,
                            backgroundImage: userImageURL.isNotEmpty
                                ? NetworkImage(userImageURL)
                                : null,
                            child: userImageURL.isEmpty
                                ? const Icon(Icons.person, size: 50)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '$userName',
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(height: 20),
                        if (userType == 'bauer') ...[
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => Produkt()),
                              );
                            },
                            child: const Text('Meine Produkte'),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Adresse',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          TextField(
                            controller: _streetController,
                            decoration: const InputDecoration(
                              labelText: 'Straße',
                            ),
                          ),
                          TextField(
                            controller: _zipController,
                            decoration: const InputDecoration(
                              labelText: 'PLZ',
                            ),
                          ),
                          TextField(
                            controller: _cityController,
                            decoration: const InputDecoration(
                              labelText: 'Ort',
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _saveAddress,
                            child: const Text('Adresse speichern'),
                          ),
                        ] else ...[
                          const SizedBox(height: 5),
                        ],
                      ],
                    ),
                  ),
                ),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _reviewsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('Keine Kommentare gefunden'));
                    }

                    final comments = snapshot.data!;

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: ListTile(
                            title: _buildRatingStars(comment['bewertung']), // Hier die Bewertung in Sternen darstellen
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Kommentar: ${comment['kommentar']}'),
                                Text('Anbieter: ${comment['bauerName']}'),
                              ],
                            ),
                            trailing: userType != 'bauer'
                                ? IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () async {
                                      final bauerRef = comment['bauer'] as DocumentReference;
                                      await _deleteReview(bauerRef);
                                    },
                                  )
                                : null,
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
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
}
