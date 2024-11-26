import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'suche.dart';
import 'elearning.dart';

// Hauptfunktion der Anwendung, die Firebase initialisiert und die App startet
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

// Haupt-Widget der Anwendung
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Firebase Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AuthenticationScreen(),
    );
  }
}

// Singleton-Klasse für Benutzersitzung
class UserSession {
  static final UserSession _instance = UserSession._internal();

  DocumentReference? userDocRef;

  factory UserSession() {
    return _instance;
  }

  UserSession._internal();

  static UserSession get instance => _instance;
}

// Widget für die Authentifizierungsseite
class AuthenticationScreen extends StatefulWidget {
  @override
  _AuthenticationScreenState createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _registerEmailController = TextEditingController();
  final TextEditingController _registerUsernameController = TextEditingController();
  final TextEditingController _registerPasswordController = TextEditingController();
  bool _isRegistering = false;
  String _role = 'Konsument'; 

  // Funktion zur Anmeldung mit E-Mail und Passwort
  // Funktion zur Anmeldung mit E-Mail und Passwort
void _login() async {
  String email = _emailController.text;
  String password = _passwordController.text;

  if (email.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bitte E-Mail-Adresse eingeben.'),
      ),
    );
    return;
  }

  if (password.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bitte Passwort eingeben.'),
      ),
    );
    return;
  }

  try {
    UserCredential userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Speichern der Dokumentenreferenz des Benutzers
    UserSession().userDocRef = FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid);

    // Navigation zur Suche-Seite
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Suche()),
    );
  } catch (error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Anmeldung fehlgeschlagen: $error'),
      ),
    );
  }
}

