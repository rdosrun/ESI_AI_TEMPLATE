import 'dart:convert';

import 'package:agent_builder/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('architecture JSON round-trips nodes and edges', () {
    final original = ArchitectureDocument(
      name: 'Test architecture',
      nodes: [
        FlowNode(
          id: 'start',
          type: BlockType.start,
          position: const Offset(10, 20),
          title: 'Start',
        ),
        FlowNode(
          id: 'agent',
          type: BlockType.agent,
          position: const Offset(250, 20),
          title: 'Agent',
        ),
      ],
      edges: [FlowEdge(id: 'edge-1', from: 'start', to: 'agent')],
    );

    final restored = ArchitectureDocument.fromJson(
      jsonDecode(original.toPrettyJson()),
    );

    expect(restored.name, 'Test architecture');
    expect(restored.nodes, hasLength(2));
    expect(restored.nodes.last.type, BlockType.agent);
    expect(restored.nodes.first.position, const Offset(10, 20));
    expect(restored.edges.single.from, 'start');
    expect(restored.edges.single.to, 'agent');
  });

  test('condition branches and connection labels persist in JSON', () {
    final condition = FlowNode(
      id: 'condition',
      type: BlockType.condition,
      position: const Offset(20, 40),
      title: 'Route request',
      config: {
        'branches': [
          {'condition': 'priority == high', 'label': 'urgent'},
          {'condition': 'else', 'label': 'normal'},
        ],
      },
    );
    final original = ArchitectureDocument(
      name: 'Conditional workflow',
      nodes: [condition],
      edges: [
        FlowEdge(
          id: 'edge-conditional',
          from: 'condition',
          to: 'agent',
          label: 'urgent',
        ),
      ],
    );

    final restored = ArchitectureDocument.fromJson(
      jsonDecode(original.toPrettyJson()),
    );
    final branches = restored.nodes.single.config['branches'] as List;

    expect((branches.first as Map)['condition'], 'priority == high');
    expect(restored.edges.single.label, 'urgent');
  });

  test('agent instructions and integration references persist in JSON', () {
    final agent = FlowNode(
      id: 'agent',
      type: BlockType.agent,
      position: const Offset(20, 40),
      title: 'Research agent',
      config: {
        'instructions': 'Use approved sources and cite the result.',
        'integrationRefs': ['api-source', 'mcp-source'],
      },
    );
    final restored = ArchitectureDocument.fromJson(
      jsonDecode(
        ArchitectureDocument(
          name: 'Agent references',
          nodes: [agent],
          edges: [],
        ).toPrettyJson(),
      ),
    );

    expect(
      restored.nodes.single.config['instructions'],
      'Use approved sources and cite the result.',
    );
    expect(restored.nodes.single.config['integrationRefs'], [
      'api-source',
      'mcp-source',
    ]);
  });

  testWidgets('builder renders its three main work areas', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const AgentBuilderApp());
    await tester.pumpAndSettle();

    expect(find.text('BLOCKS'), findsOneWidget);
    expect(find.text('Triage agent'), findsOneWidget);
    expect(find.text('Builder assistant'), findsOneWidget);
    expect(find.text('If / else'), findsOneWidget);
    expect(find.text('API call'), findsOneWidget);
    expect(find.text('Cloud save'), findsOneWidget);
    expect(find.text('Deploy'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Search agents'), findsOneWidget);
    expect(find.byTooltip('Connection input'), findsNWidgets(2));
    expect(find.byTooltip('Drag to connect'), findsNWidgets(2));
  });

  testWidgets('agent workspace asks signed-out users to authenticate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const AgentBuilderApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agent-workspace-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to run deployed agents'), findsOneWidget);
    expect(find.text('Back to builder'), findsOneWidget);
    expect(find.text('BLOCKS'), findsNothing);
  });

  testWidgets('side panels collapse and restore', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const AgentBuilderApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Collapse blocks'));
    await tester.pumpAndSettle();
    expect(find.text('BLOCKS'), findsNothing);
    expect(find.byTooltip('Show blocks'), findsOneWidget);

    await tester.tap(find.byTooltip('Collapse panel'));
    await tester.pumpAndSettle();
    expect(find.text('Builder assistant'), findsNothing);
    expect(find.byTooltip('Show chat and settings'), findsOneWidget);
  });

  testWidgets('clicking a connection opens removal and label controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const AgentBuilderApp());
    await tester.pumpAndSettle();

    // Midpoint of the sample connection after the left palette and top bar.
    await tester.tapAt(const Offset(544, 186));
    await tester.pumpAndSettle();

    expect(find.text('Connection settings'), findsOneWidget);
    expect(find.text('Link label'), findsOneWidget);
    expect(find.text('Remove connection'), findsOneWidget);

    await tester.tap(find.text('Remove connection'));
    await tester.pumpAndSettle();
    expect(find.text('Connection settings'), findsNothing);
  });

  testWidgets('API blocks expose endpoint and credential reference settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const AgentBuilderApp());
    await tester.pumpAndSettle();

    await tester.drag(find.text('API call'), const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(find.text('API CONFIGURATION'), findsOneWidget);
    expect(find.text('API URL'), findsOneWidget);
    expect(find.text('HTTP method'), findsOneWidget);
    expect(find.text('Token / credential reference'), findsOneWidget);

    await tester.drag(find.text('MCP tool'), const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(find.text('MCP CONFIGURATION'), findsOneWidget);
    expect(find.text('MCP server URL'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('Tool name'), findsOneWidget);

    tester
        .widget<GestureDetector>(find.byKey(const ValueKey('node-card-node-2')))
        .onTap!();
    await tester.pumpAndSettle();
    expect(find.text('AGENT CONFIGURATION'), findsOneWidget);
    expect(find.text('Agent instructions'), findsOneWidget);
    expect(find.text('REFERENCED INPUTS'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(2));

    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    final checkbox = tester.widget<CheckboxListTile>(
      find.byType(CheckboxListTile).first,
    );
    expect(checkbox.value, isTrue);
  });

  testWidgets('one output port creates consecutive connections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const AgentBuilderApp());
    await tester.pumpAndSettle();
    await tester.drag(find.text('API call'), const Offset(400, 10));
    await tester.pumpAndSettle();
    await tester.drag(find.text('MCP tool'), const Offset(440, 80));
    await tester.pumpAndSettle();

    final source = tester.getCenter(
      find.byKey(const ValueKey('output-port-node-1')),
    );
    const apiTarget = Offset(421, 431);
    await tester.dragFrom(source, apiTarget - source);
    await tester.pumpAndSettle();

    final sameSource = tester.getCenter(
      find.byKey(const ValueKey('output-port-node-1')),
    );
    const mcpTarget = Offset(461, 556);
    await tester.dragFrom(sameSource, mcpTarget - sameSource);
    await tester.pumpAndSettle();

    final jsonTab = find.text('JSON');
    await tester.ensureVisible(jsonTab);
    await tester.tap(jsonTab);
    await tester.pumpAndSettle();
    final jsonText = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((widget) => widget.data ?? '')
        .firstWhere((text) => text.contains('"edges"'));
    expect(
      RegExp('"from": "node-1"').allMatches(jsonText),
      hasLength(3),
      reason: jsonText,
    );
  });

  testWidgets('theme toggle switches to dark mode', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const AgentBuilderApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(find.byTooltip('Use light mode'), findsOneWidget);
  });
}
