import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Learning',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ELearning(),
    );
  }
}

class ELearning extends StatefulWidget {
  @override
  _ELearningState createState() => _ELearningState();
}

// Singleton-Klasse für Benutzersitzung
class UserSession {
  static final UserSession _instance = UserSession._internal();

  DocumentReference? userDocRef;
  List<dynamic> wiederholtArray = [];

  factory UserSession() {
    return _instance;
  }

  UserSession._internal();

  static UserSession get instance => _instance;
}


class _ELearningState extends State<ELearning> {
  String? _selectedUser;
  List<String> _userNames = [];
  List<DocumentSnapshot> _exercises = [];
  bool _isAddingExercise = false;
  TextEditingController _durationController = TextEditingController();
  TextEditingController _mediumController = TextEditingController();
  TextEditingController _niveauController = TextEditingController();
  TextEditingController _themaController = TextEditingController();


  @override
  void initState() {
    super.initState();
    _fetchUserNames();
    _fetchRecommendedExercises();
  }

  Future<void> _fetchUserNames() async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection('Profil').get();
    List<String> userNames = querySnapshot.docs.map((doc) => doc['name'] as String).toList();
    setState(() {
      _userNames = userNames;
    });
  }

  Future<void> _fetchRecommendedExercises() async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection('Übungen').get();
    setState(() {
      _exercises = querySnapshot.docs;
    });
  }

  void _loginAsUser(String userName) async {
    // Fetch the user document reference
    DocumentReference userDocRef = FirebaseFirestore.instance.collection('Profil').doc(userName);
    DocumentSnapshot userDoc = await userDocRef.get();

    if (userDoc.exists) {
      List<dynamic> wiederholtArray = userDoc['wiederholt'];
    
      // Update state with user document reference and "wiederholt" array
      setState(() {
        UserSession().userDocRef = userDocRef;
        UserSession().wiederholtArray = wiederholtArray;
      });
    
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Angemeldet als $userName')),
      );
    } else {
      setState(() {
        UserSession().userDocRef = null;
        UserSession().wiederholtArray = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Benutzerprofil nicht gefunden')),
      );
    }
  }

    // Methode zum Hinzufügen einer neuen Übung
  void _addExercise() {
    setState(() {
      _isAddingExercise = true;
    });
  }

  // Methode zum Speichern der neuen Übung
  Future<void> _saveExercise() async {
    int newId = _exercises.length + 1; // Aufsteigende ID für neue Übung

    Map<String, dynamic> newExercise = {
      'ID': newId,
      'Dauer': int.parse(_durationController.text),
      'Medium': _mediumController.text,
      'Niveau': _niveauController.text,
      'Thema': _themaController.text,
    };

    DocumentReference newDocRef = await FirebaseFirestore.instance.collection('Übungen').add(newExercise);

    // Abrufen des Dokuments nach dem Hinzufügen, um die Liste zu aktualisieren
    DocumentSnapshot newDocSnapshot = await newDocRef.get();

    setState(() {
      _exercises.insert(0, newDocSnapshot);
      _isAddingExercise = false;
      _durationController.clear();
      _mediumController.clear();
      _niveauController.clear();
      _themaController.clear();
    });
  }


  Widget _buildExerciseCard(DocumentSnapshot exercise) {
    int exerciseId = exercise['ID'];
  
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: BorderSide(
            color: Colors.black,
            width: 1.0,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ID: $exerciseId | '),
              Text('Lvl: ${exercise['Niveau']} | '), 
              Text('${exercise['Medium']} | '),      
              Text('${exercise['Dauer']}s | '),
              Text('Thema: ${exercise['Thema']}'),
            ],
          ),
        ),
      ),
    );
  }





  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('E-Learning'),
        actions: [
          DropdownButton<String>(
            hint: Text('Anmelden'),
            value: _selectedUser,
            items: _userNames.map((String userName) {
              return DropdownMenuItem<String>(
                value: userName,
                child: Text(userName),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedUser = newValue;
              });
              if (newValue != null) {
                _loginAsUser(newValue);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Text('Willkommen beim E-Learning!', style: TextStyle(fontSize: 24.0))),
              SizedBox(height: 24.0),
              Text('Empfohlene Übungen', style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold)),
              SizedBox(height: 16.0),
              Column(
                children: _exercises.map((exercise) => _buildExerciseCard(exercise)).toList(),
              ),
              if (_isAddingExercise) ...[
                TextField(
                  controller: _durationController,
                  decoration: InputDecoration(labelText: 'Dauer (s)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: _mediumController,
                  decoration: InputDecoration(labelText: 'Medium'),
                ),
                TextField(
                  controller: _niveauController,
                  decoration: InputDecoration(labelText: 'Niveau'),
                ),
                TextField(
                  controller: _themaController,
                  decoration: InputDecoration(labelText: 'Thema'),
                ),
                SizedBox(height: 10.0),
                ElevatedButton(
                  onPressed: _saveExercise,
                  child: Text('Speichern'),
                ),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addExercise,
        child: Icon(Icons.add),
        tooltip: 'Übung hinzufügen',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

