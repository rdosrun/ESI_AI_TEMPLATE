import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'auth.dart';
import 'services/agent_api.dart';
import 'storage.dart';

void main() => runApp(const AgentBuilderApp());

const _ink = Color(0xFF17202A);
const _muted = Color(0xFF667085);
const _canvas = Color(0xFFF5F7FA);
const _brand = Color(0xFF5B5BD6);

class AgentBuilderApp extends StatefulWidget {
  const AgentBuilderApp({super.key});

  @override
  State<AgentBuilderApp> createState() => _AgentBuilderAppState();
}

class _AgentBuilderAppState extends State<AgentBuilderApp> {
  final _storage = ArchitectureStorage();
  bool darkMode = false;

  @override
  void initState() {
    super.initState();
    _restoreTheme();
  }

  Future<void> _restoreTheme() async {
    final saved = await _storage.loadDarkMode();
    if (saved != null && mounted) setState(() => darkMode = saved);
  }

  Future<void> _toggleTheme() async {
    final enabled = !darkMode;
    setState(() => darkMode = enabled);
    await _storage.saveDarkMode(enabled);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Agent Architecture Builder',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _brand),
        scaffoldBackgroundColor: _canvas,
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _brand,
          brightness: Brightness.dark,
          surface: const Color(0xFF171A22),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F1117),
        cardTheme: const CardThemeData(color: Color(0xFF171A22)),
        dividerColor: const Color(0xFF343A46),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF20242E),
        ),
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      home: BuilderPage(darkMode: darkMode, onToggleTheme: _toggleTheme),
    );
  }
}

enum BlockType {
  start('Start', Icons.play_arrow_rounded, Color(0xFF12A594)),
  agent('Agent', Icons.smart_toy_outlined, Color(0xFF5B5BD6)),
  condition('If / else', Icons.call_split_rounded, Color(0xFFE58A2B)),
  loop('For loop', Icons.loop_rounded, Color(0xFFB85CC7)),
  api('API call', Icons.api_rounded, Color(0xFF2878D0)),
  tool('MCP tool', Icons.handyman_outlined, Color(0xFF31756B)),
  input('Input', Icons.input_rounded, Color(0xFF667085)),
  output('Output', Icons.output_rounded, Color(0xFFE0526F));

  const BlockType(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

class FlowNode {
  FlowNode({
    required this.id,
    required this.type,
    required this.position,
    required this.title,
    this.description = '',
    Map<String, dynamic>? config,
  }) : config = config ?? {};

  final String id;
  final BlockType type;
  Offset position;
  String title;
  String description;
  final Map<String, dynamic> config;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'position': {'x': position.dx, 'y': position.dy},
    'title': title,
    'description': description,
    'config': config,
  };

  factory FlowNode.fromJson(Map<String, dynamic> json) {
    final point = json['position'] as Map<String, dynamic>? ?? {};
    return FlowNode(
      id: json['id'] as String,
      type: BlockType.values.byName(json['type'] as String),
      position: Offset(
        (point['x'] as num? ?? 0).toDouble(),
        (point['y'] as num? ?? 0).toDouble(),
      ),
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String? ?? '',
      config: Map<String, dynamic>.from(json['config'] as Map? ?? {}),
    );
  }
}

class FlowEdge {
  FlowEdge({
    required this.id,
    required this.from,
    required this.to,
    this.label = '',
  });
  final String id;
  final String from;
  final String to;
  String label;

  Map<String, dynamic> toJson() => {
    'id': id,
    'from': from,
    'to': to,
    'label': label,
  };

  factory FlowEdge.fromJson(Map<String, dynamic> json) => FlowEdge(
    id: json['id'] as String,
    from: json['from'] as String,
    to: json['to'] as String,
    label: json['label'] as String? ?? '',
  );
}

class ArchitectureDocument {
  ArchitectureDocument({
    required this.name,
    required this.nodes,
    required this.edges,
  });
  String name;
  final List<FlowNode> nodes;
  final List<FlowEdge> edges;

  Map<String, dynamic> toJson() => {
    'schemaVersion': '1.0',
    'name': name,
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
    'nodes': nodes.map((node) => node.toJson()).toList(),
    'edges': edges.map((edge) => edge.toJson()).toList(),
  };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory ArchitectureDocument.fromJson(Map<String, dynamic> json) =>
      ArchitectureDocument(
        name: json['name'] as String? ?? 'Imported architecture',
        nodes: (json['nodes'] as List? ?? [])
            .map(
              (item) =>
                  FlowNode.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
        edges: (json['edges'] as List? ?? [])
            .map(
              (item) =>
                  FlowEdge.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
      );
}

class BuilderPage extends StatefulWidget {
  const BuilderPage({
    super.key,
    required this.darkMode,
    required this.onToggleTheme,
  });

  final bool darkMode;
  final VoidCallback onToggleTheme;

  @override
  State<BuilderPage> createState() => _BuilderPageState();
}

class _BuilderPageState extends State<BuilderPage> {
  final _canvasKey = GlobalKey();
  final _chatController = TextEditingController();
  final _storage = ArchitectureStorage();
  final _agentApi = AgentBuilderApi();
  final _authentication = EntraAuthentication();
  late ArchitectureDocument document;
  EntraUser? currentUser;
  bool authenticationLoading = true;
  String? cloudArchitectureId;
  int? cloudArchitectureVersion;
  String? deploymentStatus;
  bool cloudOperationInProgress = false;
  String? selectedNodeId;
  String? selectedEdgeId;
  String? linkSourceId;
  String? connectionDragSourceId;
  Offset? connectionDragPosition;
  Offset? connectionCanvasGlobalOrigin;
  bool showJson = false;
  bool showAgents = false;
  bool leftPanelOpen = true;
  bool rightPanelOpen = true;
  final List<({bool user, String text})> messages = [
    (
      user: false,
      text:
          'Describe the workflow you want to build. I can help you plan the blocks and connections.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    document = ArchitectureDocument(
      name: 'Customer support workflow',
      nodes: [
        FlowNode(
          id: 'node-1',
          type: BlockType.start,
          position: const Offset(70, 80),
          title: 'New request',
        ),
        FlowNode(
          id: 'node-2',
          type: BlockType.agent,
          position: const Offset(340, 80),
          title: 'Triage agent',
          description: 'Classify intent and urgency',
        ),
      ],
      edges: [FlowEdge(id: 'edge-1', from: 'node-1', to: 'node-2')],
    );
    _restoreDraft();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _authentication.currentUser();
      if (mounted) setState(() => currentUser = user);
    } catch (_) {
      // Keep the canvas usable locally when Static Web Apps auth is unavailable.
    } finally {
      if (mounted) setState(() => authenticationLoading = false);
    }
  }

  Future<void> _restoreDraft() async {
    final saved = await _storage.loadDraft();
    if (saved == null || !mounted) return;
    try {
      setState(
        () => document = ArchitectureDocument.fromJson(jsonDecode(saved)),
      );
    } catch (_) {
      // Keep the sample architecture when a stale browser draft is invalid.
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  void _addNode(BlockType type, Offset canvasPosition) {
    final id = 'node-${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      document.nodes.add(
        FlowNode(
          id: id,
          type: type,
          position: Offset(
            math.max(12, canvasPosition.dx - 90),
            math.max(12, canvasPosition.dy - 35),
          ),
          title: type.label,
          description: _defaultDescription(type),
        ),
      );
      selectedNodeId = id;
      selectedEdgeId = null;
    });
  }

