// ignore_for_file: library_private_types_in_public_api

import 'package:counter/file_handling.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}
Future<void> addUser(String userId, String name) async {
  await FirebaseFirestore.instance.collection('Players').doc(userId).set({
    'name': name,
    'createdAt': FieldValue.serverTimestamp(),
  });
  debugPrint("User added!");
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
    addUser('userid', 'username');
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
    resetData(true, false, false);
    setState(() {
      // Use setState to update players after data is loaded and sorted
      players = Map.fromEntries(
        rawPlayers.entries.toList()
          ..sort((a, b) => (b.value["history"]?.length ?? 0).compareTo(a.value["history"]?.length ?? 0))
      );
    });
  }

  void alterPlayers(String label, List value){
    setState(() {
    players[label]!['history'] = value;
      players = Map.fromEntries(
        players.entries.toList()
          ..sort((a, b) => (b.value["history"].length ?? 0).compareTo(a.value["history"].length ?? 0))
      );
    });
    writeData(players, append: false);
  }
  void editPlayer(String oldKey, Map newTile){
    Map<String, dynamic> updatedPlayers = {};
    
    players.forEach((key, value) {
      if (key == oldKey) {
        // Replace the old key with the new key and update the value
        updatedPlayers[newTile['label']] = {
          'history': newTile['history'],
          'color': newTile['color']
        };
      } else {
        // Keep the original entries
        updatedPlayers[key] = value;
      }
    });
    setState(() {
        players = updatedPlayers;
    });
    writeData(players, append: false);
  }
  void addRecord(String label, DateTime dateTime){
    players[label]['history'] ??= [];
    players[label]['history'].add(DateFormat('yyyy-MM-dd HH:mm').format(dateTime));
    writeData(players, append: false);
  }
  void removeRecord(String player, int index){
    setState(() {
      // players[player]['history']?.removeAt(index);
      players = Map.fromEntries(
        players.entries.toList()
          ..sort((a, b) => (b.value["history"].length ?? 0).compareTo(a.value["history"].length ?? 0))
      );
    });
    writeData(players, append: false);
  }
  void removeTile(String key){
    setState(() {
      players.remove(key);
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
                    initialScore: players[key]["history"]?.length ?? 0,
                    color: players[key]["color"],
                    incriment: alterPlayers,
                    edit: editPlayer,
                    addRecord: addRecord, 
                    history: players[key]['history'] ?? [], 
                    removeRecord: removeRecord,
                    removeTile: removeTile,
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
                    players[label] = {'history': [], 'color': [255, color.red, color.green, color.blue]};
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
  final Function incriment;
  final Function edit;
  final Function addRecord;
  final Function removeRecord;
  final List history;
  final Function removeTile;

  const ScoreCounter({
    super.key,
    required this.label,
    required this.initialScore,
    required this.color, 
    required this.incriment, 
    required this.edit,
    required this.addRecord, 
    required this.history, 
    required this.removeRecord,
    required this.removeTile,
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

  void increment({DateTime? dateTime}) {
    // setState(() {
    //   score++;
    // });
    widget.addRecord(widget.label, dateTime ?? DateTime.now());
    widget.incriment(widget.label, widget.history);
  }

  // void decrement() {
  //   // setState(() {
  //   //   if (score > 0) score--;
  //   // });
  //   widget.incriment(widget.label, score);
  // }

  @override
  Widget build(BuildContext context) {
    score = widget.initialScore;
    return GestureDetector(
      onLongPress: () async{
        String? option = await showModalBottomSheet(
          context: context,
          builder: (context) {
            return OptionsPopup();
          },
        );
        if (option == 'Edit Tile') {
          Map? tile = await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AddPopup(initialLabel: widget.label, initialColor: Color.fromARGB(widget.color[0], widget.color[1], widget.color[2], widget.color[3]));
            }
          );
          if (tile != null){
            String label = tile["label"];
            Color color = tile['color'];
            Map newTile = {'label': label, 'history': widget.history, 'color': [255, color.red, color.green, color.blue]};
            widget.edit(widget.label, newTile);
          }     
        } else if (option == 'View history'){
          showDialog(
            context: context,
            builder: (context) {
              return HistoryPopup(player: widget.history, playerName: widget.label, removeItem: widget.removeRecord, );
            },
          );
        } else if (option == 'Delete Tile'){
          widget.removeTile(widget.label);
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
                    // IconButton(
                    //   icon: Icon(Icons.remove, color: Color.fromARGB(widget.color[0], widget.color[1], widget.color[2], widget.color[3]), size: 40,),
                    //   onPressed: decrement,
                    // ),
                    GestureDetector(
                      onLongPress: () async {
                        final result = await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return const DateTimePickerDialog();
                          },
                        );
                        if (result != null){
                            final combinedDateTime = DateTime(
                              result['date'].year,
                              result['date'].month,
                              result['date'].day,
                              result['time'].hour,
                              result['time'].minute,
                            );

                          increment(dateTime: combinedDateTime);
                        }
                      },
                      child: IconButton(
                        icon: Icon(Icons.add, color: Color.fromARGB(widget.color[0], widget.color[1], widget.color[2], widget.color[3]), size: 40,),
                        onPressed: increment,
                      ),
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
  void initState() {
    super.initState();
    if (widget.initialLabel != null) {
      label = widget.initialLabel!;
    }
    if (widget.initialColor != null){
      tempColor = widget.initialColor!;
    }
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Tile'),
      content: Row(
        children: [
          SizedBox(
            width: 150,
            child: TextFormField(
              initialValue: label,
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
                          pickerColor: tempColor,
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

class OptionsPopup extends StatefulWidget {
  const OptionsPopup({super.key});

  @override
  _OptionsPopupState createState() => _OptionsPopupState();
}

class _OptionsPopupState extends State<OptionsPopup> {

  void selectOption(String name) {
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            boxThing('Edit Tile'),
            boxThing('Delete Tile'),
            boxThing('View history'),
          ]
        ),
      ),
    );
  }

  Widget boxThing(String name) {
    return GestureDetector(
      onTap: () {
        selectOption(name); // Trigger selectTime with the corresponding days
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
        child: Container(
          decoration: BoxDecoration(
            // color: HexColor.fromHexColor('262626'),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 20
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HistoryPopup extends StatefulWidget {
  final List player;
  final String playerName;
  final Function removeItem;
  const HistoryPopup({
    super.key, required this.player, required this.playerName, required this.removeItem,
  });
  @override

  _HistoryPopupState createState() => _HistoryPopupState();
}

class _HistoryPopupState extends State<HistoryPopup> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'History for ${widget.playerName}',
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min, // Ensures the dialog fits its content
          children: [
            const Divider(),
            SizedBox(
              height: 400, // Set a specific height for the ListView
              child: ListView.builder(
                itemCount: widget.player.length,
                itemBuilder: (context, index) {
                  index = (widget.player.length-1) - index;
                  return ListTile(
                    title: Text(
                      widget.player[index],
                      style: const TextStyle(
                        fontSize: 18,
                      ),
                    ),
                    trailing: GestureDetector(
                      onTap: () {
                        setState(() {
                          widget.player.removeAt(index);
                        });
                        widget.removeItem(widget.playerName, index);
                      },
                      child: const Icon(
                        Icons.close,
                        size: 30,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

  }
}


class DateTimePickerDialog extends StatefulWidget {
  final DateTime? initialDate;
  final TimeOfDay? initialTime;


  const DateTimePickerDialog({
    this.initialDate,
    this.initialTime,
  });

  @override
  _DateTimePickerDialogState createState() => _DateTimePickerDialogState();
}

class _DateTimePickerDialogState extends State<DateTimePickerDialog> {
  DateTime? date;
  TimeOfDay? time;

  @override
  void initState() {
    super.initState();
    date = widget.initialDate ?? DateTime.now();
    time = widget.initialTime ?? TimeOfDay.now();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Date and Time'),
      content: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                final selectedDate = await showDatePicker(
                  context: context,
                  initialDate: date ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2101),
                );
                if (selectedDate != null) {
                  setState(() {
                    date = selectedDate;
                  });
                }
              },
              child: Text(
                date != null
                    ? '${date!.year}-${date!.month}-${date!.day}'
                    : 'Select Date',
              ),
            ),
          ),
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                final selectedTime = await showTimePicker(
                  context: context,
                  initialTime: time ?? TimeOfDay.now(),
                );
                if (selectedTime != null) {
                  setState(() {
                    time = selectedTime;
                  });
                }
              },
              child: Text(
                time != null
                    ? time!.format(context)
                    : 'Select Time',
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            // Perform your desired action with fromDate, fromTime, toDate, and toTime
            Navigator.of(context).pop({
              'date': date,
              'time': time,
            });
          },
          child: Text('OK'),
        ),
      ],
    );
  }
}