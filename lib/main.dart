// ignore_for_file: library_private_types_in_public_api

import 'dart:math';

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

Future<void> addUser(String name, List color, List points) async {
  await FirebaseFirestore.instance.collection('Players').doc(name).set({
    'color': color,
    'points': points,
  });
  debugPrint("User added!");
}

Future<void> updateUser(MapEntry entry, {String? name, List? color, List? points}) async {
  if (name != null){
    deleteUser(entry.key);
    addUser(
      name, 
      color ?? entry.value['color'], 
      points ?? entry.value['points']
    );
  }else{
    await FirebaseFirestore.instance.collection('Players').doc(entry.key).update({
      'color': color ?? entry.value['color'],
      'points': points ?? entry.value['points'],
    });
  }
}

Future<void> deleteUser(String docId) async {
  try{
    await FirebaseFirestore.instance.collection('Players').doc(docId).delete();
    debugPrint("User deleted!");
  }catch(e){
    debugPrint('Deleting user failed: $e');
  }
}

Future<Map<String, Map<String, dynamic>>> getAllEntriesAsMap() async {
  try {
    // Fetch all documents in the 'Players' collection
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection('Players').get();

    // Convert to a Map where the document ID is the key
    Map<String, Map<String, dynamic>> allEntries = {
      for (var doc in querySnapshot.docs) doc.id: doc.data() as Map<String, dynamic>
    };

    debugPrint("Fetched ${allEntries.length} entries.");
    return allEntries;
  } catch (e) {
    debugPrint("Error fetching entries: $e");
    return {};
  }
}

String generateRandomId(int length) {
  const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final Random random = Random();
  return List.generate(length, (index) => chars[random.nextInt(chars.length)]).join();
}