  String _defaultDescription(BlockType type) => switch (type) {
    BlockType.agent => 'Choose an agent and define its goal',
    BlockType.condition => 'Evaluate a true / false expression',
    BlockType.loop => 'Repeat for each item in a collection',
    BlockType.api => 'Call an HTTP service',
    BlockType.tool => 'Call a tool exposed by an MCP server',
    BlockType.input => 'Collect workflow input',
    BlockType.output => 'Return a result',
    BlockType.start => 'Workflow entry point',
  };

  void _moveNode(FlowNode node, DragUpdateDetails details) {
    if (connectionDragSourceId != null) return;
    setState(() {
      node.position = Offset(
        math.max(0, node.position.dx + details.delta.dx),
        math.max(0, node.position.dy + details.delta.dy),
      );
    });
  }

  void _startConnectionDrag(String sourceId, Offset globalPosition) {
    final source = document.nodes
        .where((node) => node.id == sourceId)
        .firstOrNull;
    if (source == null) return;
    setState(() {
      connectionDragSourceId = sourceId;
      connectionDragPosition = source.position + const Offset(190, 38);
      connectionCanvasGlobalOrigin = globalPosition - connectionDragPosition!;
    });
  }

  void _updateConnectionDrag(Offset globalPosition) {
    final origin = connectionCanvasGlobalOrigin;
    if (origin == null) return;
    setState(() => connectionDragPosition = globalPosition - origin);
  }

  void _endConnectionDrag() {
    final sourceId = connectionDragSourceId;
    final dropPosition = connectionDragPosition;
    String? destinationId;
    if (sourceId != null && dropPosition != null) {
      destinationId = document.nodes.reversed
          .where((node) => node.id != sourceId)
          .where(
            (node) => Rect.fromLTWH(
              node.position.dx - 14,
              node.position.dy,
              204,
              76,
            ).contains(dropPosition),
          )
          .map((node) => node.id)
          .firstOrNull;
    }
    setState(() {
      connectionDragSourceId = null;
      connectionDragPosition = null;
      connectionCanvasGlobalOrigin = null;
    });
    if (sourceId != null && destinationId != null) {
      _connectNodes(sourceId, destinationId);
    }
  }

  void _cancelConnectionDrag() {
    setState(() {
      connectionDragSourceId = null;
      connectionDragPosition = null;
      connectionCanvasGlobalOrigin = null;
    });
  }

  void _selectForLink(FlowNode node) {
    setState(() {
      if (linkSourceId == null) {
        linkSourceId = node.id;
        selectedNodeId = node.id;
        selectedEdgeId = null;
        return;
      }
      _connectNodes(linkSourceId!, node.id, updateState: false);
      linkSourceId = null;
    });
  }

  void _connectNodes(String fromId, String toId, {bool updateState = true}) {
    void connect() {
      if (fromId == toId ||
          document.edges.any(
            (edge) => edge.from == fromId && edge.to == toId,
          )) {
        return;
      }
      final source = document.nodes
          .where((node) => node.id == fromId)
          .firstOrNull;
      var label = '';
      if (source?.type == BlockType.condition) {
        final branches = source!.config['branches'] as List? ?? const [];
        final usedLabels = document.edges
            .where((edge) => edge.from == fromId)
            .map((edge) => edge.label)
            .toSet();
        final available = branches
            .map((branch) => Map<String, dynamic>.from(branch as Map))
            .where((branch) => !usedLabels.contains(branch['label']))
            .firstOrNull;
        label = available?['label'] as String? ?? '';
      }
      final edge = FlowEdge(
        id: 'edge-${DateTime.now().microsecondsSinceEpoch}',
        from: fromId,
        to: toId,
        label: label,
      );
      document.edges.add(edge);
      selectedEdgeId = edge.id;
      selectedNodeId = null;
      linkSourceId = null;
      rightPanelOpen = true;
    }

    if (updateState) {
      setState(connect);
    } else {
      connect();
    }
  }

  void _deleteSelected() {
    if (selectedEdgeId != null) {
      setState(() {
        document.edges.removeWhere((edge) => edge.id == selectedEdgeId);
        selectedEdgeId = null;
      });
      return;
    }
    final id = selectedNodeId;
    if (id == null) return;
    setState(() {
      document.nodes.removeWhere((node) => node.id == id);
      document.edges.removeWhere((edge) => edge.from == id || edge.to == id);
      selectedNodeId = null;
      selectedEdgeId = null;
      if (linkSourceId == id) linkSourceId = null;
    });
  }

  Future<void> _save() async {
    await _storage.saveDraft(document.toPrettyJson());
    if (mounted) _notice('Saved to this browser');
  }

  Future<bool> _saveToCloud() async {
    if (currentUser == null) {
      _notice('Sign in with Microsoft before saving to the cloud.');
      _authentication.signIn();
      return false;
    }
    if (cloudOperationInProgress) return false;
    setState(() => cloudOperationInProgress = true);
    try {
      final result = await _agentApi.saveArchitecture(
        document.toJson(),
        architectureId: cloudArchitectureId,
      );
      if (!mounted) return false;
      setState(() {
        cloudArchitectureId = result.id;
        cloudArchitectureVersion = result.version;
        deploymentStatus = 'draft';
      });
      _notice('Saved cloud version ${result.version}');
      return true;
    } catch (error) {
      if (mounted) _notice('Cloud save failed: $error', error: true);
      return false;
    } finally {
      if (mounted) setState(() => cloudOperationInProgress = false);
    }
  }

