// ignore_for_file: library_private_types_in_public_api

import 'package:counter/file_handling.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const ScoreBoard(),
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.blue,
          surfaceContainer: Color.fromRGBO(32, 32, 32, 1),      
        )
      )
    );
  }
}
class ScoreBoard extends StatefulWidget {
  const ScoreBoard({super.key});

  @override
  _ScoreBoardState createState() => _ScoreBoardState();
}

class _ScoreBoardState extends State<ScoreBoard> {
  Map players = {};

  @override
  void initState() {
    super.initState();
    _initializePlayers();  // Call the async method here without awaiting it
  }

  Future<void> _initializePlayers() async {
    Map rawPlayers = await readData();  // Fetch data asynchronously
    // Map<String, Map<String, dynamic>> rawPlayers = {
    //   "Me": {"score": 2, "color": [255, 128, 0, 128]}, // Purple
    //   "Dylan": {"score": 6, "color": [255, 255, 0, 0]}, // Red
    //   "Owen": {"score": 6, "color": [255, 255, 192, 203]}, // Pink
    //   "Hayden": {"score": 5, "color": [255, 255, 165, 0]}, // Orange
    //   "Mitch": {"score": 5, "color": [255, 0, 128, 0]}, // Green
    //   "Cooper": {"score": 4, "color": [200, 0, 0, 255]}, // Blue
    // };
    setState(() {
      // Use setState to update players after data is loaded and sorted
      players = Map.fromEntries(
        rawPlayers.entries.toList()
          ..sort((a, b) => b.value["score"].compareTo(a.value["score"]))
      );
    });
  }

  void alterPlayers(String label, int value){
    setState(() {
      players[label]!['score'] = value;
      players = Map.fromEntries(
        players.entries.toList()
          ..sort((a, b) => b.value["score"].compareTo(a.value["score"]))
      );
    });
    writeData(players, append: false);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,      // 2 columns
                  crossAxisSpacing: 16,   // spacing between columns
                  mainAxisSpacing: 16,    // spacing between rows
                  childAspectRatio: 1.18,  // ratio to make the widgets fit nicely
                ),
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final key = players.keys.toList()[index];
                  return ScoreCounter(
                    label: key,
                    initialScore: players[key]["score"],
                    color: players[key]["color"],
                    function: alterPlayers,
                  );
                },
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: GestureDetector(
              onTap: () async {
                debugPrint('ball');
                Map? tile = await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return const AddPopup();
                  }
                );
                if (tile != null){
                  String label = tile["label"];
                  Color color = tile['color'];
                  setState(() {
                    players[label] = {'score': 0, 'color': [color.alpha, color.red, color.green, color.blue]};
                  });
                  writeData(players, append: false);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: AddButton(),
              ),
            ),
          ),
        ],
      ),

    );
  }

  // ignore: non_constant_identifier_names
  Container AddButton() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Colors.purple, Colors.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: const Icon(
        Icons.add,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}



class ScoreCounter extends StatefulWidget {
  final String label;
  final int initialScore;
  final List color;
  final Function function;

  const ScoreCounter({
    super.key,
    required this.label,
    required this.initialScore,
    required this.color, 
    required this.function,
  });

  @override
  _ScoreCounterState createState() => _ScoreCounterState();
}

class _ScoreCounterState extends State<ScoreCounter> {
  late int score;

  @override
  void initState() {
    super.initState();
  }

  void increment() {
    setState(() {
      score++;
    });
    widget.function(widget.label, score);
  }

  void decrement() {
    setState(() {
      if (score > 0) score--;
    });
    widget.function(widget.label, score);
  }

  @override
  Widget build(BuildContext context) {
    score = widget.initialScore;
    return GestureDetector(
      onLongPress: () async{
        Map? tile = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AddPopup(initialLabel: widget.label, initialColor: Color.fromARGB(widget.color[0], widget.color[1], widget.color[2], widget.color[3]));
          }
        );
        if (tile != null){
          String label = tile["label"];
          Color color = tile['color'];
          // setState(() {
          //   players[label] = {'score': 0, 'color': [color.alpha, color.red, color.green, color.blue]};
          // });
          // writeData(players, append: false);
        }      
      },
      child: Column(
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Color.fromARGB(widget.color[0], widget.color[1], widget.color[2], widget.color[3]).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color.fromARGB(widget.color[0], widget.color[1], widget.color[2], widget.color[3]), width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 5),
                Text(
                  '$score',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove, color: Color.fromARGB(widget.color[0], widget.color[1], widget.color[2], widget.color[3]), size: 40,),
                      onPressed: decrement,
                    ),
                    IconButton(
                      icon: Icon(Icons.add, color: Color.fromARGB(widget.color[0], widget.color[1], widget.color[2], widget.color[3]), size: 40,),
                      onPressed: increment,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AddPopup extends StatefulWidget {
  final String? initialLabel;
  final Color? initialColor;
  const AddPopup({
    super.key, this.initialLabel, this.initialColor
  });
  @override

  _AddPopupState createState() => _AddPopupState();
}

class _AddPopupState extends State<AddPopup> {
  Color tempColor = Colors.white;
  String label = '';
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Tile'),
      content: Row(
        children: [
          SizedBox(
            width: 150,
            child: TextFormField(
              initialValue: widget.initialLabel ?? '',
              onChanged:(value) => label = value,
            ),
          ),
          const SizedBox(
            width: 7.5,
          ),
          GestureDetector(
            onTap: () async{
              Color? color = await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Pick a color'),
                      content: SingleChildScrollView(
                        child: ColorPicker(
                          pickerColor: widget.initialColor ?? tempColor,
                          paletteType: PaletteType.hueWheel, // This is the key fix
                          enableAlpha: false,
                          onColorChanged: (color) {
                            setState(() => tempColor = color);
                          },
                        ),
                      ),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('Cancel'),
                          onPressed: () {
                            Navigator.of(context).pop(); // Close without saving
                          },
                        ),
                        TextButton(
                          child: const Text('Reset'),
                          onPressed: () {
                            Navigator.of(context).pop(); // Close without saving
                          },
                        ),
                        TextButton(
                          child: const Text('Select'),
                          onPressed: () {
                            Navigator.of(context).pop(tempColor); // Return selected color
                          },
                        ),
                      ],
                    );
                  },
                );

                if (color != null) {
                  setState(() {
                    tempColor = color;
                  });
                }
            },
            child: Padding(
              padding: EdgeInsets.only(left: 20),
              child: Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: tempColor,
                  borderRadius: BorderRadius.circular(100)
                ),
              ),
            ),
          )
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Close the dialog
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop({'label': label, 'color': tempColor}); // Perform action and close the dialog
            debugPrint("Alert Confirmed!");
          },
          child: const Text(
            'OK',
            style: TextStyle(
              fontSize: 20,
            ),
          ),
        ),
      ],
    );
  }
}