void syncClientWithServer(Map differences, Map clientData, Map serverData){
  for (MapEntry difference in differences.entries){
    if (difference.value[0] == '-'){
      deleteUser(difference.key);
    }
    else if (!serverData.containsKey(difference.key)){
      addUser(difference.key, clientData[difference.key]['color'], clientData[difference.key]['points']);
    }else{
      updateUser(MapEntry(difference.key, clientData[difference.key]));
    }
  }
}
Map mergeClientServer(Map differences, Map clientData, Map serverData){ // ehhhhhhh
  Map data = serverData;
  for (String key in clientData.keys){
    if (!data.containsKey(key)){
      data[key] = clientData[key];
      addUser(key, clientData[key]['color'], clientData[key]['points']);
    }
  }
  return data;
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
    // addUser('Cooper gomd', [0, 0, 0, 1], [DateTime.now()]);
    // updateUser('cauoiud', [0, 0, 0, 0], [DateTime.now()]);
  }

  Future<void> _initializePlayers() async {
    Map rawPlayers = await readData();  // Fetch data asynchronously
    Map cloudData =  await getAllEntriesAsMap();
    Map differences = {};  // [local, cloud]
    const listEquality = ListEquality();

    for (String key in {...cloudData.keys, ...rawPlayers.keys}) {
      if (!rawPlayers.containsKey(key) || !cloudData.containsKey(key)){
        differences[key] = [rawPlayers[key]?['points'].length ?? '-', cloudData[key]?['points'].length ?? '-'];
      }else{
        if (!listEquality.equals(cloudData[key]['points'], rawPlayers[key]['points'])){
          differences[key] = [rawPlayers[key]['points'].length, cloudData[key]['points'].length];
        }
      }
    }
    if (differences.isNotEmpty){
      // sync popup
      String? option = await showDialog(
        // ignore: use_build_context_synchronously
        context: context,
        builder: (context) {
          return SyncPopup(differences: differences);
        },
      );
      if (option != null){
        switch (option){
          case 'Client':          
            // sync clients content with server
            syncClientWithServer(differences, rawPlayers, cloudData);
          case 'Merge': 
            // combine both maps, which one takes priority? id say server

          case 'Server': 
            // sync servers content with the client
            rawPlayers = cloudData;
            writeData(rawPlayers, append: false);
        }
      }
    }
    // resetData(true, false, false);
    setState(() {
      // Use setState to update players after data is loaded and sorted
      players = Map.fromEntries(
        rawPlayers.entries.toList()
          ..sort((a, b) => (b.value["points"]?.length ?? 0).compareTo(a.value["points"]?.length ?? 0))
      );
    });
  }

  void addPoint(String label, List value){
    setState(() {
    players[label]!['points'] = value;
      players = Map.fromEntries(
        players.entries.toList()
          ..sort((a, b) => (b.value["points"]?.length ?? 0).compareTo(a.value["points"]?.length ?? 0))
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
          'points': newTile['points'],
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
    updateUser(MapEntry(oldKey, newTile), name: newTile['label']);
    writeData(players, append: false);
  }
  void addRecord(String label, DateTime dateTime){
    players[label]['points'] ??= [];
    players[label]['points'].add(DateFormat('yyyy-MM-dd HH:mm').format(dateTime));
    updateUser(MapEntry(label, players[label]), points: players[label]['points']);
    writeData(players, append: false);
  }
  void removeRecord(String player, int index){
    setState(() {
      players[player]['points']?.removeAt(index);
      players = Map.fromEntries(
        players.entries.toList()
          ..sort((a, b) => (b.value["points"].length ?? 0).compareTo(a.value["points"].length ?? 0))
      );
    });
    updateUser(MapEntry(player, players[player]), points: players[player]['points']);
    writeData(players, append: false);
  }
  void removeTile(String key){
    setState(() {
      players.remove(key);
    });
    deleteUser(key);
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
                    initialScore: players[key]["points"]?.length ?? 0,
                    color: players[key]["color"],
                    incriment: addPoint,
                    edit: editPlayer,
                    addRecord: addRecord, 
                    history: players[key]['points'] ?? [], 
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
                    players[label] = {'points': [], 'color': [255, color.red, color.green, color.blue]};
                    addUser(label, [255, color.red, color.green, color.blue], []);
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
            return const OptionsPopup();
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
            Map newTile = {'label': label, 'points': widget.history, 'color': [255, color.red, color.green, color.blue]};
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
              padding: const EdgeInsets.only(left: 20),
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
                style: const TextStyle(
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
                          widget.removeItem(widget.playerName, index);
                        });
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
      actionsAlignment: MainAxisAlignment.center,
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
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            // Perform your desired action with fromDate, fromTime, toDate, and toTime
            Navigator.of(context).pop({
              'date': date,
              'time': time,
            });
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}

class SyncPopup extends StatefulWidget {
  final Map differences;
  SyncPopup({super.key, required this.differences});
  @override
  _SyncPopupState createState() => _SyncPopupState();
}

class _SyncPopupState extends State<SyncPopup> {
  TextStyle actionsButtonStyle = const TextStyle(
    fontSize: 20,
  );
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(
            Icons.warning_rounded,
            size: 40,
          ),
          SizedBox(width: 10,),
          Text(
            'Content mismatch',
            style: TextStyle(
              fontSize: 20,
            ),
          )
        ],  
      ),
      content: SizedBox(
        width: 400,
        child: ListView.builder(
          itemCount: widget.differences.length,
          shrinkWrap: true,
          itemBuilder: (context, index){
            MapEntry entry = widget.differences.entries.toList()[index];
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: 20,
                  ),
                ),
                Text(
                  'C: ${entry.value[0]}  |  S: ${entry.value[1]}',
                  style: const TextStyle(
                    fontSize: 20,
                  ),
                )
              ],
            );
          }
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actions: [
        TextButton(
          onPressed: (){
            Navigator.pop(context, 'Client');
          }, 
          child: Text(
            'Client',
            style: actionsButtonStyle,
          )
        ),
        TextButton(
          onPressed: (){
            Navigator.pop(context, 'Merge');
          }, 
          child: Text(
            'Merge',
            style: actionsButtonStyle,
          )
        ),
        TextButton(
          onPressed: (){
            Navigator.pop(context, 'Server');
          }, 
          child: Text(
            'Server',
            style: actionsButtonStyle,
          )
        )
      ],
    );
  }
}