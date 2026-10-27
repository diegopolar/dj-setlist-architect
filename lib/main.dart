import 'package:flutter/material.dart';
import 'screens/config_screen.dart';
import 'screens/library_screen.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'DJ Setlist Architect',
      debugShowCheckedModeBanner: false,
      // Tema oscuro de alto contraste para cabina.
      theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: Colors.black,
          colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00E5FF), secondary: Color(0xFFFF2D95), surface: Color(0xFF111111))),
      home: const Home());
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _i = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(child: IndexedStack(index: _i, children: const [ConfigScreen(), LibraryScreen()])),
      bottomNavigationBar: NavigationBar(selectedIndex: _i, onDestinationSelected: (v) => setState(() => _i = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.tune), label: 'Sesión'),
            NavigationDestination(icon: Icon(Icons.library_music), label: 'Biblioteca')]));
}
