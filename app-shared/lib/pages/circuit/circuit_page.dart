import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:orchid/api/orchid_api.dart';
import 'package:orchid/api/user_preferences.dart';
import 'package:orchid/pages/circuit/openvpn_hop_page.dart';
import 'package:orchid/pages/circuit/orchid_hop_page.dart';
import 'package:orchid/pages/common/formatting.dart';
import 'package:orchid/pages/keys/keys_page.dart';
import 'package:orchid/util/collections.dart';

import '../app_gradients.dart';
import '../app_text.dart';
import 'circuit_hop.dart';

class CircuitPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return new CircuitPageState();
  }
}

class CircuitPageState extends State<CircuitPage> {
  List<UniqueHop> _hops;
  bool _keysAvailable = false;

  @override
  void initState() {
    super.initState();
    initStateAsync();
  }

  void initStateAsync() async {
    var circuit = await UserPreferences().getCircuit();
    var keys = await UserPreferences().getKeys();
    if (mounted) {
      setState(() {
        // Wrap the hops with a locally unique id for the UI
        _hops = mapIndexed(circuit?.hops ?? [], ((index, hop) {
          var key = DateTime.now().millisecondsSinceEpoch + index;
          return UniqueHop(key: key, hop: hop);
        }))
            .toList();
        _keysAvailable = keys != null && keys.length > 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: AppGradients.basicGradient),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            pady(16),
            Expanded(child: _buildListView()),
            Visibility(
              visible: _keysAvailable,
              child: FloatingAddButton(onPressed: _addHop),
              replacement: Text("Add keys before creating a circuit...",
                  style: AppText.textHintStyle
                      .copyWith(fontStyle: FontStyle.italic, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  ReorderableListView _buildListView() {
    return ReorderableListView(
        children: (_hops ?? []).map((uniqueHop) {
          return Dismissible(
            background: Container(
              color: Colors.red,
              child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "Delete",
                      style: TextStyle(color: Colors.white),
                    ),
                  )),
            ),
            onDismissed: (direction) {
              _deleteHop(uniqueHop);
            },
            child: ListTile(
              onTap: () {
                _editHop(uniqueHop);
              },
              key: Key(uniqueHop.key.toString()),
              title: Text(
                uniqueHop.hop.displayName(),
                style: AppText.listItem,
              ),
              trailing: Icon(Icons.menu),
            ),
            key: Key(uniqueHop.key.toString()),
          );
        }).toList(),
        onReorder: _onReorder);
  }

  void _addHop() async {
    _showAddHopChoices(
      context: context,
      child: CupertinoActionSheet(
          title: Text('Hop Type', style: TextStyle(fontSize: 21)),
          actions: <Widget>[
            CupertinoActionSheetAction(
              child: const Text("Orchid"),
              onPressed: () {
                Navigator.pop(context, Protocol.Orchid);
              },
            ),
            CupertinoActionSheetAction(
              child: const Text("Open VPN"),
              onPressed: () {
                Navigator.pop(context, Protocol.OpenVPN);
              },
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.pop(context);
            },
          )),
    );
  }

  void _showAddHopChoices({BuildContext context, Widget child}) {
    showCupertinoModalPopup<Protocol>(
      context: context,
      builder: (BuildContext context) => child,
    ).then<void>((value) {
      if (value != null) {
        _addHopType(value);
      }
    });
  }

  void _addHopType(Protocol hopType) async {
    EditableHop editableHop = EditableHop.empty();
    HopEditor editor;
    switch (hopType) {
      case Protocol.Orchid:
        editor = OrchidHopPage(editableHop: editableHop);
        break;
      case Protocol.OpenVPN:
        editor = OpenVPNHopPage(editableHop: editableHop);
        break;
    }

    await _showEditor(editor);
    if (_hops == null) {
      _hops = [];
    }
    setState(() {
      _hops.add(editableHop.value);
    });
    _saveCircuit();
  }

  void _editHop(UniqueHop uniqueHop) async {
    EditableHop editableHop = EditableHop(uniqueHop);
    var editor;
    switch (uniqueHop.hop.protocol) {
      case Protocol.Orchid:
        editor = OrchidHopPage(editableHop: editableHop);
        break;
      case Protocol.OpenVPN:
        editor = OpenVPNHopPage(editableHop: editableHop);
        break;
    }

    await _showEditor(editor);
    var index = _hops.indexOf(uniqueHop);
    setState(() {
      _hops.removeAt(index);
      _hops.insert(index, editableHop.value);
    });
    _saveCircuit();
  }

  Future<UniqueHop> _showEditor(editor) async {
    var route = MaterialPageRoute<UniqueHop>(builder: (context) => editor);
    return await Navigator.push(context, route);
  }

  // Callback for swipe to delete
  void _deleteHop(UniqueHop uniqueHop) {
    var index = _hops.indexOf(uniqueHop);
    setState(() {
      _hops.removeAt(index);
    });
    _saveCircuit();
  }

  void _saveCircuit() {
    var circuit = Circuit(_hops.map((uniqueHop) => uniqueHop.hop).toList());
    UserPreferences().setCircuit(circuit);
    OrchidAPI().updateConfiguration();
  }

  // Callback for drag to reorder
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final UniqueHop hop = _hops.removeAt(oldIndex);
      _hops.insert(newIndex, hop);
    });
    _saveCircuit();
  }
}
