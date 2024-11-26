import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'suche.dart';
import 'profil.dart';
import 'main.dart';

class Bewertung extends StatefulWidget {
  final String anbieter;

  Bewertung({required this.anbieter});

  @override
  _BewertungState createState() => _BewertungState();
}

class _BewertungState extends State<Bewertung> {
  int _selectedRating = 0;
  TextEditingController _textController = TextEditingController();

  // Diese Funktion holt die Bewertungen eines Nutzers aus der Firestore-Datenbank
  Future<Map<String, dynamic>> _fetchUserRating(DocumentReference userRef) async {
    var ratingSnapshot = await FirebaseFirestore.instance.collection('bewertung').where('bauer', isEqualTo: userRef).get();
    var ratings = ratingSnapshot.docs.map((doc) => doc.data()['bewertung'] as int).toList();
    var ratingSum = ratings.fold(0, (sum, rating) => sum + rating);
    var ratingCount = ratings.length;
    var averageRating = ratingCount > 0 ? ratingSum / ratingCount : 0.0;
    return {'averageRating': averageRating, 'ratingCount': ratingCount};
  }

  // Diese Funktion sendet die Bewertung und den Kommentar des Nutzers an die Firestore-Datenbank
  void _submitReview() async {
  if (_selectedRating == 0) {
    // Fehlerbehandlung oder Nachricht anzeigen, dass eine Bewertung ausgewählt werden muss
    return;
  }

  String kommentar = _textController.text.trim();
  if (kommentar.isEmpty) {
    // Fehlerbehandlung oder Nachricht anzeigen, dass der Kommentar nicht leer sein darf
    return;
  }

  // Holt die aktuelle Nutzerreferenz aus der Sitzungsklasse (UserSession)
  DocumentReference? konsumentRef = UserSession.instance.userDocRef;

  // Holt die Anbieterreferenz basierend auf dem Namen des Anbieters
  var userSnapshot = await FirebaseFirestore.instance.collection('users')
      .where('name', isEqualTo: widget.anbieter).get();
  if (userSnapshot.docs.isEmpty) {
    // Fehlerbehandlung, wenn Anbieter nicht gefunden wurde
    return;
  }
  DocumentReference bauerRef = userSnapshot.docs[0].reference;

  // Überprüft, ob bereits eine Bewertung von diesem Nutzer für diesen Anbieter existiert
  var existingReviewSnapshot = await FirebaseFirestore.instance.collection('bewertung')
      .where('konsument', isEqualTo: konsumentRef)
      .where('bauer', isEqualTo: bauerRef)
      .get();
  if (existingReviewSnapshot.docs.isNotEmpty) {
    // Zeigt eine Fehlermeldung an, dass nur eine Bewertung pro Anbieter erlaubt ist
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sie können nur eine Bewertung pro Anbieter abgeben.'),
        duration: Duration(seconds: 2),
      ),
    );
    return;
  }

  try {
    // Erstellt ein neues Dokument in der Sammlung 'bewertung'
    await FirebaseFirestore.instance.collection('bewertung').add({
      'bewertung': _selectedRating,
      'kommentar': kommentar,
      'bauer': bauerRef,
      'konsument': konsumentRef,
      'timestamp': Timestamp.now(),
    });

    // Löscht das Textfeld nach erfolgreicher Übermittlung
    _textController.clear();

    // Zeigt eine Erfolgsmeldung an
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Kommentar erfolgreich gespeichert.'),
        duration: Duration(seconds: 2), // Optionale Dauer
      ),
    );

    // Erzwingt einen Neuladen des Widgets, um Änderungen anzuzeigen (optional)
    setState(() {
      // UI-Aktualisierung auslösen, um die neue Bewertung anzuzeigen
    });
  } catch (e) {
    // Zeigt eine Fehlermeldung an
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fehler beim Speichern des Kommentars: $e'),
        duration: Duration(seconds: 2), // Optionale Dauer
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bewertungen'), 
        backgroundColor: const Color.fromRGBO(185, 228, 182, 1),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.0), // Höhe des Strichs
          child: Container(
            color: Colors.black, // Farbe des Strichs
            height: 1.0, // Höhe des Strichs
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').where('name', isEqualTo: widget.anbieter).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            var users = snapshot.data!.docs;
            if (users.isEmpty) {
              return Center(child: Text('Kein Nutzer mit dem Namen ${widget.anbieter} gefunden'));
            }
            var user = users[0].data() as Map<String, dynamic>;
            var userRef = users[0].reference;
            var name = user['name'] ?? 'Unbekannter Benutzer';
            var profileImageUrl = user['bild'];
            var street = user['street'] ?? '';
            var zip = user['zip'] ?? '';
            var city = user['city'] ?? '';
            
            return FutureBuilder<Map<String, dynamic>>(
              future: _fetchUserRating(userRef),
              builder: (context, ratingSnapshot) {
                if (ratingSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (ratingSnapshot.hasError) {
                  return Center(child: Text('Error: ${ratingSnapshot.error}'));
                }

                var ratingData = ratingSnapshot.data!;
                var averageRating = ratingData['averageRating'] as double;

                return ListView(
                  children: [
                    ListTile(
                      title: Text(name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (street.isNotEmpty) Text(street),
                          if (zip.isNotEmpty || city.isNotEmpty) Text('$zip $city'),
                          Row(
                            children: [
                              _buildReviewStars(averageRating),
                              SizedBox(width: 8),
                              Text('${averageRating.toStringAsFixed(1)} / 5.0'),
                            ],
                          ),
                        ],
                      ),
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(profileImageUrl),
                        radius: 50,
                      ),
                    ),
                    Divider(
                      color: Colors.black,
                      thickness: 2.0,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _textController,
                        decoration: InputDecoration(
                          hintText: 'Schreibe einen Kommentar...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    _buildRatingInput(),
                    Divider(
                      color: Colors.black,
                      thickness: 2.0,
                    ),
                    _buildUserReviews(userRef),
                  ],
                );
              },
            );
          },
        ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
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

  // Diese Funktion baut die Sterne für die Bewertung auf
  Widget _buildRatingStars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedRating = index + 1;
              });
            },
            child: Icon(
              index < _selectedRating ? Icons.star : Icons.star_border,
              color: index < _selectedRating ? Colors.yellow : Colors.black,
              size: 36.0, // Größere Größe für die Sterne
            ),
          ),
        );
      }),
    );
  }

  // Diese Funktion baut das Eingabefeld für die Bewertung auf
  Widget _buildRatingInput() {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Row(
        children: [
          Expanded(
            child: StarRating(
              selectedRating: _selectedRating,
              onRatingChanged: (rating) {
                setState(() {
                  _selectedRating = rating;
                });
              },
            ),
          ),
          ElevatedButton(
            onPressed: _submitReview,
            child: Text('Absenden'),
          ),
        ],
      ),
    );
  }

  // Diese Funktion holt die Bewertungen eines Nutzers und zeigt sie an
  Widget _buildUserReviews(DocumentReference userRef) {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('bewertung').where('bauer', isEqualTo: userRef).snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(child: Text('Error: ${snapshot.error}'));
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator());
      }

      var reviews = snapshot.data!.docs;

      return ListView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: reviews.length,
        itemBuilder: (context, index) {
          var review = reviews[index].data() as Map<String, dynamic>;
          var konsumentRef = review['konsument'] as DocumentReference;
          var kommentar = review['kommentar'] ?? '';
          var bewertung = review['bewertung']?.toDouble() ?? 0.0;

          return FutureBuilder<DocumentSnapshot>(
            future: konsumentRef.get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (userSnapshot.hasError) {
                return Center(child: Text('Error: ${userSnapshot.error}'));
              }

              var userData = userSnapshot.data!.data() as Map<String, dynamic>;
              var userName = userData['name'] ?? 'Unbekannter Benutzer';            

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: Colors.grey, width: 1.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: Text(userName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [                          
                          Text(kommentar),
                          _buildReviewStars(bewertung),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
}

  // Diese Funktion baut die Sterne für die Bewertungen auf
  Widget _buildReviewStars(double rating) {
    return Row(
      children: [
        for (int i = 0; i < rating.floor(); i++)
          Icon(Icons.star, color: Colors.yellow),
        if (rating % 1 != 0)
          Icon(Icons.star_half, color: Colors.yellow),
        for (int i = 0; i < (5 - rating.ceil()); i++)
          Icon(Icons.star_border, color: Colors.black),
      ],
    );
  }
}


class StarRating extends StatefulWidget {
  final int selectedRating;
  final ValueChanged<int> onRatingChanged;

  StarRating({required this.selectedRating, required this.onRatingChanged});

  @override
  _StarRatingState createState() => _StarRatingState();
}

class _StarRatingState extends State<StarRating> {
  late int _currentRating;
  TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentRating = widget.selectedRating;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: InkWell(
            onTap: () {
              setState(() {
                _currentRating = index + 1;
                widget.onRatingChanged(_currentRating); // Aktualisiert die ausgewählte Bewertung des Elternwidgets
              });
            },
            child: Icon(
              index < _currentRating ? Icons.star : Icons.star_border,
              color: index < _currentRating ? Colors.yellow : Colors.black,
              size: 36.0,
            ),
          ),
        );
      }),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