  Future<void> _requestDeployment() async {
    if (cloudOperationInProgress) return;
    final saved = await _saveToCloud();
    if (!saved || !mounted || cloudArchitectureId == null) return;
    setState(() => cloudOperationInProgress = true);
    try {
      final result = await _agentApi.requestDeployment(cloudArchitectureId!);
      if (!mounted) return;
      setState(() => deploymentStatus = result.status);
      _notice(
        'Deployment status: ${result.status}. ${result.message} '
        'Runtime endpoint: ${result.endpoint}',
      );
    } catch (error) {
      if (mounted) _notice('Deployment request failed: $error', error: true);
    } finally {
      if (mounted) setState(() => cloudOperationInProgress = false);
    }
  }

  Future<void> _download() async {
    await _storage.downloadJson(
      '${_safeFilename(document.name)}.json',
      document.toPrettyJson(),
    );
    if (mounted) _notice('JSON download created');
  }

  Future<void> _upload() async {
    try {
      final content = await _storage.pickJson();
      if (content == null) return;
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object');
      }
      final imported = ArchitectureDocument.fromJson(decoded);
      setState(() {
        document = imported;
        cloudArchitectureId = null;
        cloudArchitectureVersion = null;
        deploymentStatus = null;
        selectedNodeId = null;
        selectedEdgeId = null;
        linkSourceId = null;
      });
      await _storage.saveDraft(document.toPrettyJson());
      if (mounted) _notice('Architecture loaded');
    } catch (error) {
      if (mounted) _notice('Could not load JSON: $error', error: true);
    }
  }

