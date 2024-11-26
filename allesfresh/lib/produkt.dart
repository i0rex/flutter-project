import 'dart:io'; // Import für Dateioperationen

import 'package:flutter/material.dart'; // Import für UI-Komponenten
import 'package:cloud_firestore/cloud_firestore.dart'; // Import für Firestore-Datenbank
import 'package:firebase_storage/firebase_storage.dart'; // Import für Firebase Storage
import 'package:image_picker/image_picker.dart'; // Import für Bildauswahl
import 'main.dart'; // Import der Hauptdatei

class Produkt extends StatefulWidget {
  @override
  _ProduktState createState() => _ProduktState();
}

class _ProduktState extends State<Produkt> {
  late Future<DocumentSnapshot> _userFuture;

  // Controller für die Eingabefelder
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _productDescriptionController = TextEditingController();
  final TextEditingController _productPriceController = TextEditingController();
  final TextEditingController _tagController = TextEditingController(); // Controller für das Tag-Eingabefeld

  File? _imageFile; // Dateiobjekt für das ausgewählte Bild
  final ImagePicker _picker = ImagePicker();
  List<String> _tags = []; // Liste der hinzugefügten Tags

  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _userFuture = _fetchUser(); // Benutzerinformationen laden
  }

  // Funktion zum Abrufen der Benutzerinformationen
  Future<DocumentSnapshot> _fetchUser() async {
    final DocumentReference? userDocRef = UserSession().userDocRef;

    if (userDocRef != null) {
      return await userDocRef.get();
    } else {
      throw Exception('User not found');
    }
  }

  // Funktion zum Hinzufügen eines neuen Produkts
  Future<void> _addProduct() async {
    final DocumentReference? userDocRef = UserSession().userDocRef;

    if (userDocRef != null) {
      String? imageUrl;

      if (_imageFile != null) {
        // Bild hochladen und URL erhalten
        imageUrl = await _uploadImageToFirebase(_imageFile!);
      }

      await FirebaseFirestore.instance.collection('produkte').add({
        'name': _productNameController.text,
        'beschreibung': _productDescriptionController.text,
        'preis': _productPriceController.text,
        'user': userDocRef, // Referenz zum Benutzer hinzufügen
        'bild': imageUrl, // Bild-URL speichern, falls vorhanden
        'tags': _tags, // Tags speichern
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produkt hinzugefügt')),
      );
    }
  }

  // Funktion zum Hochladen eines Bildes auf Firebase
  Future<String> _uploadImageToFirebase(File imageFile) async {
    try {
      // Zugriff auf Firebase Storage
      FirebaseStorage storage = FirebaseStorage.instance;

      // Bildreferenz erstellen
      Reference ref = storage.ref().child('produkt_bilder/${DateTime.now().millisecondsSinceEpoch}');

      // Bild hochladen
      UploadTask uploadTask = ref.putFile(imageFile);

      // Warten, bis der Upload abgeschlossen ist
      await uploadTask.whenComplete(() => null);

      // Bild-URL abrufen
      String imageUrl = await ref.getDownloadURL();

      return imageUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return '';
    }
  }

  // Funktion zum Auswählen eines Bildes aus der Galerie
  void _getImageFromGallery() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _imageFile = File(pickedFile.path);
      } else {
        print('No image selected.');
      }
    });
  }

  // Funktion zum Hinzufügen eines Tags
  void _addTag() {
    setState(() {
      if (_tagController.text.isNotEmpty) {
        if (_tags.length < 5) {
          _tags.add(_tagController.text);
          _tagController.clear();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Maximal 5 Tags sind erlaubt')),
          );
        }
      }
    });
  }

  // Funktion zum Entfernen eines Tags
  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  // Funktion zum Bearbeiten eines Produkts
  void _editProduct(DocumentSnapshot product) {
    setState(() {
      _productNameController.text = product['name'];
      _productDescriptionController.text = product['beschreibung'];
      _productPriceController.text = product['preis'];
      _tags = List<String>.from(product['tags'] ?? []);
      _imageFile = null;
    });
    _showEditProductDialog(product);
  }

  // Funktion zum Aktualisieren eines Produkts
  Future<void> _updateProduct(DocumentSnapshot product) async {
    final DocumentReference? userDocRef = UserSession().userDocRef;

    if (userDocRef != null) {
      String? imageUrl = product['bild'];

      if (_imageFile != null) {
        // Bild hochladen und URL erhalten
        imageUrl = await _uploadImageToFirebase(_imageFile!);
      }

      await product.reference.update({
        'name': _productNameController.text,
        'beschreibung': _productDescriptionController.text,
        'preis': _productPriceController.text,
        'tags': _tags, // Tags speichern
        'bild': imageUrl, // Bild-URL aktualisieren, falls vorhanden
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produkt aktualisiert')),
      );
    }
  }

  // Funktion zum Anzeigen des Dialogs zur Bearbeitung eines Produkts
  void _showEditProductDialog(DocumentSnapshot product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Produkt bearbeiten'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _productNameController,
                  decoration: const InputDecoration(
                    labelText: 'Produktname',
                  ),
                ),
                TextField(
                  controller: _productDescriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Beschreibung',
                  ),
                ),
                TextField(
                  controller: _productPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Preis',
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tagController,
                        decoration: const InputDecoration(
                          labelText: 'Tags',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _addTag,
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8.0,
                  children: _tags.map((tag) => GestureDetector(
                    onTap: () => _removeTag(tag), // Entfernen des Tags beim Anklicken
                    child: Chip(
                      label: Text('#$tag'),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _getImageFromGallery,
                  child: const Text('Bild auswählen'),
                ),
                _imageFile != null
                    ? Image.file(
                        _imageFile!,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      )
                    : product['bild'] != null
                        ? Image.network(
                            product['bild'],
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          )
                        : const SizedBox.shrink(),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Abbrechen'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Speichern'),
              onPressed: () {
                _updateProduct(product);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Produkte'), 
        backgroundColor: const Color.fromRGBO(185, 228, 182, 1),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.0), // Höhe des Strichs
          child: Container(
            color: Colors.black, // Farbe des Strichs
            height: 1.0, // Höhe des Strichs
          ),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('User not found'));
          }

          final userDocRef = snapshot.data!.reference;

          return SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExpansionPanelList(
                  elevation: 1,
                  expandedHeaderPadding: EdgeInsets.zero,
                  expansionCallback: (int index, bool isExpanded) {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  children: [
                    ExpansionPanel(
                      headerBuilder: (BuildContext context, bool isExpanded) {
                        return const ListTile(
                          title: Text(
                            'Produkt hinzufügen',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                      body: Column(
                        children: [
                          TextField(
                            controller: _productNameController,
                            decoration: const InputDecoration(
                              labelText: 'Produktname',
                            ),
                          ),
                          TextField(
                            controller: _productDescriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Beschreibung',
                            ),
                          ),
                          TextField(
                            controller: _productPriceController,
                            decoration: const InputDecoration(
                              labelText: 'Preis',
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _tagController,
                                  decoration: const InputDecoration(
                                    labelText: 'Tags',
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: _addTag,
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 8.0,
                            children: _tags.map((tag) => Chip(
                              label: Text('#$tag'),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            )).toList(),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _getImageFromGallery,
                            child: const Text('Bild auswählen'),
                          ),
                          _imageFile != null
                              ? Image.file(
                                  _imageFile!,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                )
                              : const SizedBox.shrink(),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _addProduct,
                            child: const Text('Produkt hinzufügen'),
                          ),
                        ],
                      ),
                      isExpanded: _isExpanded,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Meine Produkte verwalten',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Container(
                  height: 400, // Festgelegte Höhe für den Container
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('produkte')
                        .where('user', isEqualTo: userDocRef)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('Keine Produkte gefunden'));
                      }

                      return ListView.builder(
                        // Entfernen des shrinkWrap Attributs
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final product = snapshot.data!.docs[index];
                          var tags = List<String>.from(product['tags'] ?? []);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                            child: InkWell(                         
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black, width: 2.0),
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product['name'] ?? '',
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          if (product['bild'] != null) ...[
                                            Expanded(
                                              flex: 1,
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(8.0),
                                                child: Image.network(
                                                  product['bild'],
                                                  height: 120,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          Expanded(
                                            flex: 1,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (product['beschreibung'] != null) ...[
                                                  Text('${product['beschreibung']}'),
                                                ],
                                                Text(
                                                  'Preis: ${product['preis'] ?? 0}',
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
                                        const SizedBox(height: 8),
                                      ],
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit),
                                            onPressed: () => _editProduct(product),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (BuildContext context) {
                                                  return AlertDialog(
                                                    title: const Text('Produkt löschen'),
                                                    content: const Text('Möchten Sie dieses Produkt wirklich löschen?'),
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
                                                          product.reference.delete();
                                                          Navigator.of(context).pop();
                                                        },
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
