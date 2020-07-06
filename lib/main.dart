// import 'package:flutter/material.dart';
// import 'package:rxdart/subjects.dart';

// void main() {
//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter Render',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//         visualDensity: VisualDensity.adaptivePlatformDensity,
//       ),
//       home: MyHomePage(title: 'Flutter Render'),
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   MyHomePage({Key key, this.title}) : super(key: key);

//   final String title;

//   @override
//   _MyHomePageState createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   BehaviorSubject<int> selectIndexController = BehaviorSubject();

//   @override
//   void initState() {
//     super.initState();
//     selectIndexController = BehaviorSubject.seeded(0);
//   }

//   @override
//   void dispose() {
//     selectIndexController.close();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Color.fromARGB(255, 51, 51, 51),
//       body: Row(
//         children: <Widget>[
//           StreamBuilder(
//               stream: selectIndexController.stream,
//               builder: (context, snapshot) {
//                 return NavigationRail(
//                     backgroundColor: Color.fromARGB(255, 51, 51, 51),
//                     onDestinationSelected: (value) =>
//                         selectIndexController.add(value),
//                     destinations: <NavigationRailDestination>[
//                       NavigationRailDestination(
//                         icon: Icon(Icons.folder, color: Colors.grey),
//                         selectedIcon: Icon(
//                           Icons.folder,
//                           color: Colors.white,
//                         ),
//                         label: Text(''),
//                       ),
//                       NavigationRailDestination(
//                         icon: Icon(Icons.hot_tub, color: Colors.grey),
//                         selectedIcon: Icon(
//                           Icons.hot_tub,
//                           color: Colors.white,
//                         ),
//                         label: Text(''),
//                       ),
//                       NavigationRailDestination(
//                         icon: Icon(Icons.search, color: Colors.grey),
//                         selectedIcon: Icon(
//                           Icons.search,
//                           color: Colors.white,
//                         ),
//                         label: Text(''),
//                       ),
//                       NavigationRailDestination(
//                         icon: Icon(Icons.play_arrow, color: Colors.grey),
//                         selectedIcon: Icon(
//                           Icons.play_arrow,
//                           color: Colors.white,
//                         ),
//                         label: Text(''),
//                       ),
//                       NavigationRailDestination(
//                         icon: Icon(Icons.extension, color: Colors.grey),
//                         selectedIcon: Icon(
//                           Icons.extension,
//                           color: Colors.white,
//                         ),
//                         label: Text(''),
//                       ),
//                     ],
//                     selectedIndex: snapshot.data ?? 0);
//               }),
//         ],
//       ),
//     );
//   }
// }