  String _safeFilename(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  void _notice(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red.shade700 : _ink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _sendChat() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      messages.add((user: true, text: text));
      messages.add((
        user: false,
        text:
            'Planning assistant placeholder: add the relevant blocks from the left, then select “Link” and click the source and destination blocks.',
      ));
      _chatController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = document.nodes
        .where((node) => node.id == selectedNodeId)
        .firstOrNull;
    final selectedEdge = document.edges
        .where((edge) => edge.id == selectedEdgeId)
        .firstOrNull;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              document: document,
              agentWorkspace: showAgents,
              onToggleWorkspace: () => setState(() => showAgents = !showAgents),
              showJson: showJson,
              linking: linkSourceId != null,
              onNameChanged: (value) => setState(() => document.name = value),
              onToggleJson: () => setState(() => showJson = !showJson),
              onLink: () => setState(
                () =>
                    linkSourceId = linkSourceId == null ? selectedNodeId : null,
              ),
              onDelete: selected == null && selectedEdge == null
                  ? null
                  : _deleteSelected,
              onSave: _save,
              onCloudSave: _saveToCloud,
              onDeploy: _requestDeployment,
              cloudOperationInProgress: cloudOperationInProgress,
              cloudVersion: cloudArchitectureVersion,
              deploymentStatus: deploymentStatus,
              currentUser: currentUser,
              authenticationLoading: authenticationLoading,
              onSignIn: _authentication.signIn,
              onSignOut: _authentication.signOut,
              onUpload: _upload,
              onDownload: _download,
              darkMode: widget.darkMode,
              onToggleTheme: widget.onToggleTheme,
            ),
            Expanded(
              child: showAgents
                  ? _DeployedAgentsWorkspace(
                      api: _agentApi,
                      currentUser: currentUser,
                      onSignIn: _authentication.signIn,
                    )
                  : Row(
                      children: [
                        if (leftPanelOpen)
                          SizedBox(
                            width: 244,
                            child: _BlockPalette(
                              onCollapse: () =>
                                  setState(() => leftPanelOpen = false),
                            ),
                          )
                        else
                          _CollapsedRail(
                            icon: Icons.chevron_right,
                            tooltip: 'Show blocks',
                            onTap: () => setState(() => leftPanelOpen = true),
                          ),
                        Expanded(
                          child: showJson
                              ? _JsonView(json: document.toPrettyJson())
                              : _FlowCanvas(
                                  key: _canvasKey,
                                  document: document,
                                  selectedNodeId: selectedNodeId,
                                  selectedEdgeId: selectedEdgeId,
                                  linkSourceId: linkSourceId,
                                  connectionDragSourceId:
                                      connectionDragSourceId,
                                  connectionDragPosition:
                                      connectionDragPosition,
                                  onDrop: _addNode,
                                  onMove: _moveNode,
                                  onSelect: (node) => setState(() {
                                    selectedNodeId = node.id;
                                    selectedEdgeId = null;
                                    rightPanelOpen = true;
                                  }),
                                  onEdgeSelect: (edge) => setState(() {
                                    selectedEdgeId = edge.id;
                                    selectedNodeId = null;
                                    rightPanelOpen = true;
                                  }),
                                  onConnectionDragStart: _startConnectionDrag,
                                  onConnectionDragUpdate: _updateConnectionDrag,
                                  onConnectionDragEnd: _endConnectionDrag,
                                  onConnectionDragCancel: _cancelConnectionDrag,
                                  onLinkSelect: _selectForLink,
                                  onClearSelection: () => setState(() {
                                    selectedNodeId = null;
                                    selectedEdgeId = null;
                                  }),
                                ),
                        ),
                        if (rightPanelOpen)
                          SizedBox(
                            width: 340,
                            child: selectedEdge != null
                                ? _EdgeInspector(
                                    edge: selectedEdge,
                                    onChanged: () => setState(() {}),
                                    onDelete: _deleteSelected,
                                    onClose: () =>
                                        setState(() => selectedEdgeId = null),
                                    onCollapse: () =>
                                        setState(() => rightPanelOpen = false),
                                  )
                                : selected == null
                                ? _ChatPanel(
                                    messages: messages,
                                    controller: _chatController,
                                    onSend: _sendChat,
                                    onCollapse: () =>
                                        setState(() => rightPanelOpen = false),
                                  )
                                : _Inspector(
                                    node: selected,
                                    integrations: document.nodes
                                        .where(
                                          (node) =>
                                              node.type == BlockType.api ||
                                              node.type == BlockType.tool,
                                        )
                                        .toList(),
                                    onChanged: () => setState(() {}),
                                    onClose: () =>
                                        setState(() => selectedNodeId = null),
                                    onCollapse: () =>
                                        setState(() => rightPanelOpen = false),
                                  ),
                          )
                        else
                          _CollapsedRail(
                            icon: Icons.chevron_left,
                            tooltip: 'Show chat and settings',
                            onTap: () => setState(() => rightPanelOpen = true),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeployedAgentsWorkspace extends StatefulWidget {
  const _DeployedAgentsWorkspace({
    required this.api,
    required this.currentUser,
    required this.onSignIn,
  });

  final AgentBuilderApi api;
  final EntraUser? currentUser;
  final VoidCallback onSignIn;

  @override
  State<_DeployedAgentsWorkspace> createState() =>
      _DeployedAgentsWorkspaceState();
}

class _DeployedAgentsWorkspaceState extends State<_DeployedAgentsWorkspace> {
  final _searchController = TextEditingController();
  final _promptController = TextEditingController();
  List<DeployedAgent> agents = const [];
  DeployedAgent? selected;
  bool loading = false;
  bool running = false;
  String? error;
  AgentInvocationResult? result;

  @override
  void initState() {
    super.initState();
    if (widget.currentUser != null) _load();
  }

  @override
  void didUpdateWidget(covariant _DeployedAgentsWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser == null && widget.currentUser != null) _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.currentUser == null || loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await widget.api.listDeployments(
        search: _searchController.text,
      );
      if (!mounted) return;
      setState(() {
        agents = loaded;
        if (selected == null ||
            !loaded.any((agent) => agent.id == selected!.id)) {
          selected = loaded.firstOrNull;
        }
      });
    } catch (caught) {
      if (mounted) setState(() => error = caught.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _run() async {
    final agent = selected;
    final prompt = _promptController.text.trim();
    if (agent == null || prompt.isEmpty || running) return;
    setState(() {
      running = true;
      error = null;
      result = null;
    });
    try {
      final response = await widget.api.invokeDeployment(agent.id, prompt);
      if (mounted) setState(() => result = response);
    } catch (caught) {
      if (mounted) setState(() => error = caught.toString());
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentUser == null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 42, color: _brand),
                  const SizedBox(height: 16),
                  const Text(
                    'Sign in to run deployed agents',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Only agents deployed by your Microsoft account are shown.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: widget.onSignIn,
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in with Microsoft'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 360,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Deployed agents',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('agent-search-field'),
                      controller: _searchController,
                      onSubmitted: (_) => _load(),
                      decoration: InputDecoration(
                        hintText: 'Search by agent name',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          tooltip: 'Search deployed agents',
                          onPressed: loading ? null : _load,
                          icon: const Icon(Icons.arrow_forward),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (loading) const LinearProgressIndicator(),
                    Expanded(
                      child: agents.isEmpty && !loading
                          ? const Center(
                              child: Text(
                                'No deployed agents found.',
                                style: TextStyle(color: _muted),
                              ),
                            )
                          : ListView.separated(
                              itemCount: agents.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final agent = agents[index];
                                return ListTile(
                                  selected: selected?.id == agent.id,
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.smart_toy_outlined),
                                  ),
                                  title: Text(agent.name),
                                  subtitle: Text(
                                    'Architecture v${agent.architectureVersion} • ${agent.status}',
                                  ),
                                  onTap: () => setState(() {
                                    selected = agent;
                                    result = null;
                                    error = null;
                                  }),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: selected == null
                    ? const Center(
                        child: Text('Select a deployed agent to run.'),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selected!.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Runtime ${selected!.runtimeVersion} • ${selected!.status}',
                            style: const TextStyle(color: _muted),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            key: const ValueKey('agent-prompt-field'),
                            controller: _promptController,
                            minLines: 3,
                            maxLines: 7,
                            decoration: const InputDecoration(
                              labelText: 'What do you want this agent to do?',
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            key: const ValueKey('run-deployed-agent'),
                            onPressed: running ? null : _run,
                            icon: running
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.play_arrow),
                            label: Text(running ? 'Running…' : 'Run agent'),
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                          if (result != null) ...[
                            const SizedBox(height: 20),
                            if (result!.apiResults.isNotEmpty) ...[
                              const Text(
                                'API calls',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              ...result!.apiResults.map(
                                (apiResult) => ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  title: Text(apiResult.title),
                                  subtitle: Text(
                                    'HTTP ${apiResult.statusCode}',
                                  ),
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      constraints: const BoxConstraints(
                                        maxHeight: 160,
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerLow,
                                      child: SingleChildScrollView(
                                        child: SelectableText(apiResult.body),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            const Text(
                              'Result',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerLow,
                                  border: Border.all(
                                    color: Theme.of(context).dividerColor,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: SingleChildScrollView(
                                  child: SelectableText(result!.output),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Model: ${result!.model} • Tokens: ${result!.usage['total_tokens'] ?? 'n/a'}',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.document,
    required this.agentWorkspace,
    required this.onToggleWorkspace,
    required this.showJson,
    required this.linking,
    required this.onNameChanged,
    required this.onToggleJson,
    required this.onLink,
    required this.onDelete,
    required this.onSave,
    required this.onCloudSave,
    required this.onDeploy,
    required this.cloudOperationInProgress,
    required this.cloudVersion,
    required this.deploymentStatus,
    required this.currentUser,
    required this.authenticationLoading,
    required this.onSignIn,
    required this.onSignOut,
    required this.onUpload,
    required this.onDownload,
    required this.darkMode,
    required this.onToggleTheme,
  });

  final ArchitectureDocument document;
  final bool agentWorkspace;
  final VoidCallback onToggleWorkspace;
  final bool showJson;
  final bool linking;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onToggleJson;
  final VoidCallback onLink;
  final VoidCallback? onDelete;
  final VoidCallback onSave;
  final VoidCallback onCloudSave;
  final VoidCallback onDeploy;
  final bool cloudOperationInProgress;
  final int? cloudVersion;
  final String? deploymentStatus;
  final EntraUser? currentUser;
  final bool authenticationLoading;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;
  final VoidCallback onUpload;
  final VoidCallback onDownload;
  final bool darkMode;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) => Container(
    height: 68,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _brand,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.account_tree_outlined,
            color: Colors.white,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Agent Builder',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          key: const ValueKey('agent-workspace-toggle'),
          onPressed: onToggleWorkspace,
          icon: Icon(
            agentWorkspace
                ? Icons.account_tree_outlined
                : Icons.smart_toy_outlined,
            size: 18,
          ),
          label: Text(agentWorkspace ? 'Back to builder' : 'Search agents'),
        ),
        const SizedBox(width: 28),
        SizedBox(
          width: 240,
          child: TextFormField(
            initialValue: document.name,
            onChanged: onNameChanged,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Architecture name',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (cloudVersion != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Tooltip(
                      message: deploymentStatus ?? 'draft',
                      child: Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('Cloud v$cloudVersion'),
                      ),
                    ),
                  ),
                _BarButton(
                  icon: linking ? Icons.close : Icons.link,
                  label: linking ? 'Cancel link' : 'Link',
                  onTap: onLink,
                ),
                _BarButton(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  onTap: onDelete,
                ),
                _BarButton(
                  icon: showJson
                      ? Icons.account_tree_outlined
                      : Icons.data_object,
                  label: showJson ? 'Canvas' : 'JSON',
                  onTap: onToggleJson,
                ),
                _BarButton(
                  icon: Icons.upload_file_outlined,
                  label: 'Upload',
                  onTap: onUpload,
                ),
                _BarButton(
                  icon: Icons.download_outlined,
                  label: 'Export',
                  onTap: onDownload,
                ),
                _BarButton(
                  icon: Icons.cloud_upload_outlined,
                  label: 'Cloud save',
                  onTap: cloudOperationInProgress ? null : onCloudSave,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: cloudOperationInProgress ? null : onSave,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Local'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: cloudOperationInProgress ? null : onDeploy,
                  icon: cloudOperationInProgress
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.rocket_launch_outlined, size: 18),
                  label: const Text('Deploy'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const ValueKey('theme-toggle'),
                  tooltip: darkMode ? 'Use light mode' : 'Use dark mode',
                  onPressed: onToggleTheme,
                  icon: Icon(
                    darkMode
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                ),
                const SizedBox(width: 4),
                if (authenticationLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (currentUser == null)
                  OutlinedButton.icon(
                    onPressed: onSignIn,
                    icon: const Icon(Icons.login, size: 18),
                    label: const Text('Sign in'),
                  )
                else
                  PopupMenuButton<void>(
                    tooltip: 'Microsoft account',
                    itemBuilder: (context) => [
                      PopupMenuItem<void>(
                        enabled: false,
                        child: Text(currentUser!.displayName),
                      ),
                      PopupMenuItem<void>(
                        onTap: onSignOut,
                        child: const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.logout, size: 18),
                          title: Text('Sign out'),
                        ),
                      ),
                    ],
                    child: Chip(
                      avatar: const Icon(Icons.account_circle, size: 18),
                      label: Text(currentUser!.displayName),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    label: Text(label),
    style: TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.onSurface,
    ),
  );
}

class _BlockPalette extends StatelessWidget {
  const _BlockPalette({required this.onCollapse});
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.surface,
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'BLOCKS',
                style: TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Collapse blocks',
              onPressed: onCollapse,
              icon: const Icon(Icons.chevron_left, size: 19),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Drag onto the canvas',
          style: TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: BlockType.values
                .map((type) => _PaletteBlock(type: type))
                .toList(),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Tip: select Link, then click a source block and a destination block.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _CollapsedRail extends StatelessWidget {
  const _CollapsedRail({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.symmetric(
        vertical: BorderSide(color: Theme.of(context).dividerColor),
      ),
    ),
    alignment: Alignment.topCenter,
    padding: const EdgeInsets.only(top: 10),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 20),
    ),
  );
}

class _PaletteBlock extends StatelessWidget {
  const _PaletteBlock({required this.type});
  final BlockType type;

  Widget _tile(BuildContext context, {bool dragging = false}) => Container(
    width: 205,
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: dragging
          ? Theme.of(context).colorScheme.surface
          : Theme.of(context).colorScheme.surfaceContainerLow,
      border: Border.all(
        color: dragging ? type.color : Theme.of(context).dividerColor,
      ),
      borderRadius: BorderRadius.circular(9),
      boxShadow: dragging
          ? const [BoxShadow(color: Color(0x22000000), blurRadius: 14)]
          : null,
    ),
    child: Row(
      children: [
        Icon(type.icon, color: type.color, size: 20),
        const SizedBox(width: 10),
        Text(type.label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Draggable<BlockType>(
    data: type,
    feedback: Material(
      color: Colors.transparent,
      child: _tile(context, dragging: true),
    ),
    childWhenDragging: Opacity(opacity: 0.35, child: _tile(context)),
    child: _tile(context),
  );
}

class _FlowCanvas extends StatelessWidget {
  const _FlowCanvas({
    super.key,
    required this.document,
    required this.selectedNodeId,
    required this.selectedEdgeId,
    required this.linkSourceId,
    required this.connectionDragSourceId,
    required this.connectionDragPosition,
    required this.onDrop,
    required this.onMove,
    required this.onSelect,
    required this.onEdgeSelect,
    required this.onConnectionDragStart,
    required this.onConnectionDragUpdate,
    required this.onConnectionDragEnd,
    required this.onConnectionDragCancel,
    required this.onLinkSelect,
    required this.onClearSelection,
  });
  final ArchitectureDocument document;
  final String? selectedNodeId;
  final String? selectedEdgeId;
  final String? linkSourceId;
  final String? connectionDragSourceId;
  final Offset? connectionDragPosition;
  final void Function(BlockType, Offset) onDrop;
  final void Function(FlowNode, DragUpdateDetails) onMove;
  final ValueChanged<FlowNode> onSelect;
  final ValueChanged<FlowEdge> onEdgeSelect;
  final void Function(String, Offset) onConnectionDragStart;
  final ValueChanged<Offset> onConnectionDragUpdate;
  final VoidCallback onConnectionDragEnd;
  final VoidCallback onConnectionDragCancel;
  final ValueChanged<FlowNode> onLinkSelect;
  final VoidCallback onClearSelection;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => DragTarget<BlockType>(
      onAcceptWithDetails: (details) {
        final box = context.findRenderObject() as RenderBox;
        onDrop(details.data, box.globalToLocal(details.offset));
      },
      builder: (context, candidateData, rejectedData) => GestureDetector(
        onTap: onClearSelection,
        child: ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GridPainter(Theme.of(context).dividerColor),
                ),
              ),
              ...document.edges.map(
                (edge) => Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.deferToChild,
                    onTap: () => onEdgeSelect(edge),
                    child: CustomPaint(
                      painter: _EdgePainter(
                        document.nodes,
                        document.edges,
                        edge,
                        selected: selectedEdgeId == edge.id,
                      ),
                    ),
                  ),
                ),
              ),
              if (connectionDragSourceId != null &&
                  connectionDragPosition != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _ConnectionPreviewPainter(
                        nodes: document.nodes,
                        sourceId: connectionDragSourceId!,
                        end: connectionDragPosition!,
                      ),
                    ),
                  ),
                ),
              if (document.nodes.isEmpty)
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_outline, color: _muted, size: 34),
                      SizedBox(height: 10),
                      Text(
                        'Drag a block here to begin',
                        style: TextStyle(color: _muted),
                      ),
                    ],
                  ),
                ),
              ...document.nodes.map(
                (node) => Positioned(
                  left: node.position.dx.clamp(
                    0,
                    math.max(0, constraints.maxWidth - 200),
                  ),
                  top: node.position.dy.clamp(
                    0,
                    math.max(0, constraints.maxHeight - 92),
                  ),
                  child: _FlowNodeCard(
                    node: node,
                    selected: selectedNodeId == node.id,
                    linkSource: linkSourceId == node.id,
                    linking: linkSourceId != null,
                    onTap: () => linkSourceId == null
                        ? onSelect(node)
                        : onLinkSelect(node),
                    onDoubleTap: () => onLinkSelect(node),
                    onMove: (details) => onMove(node, details),
                    onConnectionDragStart: onConnectionDragStart,
                    onConnectionDragUpdate: onConnectionDragUpdate,
                    onConnectionDragEnd: onConnectionDragEnd,
                    onConnectionDragCancel: onConnectionDragCancel,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FlowNodeCard extends StatelessWidget {
  const _FlowNodeCard({
    required this.node,
    required this.selected,
    required this.linkSource,
    required this.linking,
    required this.onTap,
    required this.onDoubleTap,
    required this.onMove,
    required this.onConnectionDragStart,
    required this.onConnectionDragUpdate,
    required this.onConnectionDragEnd,
    required this.onConnectionDragCancel,
  });
  final FlowNode node;
  final bool selected;
  final bool linkSource;
  final bool linking;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final GestureDragUpdateCallback onMove;
  final void Function(String, Offset) onConnectionDragStart;
  final ValueChanged<Offset> onConnectionDragUpdate;
  final VoidCallback onConnectionDragEnd;
  final VoidCallback onConnectionDragCancel;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: [
      Positioned(
        left: -10,
        child: Tooltip(
          message: 'Connection input',
          child: CustomPaint(
            size: const Size(18, 22),
            painter: _HomePlatePortPainter(color: node.type.color),
          ),
        ),
      ),
      GestureDetector(
        key: ValueKey('node-card-${node.id}'),
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        onPanUpdate: onMove,
        child: Container(
          width: 190,
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: linkSource
                  ? _brand
                  : selected
                  ? node.type.color
                  : Theme.of(context).dividerColor,
              width: selected || linkSource ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x160F172A),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: node.type.color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(node.type.icon, color: node.type.color, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      node.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (node.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        node.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _muted,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (linking) const Icon(Icons.ads_click, size: 15, color: _brand),
            ],
          ),
        ),
      ),
      Positioned(
        right: 0,
        child: Tooltip(
          message: 'Drag to connect',
          child: Listener(
            key: ValueKey('output-port-${node.id}'),
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) =>
                onConnectionDragStart(node.id, event.position),
            onPointerMove: (event) => onConnectionDragUpdate(event.position),
            onPointerUp: (_) => onConnectionDragEnd(),
            onPointerCancel: (_) => onConnectionDragCancel(),
            child: _ConnectionPort(color: node.type.color),
          ),
        ),
      ),
    ],
  );
}

class _ConnectionPort extends StatelessWidget {
  const _ConnectionPort({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 16,
    height: 16,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      shape: BoxShape.circle,
      border: Border.all(color: color, width: 3),
      boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 4)],
    ),
  );
}

class _HomePlatePortPainter extends CustomPainter {
  const _HomePlatePortPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width * .38, 1)
      ..lineTo(size.width - 1, 1)
      ..lineTo(size.width - 1, size.height - 1)
      ..lineTo(size.width * .38, size.height - 1)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _HomePlatePortPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ConnectionPreviewPainter extends CustomPainter {
  const _ConnectionPreviewPainter({
    required this.nodes,
    required this.sourceId,
    required this.end,
  });
  final List<FlowNode> nodes;
  final String sourceId;
  final Offset end;

  @override
  void paint(Canvas canvas, Size size) {
    final source = nodes.where((node) => node.id == sourceId).firstOrNull;
    if (source == null) return;
    final start = source.position + const Offset(190, 38);
    final bend = math.max(45.0, (end.dx - start.dx).abs() / 2);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        start.dx + bend,
        start.dy,
        end.dx - bend,
        end.dy,
        end.dx,
        end.dy,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = _brand
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _ConnectionPreviewPainter oldDelegate) =>
      oldDelegate.end != end || oldDelegate.sourceId != sourceId;
}

class _GridPainter extends CustomPainter {
  const _GridPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 24) {
      for (double y = 0; y < size.height; y += 24) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _EdgePainter extends CustomPainter {
  _EdgePainter(this.nodes, this.edges, this.edge, {required this.selected});
  final List<FlowNode> nodes;
  final List<FlowEdge> edges;
  final FlowEdge edge;
  final bool selected;

  (Offset, Offset, Offset, Offset)? get _geometry {
    final from = nodes.where((node) => node.id == edge.from).firstOrNull;
    final to = nodes.where((node) => node.id == edge.to).firstOrNull;
    if (from == null || to == null) return null;

    final start = from.position + const Offset(190, 38);
    final end = to.position + const Offset(0, 38);
    final outgoing = edges
        .where((candidate) => candidate.from == edge.from)
        .toList();
    final laneIndex = outgoing.indexWhere(
      (candidate) => candidate.id == edge.id,
    );
    final laneOffset = (laneIndex - (outgoing.length - 1) / 2) * 28.0;
    final bend = math.max(55.0, (end.dx - start.dx).abs() / 2);
    final control1 = Offset(
      start.dx + math.min(90, bend),
      start.dy + laneOffset,
    );
    final control2 = Offset(end.dx - bend, end.dy);
    return (start, end, control1, control2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _geometry;
    if (geometry == null) return;
    final (start, end, control1, control2) = geometry;
    final color = selected ? _brand : const Color(0xFF8993A4);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        control1.dx,
        control1.dy,
        control2.dx,
        control2.dy,
        end.dx,
        end.dy,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = selected ? 3 : 2
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(end.dx - 8, end.dy - 5)
        ..lineTo(end.dx - 8, end.dy + 5)
        ..close(),
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    if (edge.label.isNotEmpty) {
      final labelOffset = _bezierPoint(start, end, control1, control2, .5);
      final textPainter = TextPainter(
        text: TextSpan(
          text: edge.label,
          style: TextStyle(
            color: selected ? _brand : _ink,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            backgroundColor: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        labelOffset - Offset(textPainter.width / 2, textPainter.height + 5),
      );
    }
  }

  Offset _bezierPoint(
    Offset start,
    Offset end,
    Offset control1,
    Offset control2,
    double t,
  ) {
    final oneMinusT = 1 - t;
    return start * math.pow(oneMinusT, 3).toDouble() +
        control1 * (3 * math.pow(oneMinusT, 2) * t).toDouble() +
        control2 * (3 * oneMinusT * t * t) +
        end * math.pow(t, 3).toDouble();
  }

  @override
  bool? hitTest(Offset position) {
    final geometry = _geometry;
    if (geometry == null) return false;
    final (start, end, control1, control2) = geometry;
    for (var step = 0; step <= 40; step++) {
      if ((_bezierPoint(start, end, control1, control2, step / 40) - position)
              .distance <=
          9) {
        return true;
      }
    }
    return false;
  }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) => true;
}

class _Inspector extends StatelessWidget {
  const _Inspector({
    required this.node,
    required this.integrations,
    required this.onChanged,
    required this.onClose,
    required this.onCollapse,
  });
  final FlowNode node;
  final List<FlowNode> integrations;
  final VoidCallback onChanged;
  final VoidCallback onClose;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    padding: const EdgeInsets.all(18),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(node.type.icon, color: node.type.color),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Block settings',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 19),
              ),
              IconButton(
                tooltip: 'Collapse panel',
                onPressed: onCollapse,
                icon: const Icon(Icons.chevron_right, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextFormField(
            key: ValueKey('${node.id}-title'),
            initialValue: node.title,
            onChanged: (value) {
              node.title = value;
              onChanged();
            },
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: ValueKey('${node.id}-description'),
            initialValue: node.description,
            minLines: 3,
            maxLines: 5,
            onChanged: (value) {
              node.description = value;
              onChanged();
            },
            decoration: const InputDecoration(
              labelText: 'Description',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          if (node.type == BlockType.condition) ...[
            _ConditionBuilder(node: node, onChanged: onChanged),
            const SizedBox(height: 18),
          ],
          if (node.type == BlockType.agent) ...[
            _AgentConfigBuilder(
              node: node,
              integrations: integrations,
              onChanged: onChanged,
            ),
            const SizedBox(height: 18),
          ],
          if (node.type == BlockType.api || node.type == BlockType.tool) ...[
            _IntegrationConfigBuilder(node: node, onChanged: onChanged),
            const SizedBox(height: 18),
          ],
          const Text(
            'JSON identifier',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          SelectableText(
            node.id,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 24),
          const Text(
            'Additional block-specific settings will be stored in the config object.',
            style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    ),
  );
}

class _AgentConfigBuilder extends StatelessWidget {
  const _AgentConfigBuilder({
    required this.node,
    required this.integrations,
    required this.onChanged,
  });
  final FlowNode node;
  final List<FlowNode> integrations;
  final VoidCallback onChanged;

  List<String> get references =>
      List<String>.from(node.config['integrationRefs'] as List? ?? const []);

  void _toggleReference(String id, bool selected) {
    final updated = references;
    selected ? updated.add(id) : updated.remove(id);
    node.config['integrationRefs'] = updated.toSet().toList();
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final selectedReferences = references.toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AGENT CONFIGURATION',
          style: TextStyle(
            color: _muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey('${node.id}-instructions'),
          initialValue: node.config['instructions'] as String? ?? '',
          minLines: 5,
          maxLines: 10,
          onChanged: (value) {
            node.config['instructions'] = value;
            onChanged();
          },
          decoration: const InputDecoration(
            labelText: 'Agent instructions',
            hintText:
                'Explain the agent’s role, boundaries, decision rules, and expected output…',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'REFERENCED INPUTS',
          style: TextStyle(
            color: _muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose the API and MCP blocks this agent is allowed to reference.',
          style: TextStyle(color: _muted, fontSize: 12, height: 1.35),
        ),
        const SizedBox(height: 8),
        if (integrations.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: const Text(
              'Add an API call or MCP tool block to make it available here.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          )
        else
          ...integrations.map(
            (integration) => Container(
              margin: const EdgeInsets.only(bottom: 7),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: CheckboxListTile(
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: selectedReferences.contains(integration.id),
                  onChanged: (value) =>
                      _toggleReference(integration.id, value ?? false),
                  secondary: Icon(
                    integration.type.icon,
                    color: integration.type.color,
                    size: 20,
                  ),
                  title: Text(
                    integration.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    integration.config['endpoint'] as String? ??
                        (integration.type == BlockType.api
                            ? 'API input'
                            : 'MCP input'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _IntegrationConfigBuilder extends StatelessWidget {
  const _IntegrationConfigBuilder({
    required this.node,
    required this.onChanged,
  });
  final FlowNode node;
  final VoidCallback onChanged;

  void _set(String key, String? value) {
    node.config[key] = value ?? '';
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final isApi = node.type == BlockType.api;
    final defaultProtocol = isApi ? 'GET' : 'streamable-http';
    final protocol = node.config['protocol'] as String? ?? defaultProtocol;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isApi ? 'API CONFIGURATION' : 'MCP CONFIGURATION',
          style: const TextStyle(
            color: _muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey('${node.id}-endpoint'),
          initialValue: node.config['endpoint'] as String? ?? '',
          onChanged: (value) => _set('endpoint', value),
          decoration: InputDecoration(
            labelText: isApi ? 'API URL' : 'MCP server URL',
            hintText: isApi
                ? 'https://api.example.com/v1/items'
                : 'https://server.example.com/mcp',
            prefixIcon: const Icon(Icons.link, size: 19),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: protocol,
          decoration: InputDecoration(
            labelText: isApi ? 'HTTP method' : 'Transport',
            border: const OutlineInputBorder(),
          ),
          items:
              (isApi
                      ? const ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']
                      : const ['streamable-http', 'sse', 'stdio'])
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
          onChanged: (value) => _set('protocol', value),
        ),
        if (isApi && protocol != 'GET') ...[
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('${node.id}-request-body-template'),
            initialValue: node.config['requestBodyTemplate'] as String? ?? '',
            onChanged: (value) => _set('requestBodyTemplate', value),
            minLines: 3,
            maxLines: 7,
            decoration: const InputDecoration(
              labelText: 'JSON request body template',
              hintText: '{"input": "{{input}}"}',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
        ],
        if (!isApi) ...[
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('${node.id}-tool-name'),
            initialValue: node.config['toolName'] as String? ?? '',
            onChanged: (value) => _set('toolName', value),
            decoration: const InputDecoration(
              labelText: 'Tool name',
              hintText: 'ask_question',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey('${node.id}-credential-reference'),
          initialValue: node.config['credentialReference'] as String? ?? '',
          onChanged: (value) => _set('credentialReference', value),
          decoration: const InputDecoration(
            labelText: 'Token / credential reference',
            hintText: 'KEY_VAULT_SECRET_NAME',
            prefixIcon: Icon(Icons.key_outlined, size: 19),
            border: OutlineInputBorder(),
          ),
        ),
        if (isApi) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue:
                      node.config['credentialHeader'] as String? ??
                      'Authorization',
                  onChanged: (value) => _set('credentialHeader', value),
                  decoration: const InputDecoration(
                    labelText: 'Credential header',
                    hintText: 'Authorization',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  initialValue:
                      node.config['credentialScheme'] as String? ?? 'Bearer',
                  onChanged: (value) => _set('credentialScheme', value),
                  decoration: const InputDecoration(
                    labelText: 'Credential scheme',
                    hintText: 'Bearer',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, color: _muted, size: 16),
            SizedBox(width: 7),
            Expanded(
              child: Text(
                'Store only a Key Vault secret name or environment-variable reference. Raw tokens must not be exported in architecture JSON.',
                style: TextStyle(color: _muted, fontSize: 11, height: 1.35),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConditionBuilder extends StatelessWidget {
  const _ConditionBuilder({required this.node, required this.onChanged});
  final FlowNode node;
  final VoidCallback onChanged;

  List<Map<String, dynamic>> get branches {
    final existing = node.config['branches'] as List?;
    if (existing != null) {
      return existing
          .map((branch) => Map<String, dynamic>.from(branch as Map))
          .toList();
    }
    final defaults = <Map<String, dynamic>>[
      {'condition': '', 'label': 'true'},
      {'condition': 'else', 'label': 'false'},
    ];
    node.config['branches'] = defaults;
    return defaults;
  }

  void _persist(List<Map<String, dynamic>> value) {
    node.config['branches'] = value;
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final rules = branches;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'IF / ELSE BUILDER',
          style: TextStyle(
            color: _muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Each rule supplies a label to the next outgoing connection.',
          style: TextStyle(color: _muted, fontSize: 12, height: 1.35),
        ),
        const SizedBox(height: 12),
        ...rules.asMap().entries.map((entry) {
          final index = entry.key;
          final rule = entry.value;
          final isElse = rule['condition'] == 'else';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isElse
                          ? 'ELSE'
                          : index == 0
                          ? 'IF'
                          : 'ELSE IF',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onTertiaryContainer,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    if (rules.length > 2)
                      IconButton(
                        tooltip: 'Remove rule',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          rules.removeAt(index);
                          _persist(rules);
                        },
                        icon: const Icon(Icons.close, size: 16),
                      ),
                  ],
                ),
                if (!isElse)
                  TextFormField(
                    key: ValueKey('${node.id}-condition-$index'),
                    initialValue: rule['condition'] as String? ?? '',
                    onChanged: (value) {
                      rules[index]['condition'] = value;
                      _persist(rules);
                    },
                    decoration: const InputDecoration(
                      labelText: 'If expression',
                      hintText: 'priority == high',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                if (!isElse) const SizedBox(height: 9),
                TextFormField(
                  key: ValueKey('${node.id}-branch-label-$index'),
                  initialValue: rule['label'] as String? ?? '',
                  onChanged: (value) {
                    rules[index]['label'] = value;
                    _persist(rules);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Outgoing link label',
                    hintText: 'high priority',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: () {
            final elseIndex = rules.indexWhere(
              (rule) => rule['condition'] == 'else',
            );
            final newRule = <String, dynamic>{
              'condition': '',
              'label': 'branch ${rules.length}',
            };
            if (elseIndex == -1) {
              rules.add(newRule);
            } else {
              rules.insert(elseIndex, newRule);
            }
            _persist(rules);
          },
          icon: const Icon(Icons.add, size: 17),
          label: const Text('Add else-if rule'),
        ),
      ],
    );
  }
}

class _EdgeInspector extends StatelessWidget {
  const _EdgeInspector({
    required this.edge,
    required this.onChanged,
    required this.onDelete,
    required this.onClose,
    required this.onCollapse,
  });
  final FlowEdge edge;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final VoidCallback onClose;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.timeline, color: _brand),
            const SizedBox(width: 9),
            const Expanded(
              child: Text(
                'Connection settings',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            IconButton(
              tooltip: 'Close settings',
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 19),
            ),
            IconButton(
              tooltip: 'Collapse panel',
              onPressed: onCollapse,
              icon: const Icon(Icons.chevron_right, size: 19),
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextFormField(
          key: ValueKey('${edge.id}-label'),
          initialValue: edge.label,
          onChanged: (value) {
            edge.label = value;
            onChanged();
          },
          decoration: const InputDecoration(
            labelText: 'Link label',
            hintText: 'approved, true, retry…',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '${edge.from}  →  ${edge.to}',
          style: const TextStyle(
            color: _muted,
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          onPressed: onDelete,
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
          icon: const Icon(Icons.link_off, size: 18),
          label: const Text('Remove connection'),
        ),
      ],
    ),
  );
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.messages,
    required this.controller,
    required this.onSend,
    required this.onCollapse,
  });
  final List<({bool user, String text})> messages;
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFF0EFFF),
                child: Icon(Icons.auto_awesome, color: _brand, size: 17),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Builder assistant',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Planning mode',
                      style: TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Collapse panel',
                onPressed: onCollapse,
                icon: const Icon(Icons.chevron_right, size: 19),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              return Align(
                alignment: message.user
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(11),
                  constraints: const BoxConstraints(maxWidth: 250),
                  decoration: BoxDecoration(
                    color: message.user
                        ? _brand
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: message.user
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: controller,
            onSubmitted: (_) => onSend(),
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Describe your workflow…',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: IconButton(
                onPressed: onSend,
                icon: const Icon(Icons.send_rounded),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _JsonView extends StatelessWidget {
  const _JsonView({required this.json});
  final String json;

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF111827),
    padding: const EdgeInsets.all(24),
    child: SingleChildScrollView(
      child: SelectableText(
        json,
        style: const TextStyle(
          color: Color(0xFFD6E3F0),
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.45,
        ),
      ),
    ),
  );
}