// Funktion zur Registrierung eines neuen Benutzers
void _register() async {
  String email = _registerEmailController.text;
  String password = _registerPasswordController.text;
  String username = _registerUsernameController.text;

  try {
    // Überprüfen, ob die E-Mail-Adresse bereits in Firestore vorhanden ist
    var userQuery = await FirebaseFirestore.instance.collection('users')
      .where('mail', isEqualTo: email)
      .get();

    if (userQuery.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Die E-Mail-Adresse ist bereits registriert.'),
        ),
      );
      return;
    }

    // Überprüfen, ob der Benutzername bereits in Firestore vorhanden ist
    var usernameQuery = await FirebaseFirestore.instance.collection('users')
      .where('name', isEqualTo: username)
      .get();

    if (usernameQuery.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Der Benutzername ist bereits vergeben.'),
        ),
      );
      return;
    }

    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Benutzerinformationen in Firestore speichern
    await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
      'mail': email,
      'name': username,
      'typ': _role,
    });

    // Snackbar anzeigen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Eine Bestätigungsmail wurde versendet.'),
        action: SnackBarAction(
          label: 'Login',
          onPressed: () async {
            // Benutzer einloggen
            UserCredential loggedInUser = await _auth.signInWithEmailAndPassword(
              email: email,
              password: password,
            );

            // Speichern der Dokumentenreferenz des Benutzers
            UserSession().userDocRef = FirebaseFirestore.instance.collection('users').doc(loggedInUser.user!.uid);

            // Navigation zur Suche-Seite
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => Suche()),
            );
          },
        ),
      ),
    );

    // Buttons anzeigen
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Registrierung abgeschlossen'),
          content: const Text('Eine Bestätigungsmail wurde versendet.'),
          actions: [
            TextButton(
              onPressed: () {
                // Bestätigungsmail erneut senden
                userCredential.user!.sendEmailVerification();
                Navigator.of(context).pop();
              },
              child: const Text('Bestätigungsmail erneut senden'),
            ),
            TextButton(
              onPressed: () async {
                // Benutzer einloggen
                UserCredential loggedInUser = await _auth.signInWithEmailAndPassword(
                  email: email,
                  password: password,
                );

                // Speichern der Dokumentenreferenz des Benutzers
                UserSession().userDocRef = FirebaseFirestore.instance.collection('users').doc(loggedInUser.user!.uid);

                // Navigation zur Suche-Seite
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Suche()),
                );
              },
              child: const Text('Login'),
            ),
          ],
        );
      },
    );
  } catch (error) {
    if (error is FirebaseAuthException && error.code == 'email-already-in-use') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Die E-Mail-Adresse ist bereits registriert.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registrierung fehlgeschlagen: $error'),
        ),
      );
    }
  }
}

  // Funktion zur Anmeldung mit Google-Konto
  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        return; // Anmeldung abgebrochen
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);

      // Benutzerinformationen in Firestore speichern, falls neu
      if (userCredential.additionalUserInfo!.isNewUser) {
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'mail': userCredential.user!.email,
          'name': userCredential.user!.displayName,
        });
      }

      // Speichern der Dokumentenreferenz des Benutzers
      UserSession().userDocRef = FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid);

      // Navigation zur Suche-Seite
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => Suche()),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google Anmeldung fehlgeschlagen: $error'),
        ),
      );
    }
  }

  // Funktion zur Anmeldung mit Facebook-Konto
  Future<void> _signInWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.success) {
        final AuthCredential credential = FacebookAuthProvider.credential('accessToken');

        UserCredential userCredential = await _auth.signInWithCredential(credential);

        // Benutzerinformationen in Firestore speichern, falls neu
        if (userCredential.additionalUserInfo!.isNewUser) {
          await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
            'mail': userCredential.user!.email,
            'name': userCredential.user!.displayName,
          });
        }

        // Speichern der Dokumentenreferenz des Benutzers
        UserSession().userDocRef = FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid);

        // Navigation zur Suche-Seite
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => Suche()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Facebook Anmeldung fehlgeschlagen: ${result.message}'),
          ),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Facebook Anmeldung fehlgeschlagen: $error'),
        ),
      );
    }
  }

  // Funktion zum Umschalten zwischen Registrierung und Login
  void _toggleRegistering() {
    setState(() {
      _isRegistering = !_isRegistering;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/Hintergrund.PNG'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SingleChildScrollView(
            child: Center(
              child: Column(
                children: [
                  const SizedBox(height: 60), // Abstand für das Logo
                  Image.asset('assets/LogoAllesFresh.PNG', width: 200.0), // Logo außerhalb des Containers
                  const SizedBox(height: 60),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      elevation: 8.0,
                      color: Colors.white, // Weißer Hintergrund für den Container
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        side: const BorderSide(
                          color: Colors.black, // Schwarze Umrandung
                          width: 2.0, // Dickere Umrandung
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            TextField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'E-Mail-Adresse',
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _passwordController,
                              decoration: const InputDecoration(
                                labelText: 'Passwort',
                              ),
                              obscureText: true,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _login,
                              child: const Text('Login'),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed: _signInWithGoogle,
                              icon: Image.asset('assets/google.PNG', width: 24.0),
                              label: const Text('Mit Google anmelden'),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed: _signInWithFacebook,
                              icon: Image.asset('assets/facebook.PNG', width: 24.0),
                              label: const Text('Mit Facebook anmelden'),
                            ),
                            const Divider(),
                            ElevatedButton(
                              onPressed: _toggleRegistering,
                              child: const Text('Registrieren'),
                            ),
                            if (_isRegistering) ...[
                              TextField(
                                controller: _registerEmailController,
                                decoration: const InputDecoration(
                                  labelText: 'E-Mail-Adresse',
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _registerUsernameController,
                                decoration: const InputDecoration(
                                  labelText: 'Benutzername',
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _registerPasswordController,
                                decoration: const InputDecoration(
                                  labelText: 'Passwort',
                                ),
                                obscureText: true,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Radio<String>(
                                    value: 'bauer',
                                    groupValue: _role,
                                    onChanged: (String? value) {
                                      setState(() {
                                        _role = value!;
                                      });
                                    },
                                  ),
                                  const Text('Händler'),
                                  Radio<String>(
                                    value: 'konsument',
                                    groupValue: _role,
                                    onChanged: (String? value) {
                                      setState(() {
                                        _role = value!;
                                      });
                                    },
                                  ),
                                  const Text('Konsument'),
                                ],
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: _register,
                                child: const Text('Registrieren bestätigen'),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed: _toggleRegistering,
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Abbrechen'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ELearning()),
            );
          },
          child: const Text('Zum E-Learning'),
        ),
      ),
    );
  }

}
