import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart' hide Key, AbstractNode;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' hide Key;
import 'package:flutter_render/my_render/my_key.dart';
import 'package:flutter_render/my_render/my_node.dart';

///    author : linchenpeng
///    date   : 2020/6/18 9:37 AM
///    desc   :

/// Widget
@immutable
abstract class Widget {
  const Widget({this.key});

  final Key key;

  @protected
  Element createElement();

  @override
  bool operator ==(Object other) => super == other;

  @override
  int get hashCode => super.hashCode;

  static bool canUpdate(Widget oldWidget, Widget newWidget) {
    return oldWidget.runtimeType == newWidget.runtimeType &&
        oldWidget.key == newWidget.key;
  }
}

/// ProxyWidget
abstract class ProxyWidget extends Widget {
  const ProxyWidget({Key key, @required this.child}) : super(key: key);
  final Widget child;
}

/// ParentDataWidget
abstract class ParentDataWidget<T extends ParentData> extends ProxyWidget {
  const ParentDataWidget({Key key, Widget child})
      : super(key: key, child: child);

  @override
  ParentDataElement<T> createElement() => ParentDataElement<T>(this);

  @protected
  void applyParentData(RenderObject renderObject);

  @protected
  bool debugCanApplyOutOfTurn() => false;
}

/// InheritedWidget
abstract class InheritedWidget extends ProxyWidget {
  const InheritedWidget({Key key, Widget child})
      : super(key: key, child: child);

  @override
  InheritedElement createElement() => InheritedElement(this);

  @protected
  bool updateShouldNotify(covariant InheritedWidget oldWidget);
}

/// RenderObjectWidget
abstract class RenderObjectWidget extends Widget {
  const RenderObjectWidget({Key key}) : super(key: key);

  @override
  @factory
  RenderObjectElement createElement();

  @protected
  @factory
  RenderObject createRenderObject(BuildContext context);

  @protected
  void updateRenderObject(
      BuildContext context, covariant RenderObject renderObject);

  @protected
  void didUnmountRenderObject(covariant RenderObject renderObject) {}
}

/// StatelessWidget
abstract class StatelessWidget extends Widget {
  const StatelessWidget({Key key}) : super(key: key);

  @override
  StatelessElement createElement() => StatelessElement(this);

  @protected
  Widget build(BuildContext context);
}

/// StatefulWidget
abstract class StatefulWidget extends Widget {
  const StatefulWidget({Key key}) : super(key: key);

  @override
  StatefulElement createElement() => StatefulElement(this);

  @protected
  State createState();
}

typedef StateSetter = void Function(VoidCallback fn);

/// State
@optionalTypeArgs
abstract class State<T extends StatefulWidget> {
  T get widget => _widget;
  T _widget;

  BuildContext get context => _element;
  StatefulElement _element;

  bool get mounted => _element != null;

  @protected
  @mustCallSuper
  void initState() {}

  @mustCallSuper
  @protected
  void didUpdateWidget(covariant T oldWidget) {}

  @mustCallSuper
  @protected
  void reassemble() {}

  @protected
  void setState(VoidCallback fn) {
    final dynamic result = fn() as dynamic;
    _element.markNeedsBuild();
  }

  @mustCallSuper
  @protected
  void deactivate() {}

  @mustCallSuper
  @protected
  void dispose() {}

  @protected
  Widget build(BuildContext context);

  @mustCallSuper
  @protected
  void didChangeDependencies() {}
}

/// Element
abstract class Element implements BuildContext {
  Element(Widget widget) : _widget = widget;

  Element _parent;

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => _cachedHash;
  final int _cachedHash = _nextHashCode = (_nextHashCode + 1) % 0xffffff;
  static int _nextHashCode = 1;

  dynamic get slot => _slot;
  dynamic _slot;

  int get depth => _depth;
  int _depth;

  static int _sort(Element a, Element b) {
    if (a.depth < b.depth) {
      return -1;
    }
    if (b.depth < a.depth) {
      return 1;
    }

    if (b.dirty && !a.dirty) {
      return -1;
    }

    if (a.dirty && !b.dirty) {
      return 1;
    }
    return 0;
  }

  @override
  Widget get widget => _widget;
  Widget _widget;

  @override
  BuildOwner get owner => _owner;
  BuildOwner _owner;

  bool _active = false;

  @mustCallSuper
  @protected
  void reassemble() {
    markNeedsBuild();
    visitChildren((Element child) {
      child.reassemble();
    });
  }

  RenderObject get renderObject {
    RenderObject result;
    void visit(Element element) {
      if (element is RenderObjectElement) {
        result = element.renderObject;
      } else {
        element.visitChildren(visit);
      }
    }

    visit(this);
    return result;
  }

  void visitChildren(ElementVisitor visitor) {}

  @override
  void visitChildElements(ElementVisitor visitor) {
    visitChildren(visitor);
  }

  @protected
  Element updateChild(Element child, Widget newWidget, dynamic newSlot) {
    if (newWidget == null) {
      if (child != null) {
        deactivateChild(child);
      }
      return null;
    }

    Element newChild;
    if (child != null) {
      bool hasSameSuperclass = true;
      if (hasSameSuperclass && child.widget == newWidget) {
        if (child.slot != newSlot) {
          updateSlotForChild(child, newSlot);
        }
        newChild = child;
      } else if (hasSameSuperclass &&
          Widget.canUpdate(child.widget, newWidget)) {
        if (child.slot != newSlot) {
          updateSlotForChild(child, newSlot);
        }
        child.update(newWidget);
        newChild = child;
      } else {
        deactivateChild(child);
        newChild = inflateWidget(newWidget, newSlot);
      }
    } else {
      newChild = inflateWidget(newWidget, newSlot);
    }

    return newChild;
  }

  @mustCallSuper
  void mount(Element parent, dynamic newSlot) {
    _parent = parent;
    _slot = newSlot;

    /// 根节点的深度是1
    _depth = _parent != null ? _parent.depth + 1 : 1;
    _active = true;
    if (parent != null) {
      _owner = parent.owner;
    }
    final Key key = widget.key;
    if (key is GlobalKey) {
      key._register(this);
    }
    _updateInheritance();
  }

  @mustCallSuper
  void update(covariant Widget newWidget) {
    _widget = newWidget;
  }

  @protected
  void updateSlotForChild(Element child, dynamic newSlot) {
    void visit(Element element) {
      element._updateSlot(newSlot);
      if (element is! RenderObjectElement) {
        element.visitChildren(visit);
      }
    }

    visit(child);
  }

  void _updateSlot(dynamic newSlot) {
    _slot = newSlot;
  }

  void _updateDepth(int parentDepth) {
    final int expectedDepth = parentDepth + 1;
    if (_depth < expectedDepth) {
      _depth = expectedDepth;
      visitChildren((Element child) {
        child._updateDepth(expectedDepth);
      });
    }
  }

  void detachRenderObject() {
    visitChildren((Element child) {
      child.detachRenderObject();
    });
    _slot = null;
  }

  void attachRenderObject(dynamic newSlot) {
    visitChildren((Element child) {
      child.attachRenderObject(newSlot);
    });
    _slot = newSlot;
  }

  Element _retakeInactiveElement(GlobalKey key, Widget newWidget) {
    final Element element = key._currentElement;
    if (element == null) {
      return null;
    }
    if (!Widget.canUpdate(element.widget, newWidget)) {
      return null;
    }

    final Element parent = element._parent;
    if (parent != null) {
      parent.forgetChild(element);
      parent.deactivateChild(element);
    }

    owner._inactiveElements.remove(element);
    return element;
  }

  @protected
  Element inflateWidget(Widget newWidget, dynamic newSlot) {
    final Key key = newWidget.key;

    if (key is GlobalKey) {
      final Element newChild = _retakeInactiveElement(key, newWidget);
      if (newChild != null) {
        newChild._activateWithParent(this, newSlot);
        final Element updatedChild = updateChild(newChild, newWidget, newSlot);
        return updatedChild;
      }
    }

    final Element newChild = newWidget.createElement();
    newChild.mount(this, newSlot);
    return newChild;
  }

  @protected
  void deactivateChild(Element child) {
    child._parent = null;
    child.detachRenderObject();
    owner._inactiveElements.add(child);
  }

  @protected
  @mustCallSuper
  void forgetChild(Element child) {}

  void _activateWithParent(Element parent, dynamic newSlot) {
    _parent = parent;
    _updateDepth(_parent.depth);
    _activateRecursively(this);
    attachRenderObject(newSlot);
  }

  static void _activateRecursively(Element element) {
    element.activate();
    element.visitChildren(_activateRecursively);
  }

  @mustCallSuper
  void activate() {
    final bool hadDependencies =
        (_dependencies != null && _dependencies.isNotEmpty) ||
            _hadUnsatisfiedDependencies;
    _active = true;
    _dependencies?.clear();
    _hadUnsatisfiedDependencies = false;
    _updateInheritance();

    if (_dirty) {
      owner.scheduleBuildFor(this);
    }
    if (hadDependencies) {
      didChangeDependencies();
    }
  }

  @mustCallSuper
  void deactivate() {
    if (_dependencies != null && _dependencies.isNotEmpty) {
      for (final InheritedElement dependency in _dependencies) {
        dependency._dependents.remove(this);
      }
    }
    _inheritedWidgets = null;
    _active = false;
  }

  @mustCallSuper
  void unmount() {
    final Key key = _widget.key;
    if (key is GlobalKey) {
      key._unregister(this);
    }
  }

  @override
  RenderObject findRenderObject() => renderObject;

  @override
  Size get size {
    final RenderObject renderObject = findRenderObject();
    if (renderObject is RenderBox) {
      return renderObject.size;
    }
    return null;
  }

  Map<Type, InheritedElement> _inheritedWidgets;
  Set<InheritedElement> _dependencies;
  bool _hadUnsatisfiedDependencies = false;

  @override
  InheritedWidget dependOnInheritedElement(InheritedElement ancestor,
      {Object aspect}) {
    _dependencies ??= HashSet<InheritedElement>();
    _dependencies.add(ancestor);
    ancestor.updateDependencies(this, aspect);
    return ancestor.widget;
  }

  @override
  T dependOnInheritedWidgetOfExactType<T extends InheritedWidget>(
      {Object aspect}) {
    final InheritedElement ancestor =
        _inheritedWidgets == null ? null : _inheritedWidgets[T];

    if (ancestor != null) {
      return dependOnInheritedElement(ancestor);
    }
    _hadUnsatisfiedDependencies = true;
    return null;
  }

  @override
  InheritedElement
      getElementForInheritedWidgetOfExactType<T extends InheritedWidget>() {
    final InheritedElement ancestor =
        _inheritedWidgets == null ? null : _inheritedWidgets[T];
    return ancestor;
  }

  void _updateInheritance() {
    _inheritedWidgets = _parent?._inheritedWidgets;
  }

  @override
  T findAncestorWidgetOfExactType<T extends Widget>() {
    Element ancestor = _parent;
    while (ancestor != null && ancestor.widget.runtimeType != T) {
      ancestor = ancestor._parent;
    }
    return ancestor?.widget as T;
  }

  /// 找到最靠近的State
  @override
  T findAncestorStateOfType<T extends State>() {
    Element ancestor = _parent;
    while (ancestor != null) {
      if (ancestor is StatefulElement && ancestor.state is T) {
        break;
      }
      ancestor = ancestor._parent;
    }

    final StatefulElement statefulElement = ancestor as StatefulElement;
    return statefulElement?.state as T;
  }

  /// 找到最顶层的State
  @override
  T findRootAncestorStateOfType<T extends State>() {
    Element ancestor = _parent;
    StatefulElement statefulAncestor;
    while (ancestor != null) {
      if (ancestor is StatefulElement && ancestor.state is T) {
        statefulAncestor = ancestor;
      }
      ancestor = ancestor._parent;
    }
    return statefulAncestor?.state as T;
  }

  @override
  T findAncestorRenderObjectOfType<T extends RenderObject>() {
    Element ancestor = _parent;
    while (ancestor != null) {
      if (ancestor is RenderObjectElement && ancestor.renderObject is T) {
        return ancestor.renderObject as T;
      }
      ancestor = ancestor._parent;
    }
    return null;
  }

  @override
  void visitAncestorElements(bool visitor(Element element)) {
    Element ancestor = _parent;
    while (ancestor != null && visitor(ancestor)) {
      ancestor = ancestor._parent;
    }
  }

  @mustCallSuper
  void didChangeDependencies() {
    markNeedsBuild();
  }

  bool get dirty => _dirty;
  bool _dirty = true;

  bool _inDirtyList = false;

  void markNeedsBuild() {
    if (!_active) {
      return;
    }
    if (dirty) {
      return;
    }

    _dirty = true;
    owner.scheduleBuildFor(this);
  }

  void rebuild() {
    if (!_active || !_dirty) {
      return;
    }

    performRebuild();
  }

  @protected
  void performRebuild();
}

/// ComponentElement
abstract class ComponentElement extends Element {
  ComponentElement(Widget widget) : super(widget);

  Element _child;

  @override
  void mount(Element parent, newSlot) {
    super.mount(parent, newSlot);
    _firstBuild();
  }

  void _firstBuild() {
    rebuild();
  }

  @override
  void performRebuild() {
    Widget built;
    built = build();
    _dirty = false;

    _child = updateChild(_child, built, slot);
  }

  @protected
  Widget build();

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_child != null) {
      visitor(_child);
    }
  }

  @override
  void forgetChild(Element child) {
    _child = null;
    super.forgetChild(child);
  }
}

/// ProxyElement
abstract class ProxyElement extends ComponentElement {
  ProxyElement(ProxyWidget widget) : super(widget);

  @override
  ProxyWidget get widget => super.widget as ProxyWidget;

  @override
  Widget build() => widget.child;

  @override
  void update(Widget newWidget) {
    final ProxyWidget oldWidget = widget;
    super.update(newWidget);
    updated(oldWidget);
    _dirty = true;
    rebuild();
  }

  @protected
  void updated(covariant ProxyWidget oldWidget) {
    notifyClients(oldWidget);
  }

  @protected
  void notifyClients(covariant ProxyWidget oldWidget);
}

/// InheritedElement
class InheritedElement extends ProxyElement {
  InheritedElement(InheritedWidget widget) : super(widget);

  @override
  InheritedWidget get widget => super.widget as InheritedWidget;

  final Map<Element, Object> _dependents = HashMap<Element, Object>();

  @override
  void _updateInheritance() {
    final Map<Type, InheritedElement> incomingWidgets =
        _parent?._inheritedWidgets;
    if (incomingWidgets != null) {
      _inheritedWidgets = HashMap<Type, InheritedElement>.from(incomingWidgets);
    } else {
      _inheritedWidgets = HashMap<Type, InheritedElement>();
    }
    _inheritedWidgets[widget.runtimeType] = this;
  }

  @protected
  Object getDependencies(Element dependent) {
    return _dependents[dependent];
  }

  @protected
  void setDependencies(Element dependent, Object value) {
    _dependents[dependent] = value;
  }

  @protected
  void updateDependencies(Element dependent, Object aspect) {
    setDependencies(dependent, null);
  }

  @protected
  void notifyDependent(covariant InheritedWidget oldWidget, Element dependent) {
    dependent.didChangeDependencies();
  }

  @override
  void updated(InheritedWidget oldWidget) {
    if (widget.updateShouldNotify(oldWidget)) {
      super.updated(oldWidget);
    }
  }

  @override
  void notifyClients(InheritedWidget oldWidget) {
    for (final Element dependent in _dependents.keys) {
      notifyDependent(oldWidget, dependent);
    }
  }
}

/// RenderObjectElement
abstract class RenderObjectElement extends Element {
  RenderObjectElement(RenderObjectWidget widget) : super(widget);

  @override
  RenderObjectWidget get widget => super.widget as RenderObjectWidget;

  @override
  RenderObject get renderObject => _renderObject;
  RenderObject _renderObject;

  RenderObjectElement _ancestorRenderObjectElement;

  RenderObjectElement _findAncestorRenderObjectElement() {
    Element ancestor = _parent;
    while (ancestor != null && ancestor is! RenderObjectElement) {
      ancestor = ancestor._parent;
    }
    return ancestor as RenderObjectElement;
  }

  ParentDataElement<ParentData> _findAncesotrParentDataElement() {
    Element ancestor = _parent;
    ParentDataElement<ParentData> result;
    while (ancestor != null && ancestor is! RenderObjectElement) {
      if (ancestor is ParentDataElement<ParentData>) {
        result = ancestor as ParentDataElement<ParentData>;
        break;
      }
      ancestor = ancestor._parent;
    }
    return result;
  }

  @override
  void mount(Element parent, newSlot) {
    super.mount(parent, newSlot);
    _renderObject = widget.createRenderObject(this);

    attachRenderObject(newSlot);
    _dirty = false;
  }

  @override
  void update(covariant RenderObjectWidget newWidget) {
    super.update(newWidget);

    widget.updateRenderObject(this, renderObject);
    _dirty = false;
  }

  @override
  void performRebuild() {
    widget.updateRenderObject(this, renderObject);
    _dirty = false;
  }

  @protected
  List<Element> updateChildren(
      List<Element> oldChildren, List<Widget> newWidgets,
      {Set<Element> forgottenChildren}) {
    Element replaceWithNullIfForgotten(Element child) {
      return forgottenChildren != null && forgottenChildren.contains(child)
          ? null
          : child;
    }

    // This attempts to diff the new child list (newWidgets) with
    // the old child list (oldChildren), and produce a new list of elements to
    // be the new list of child elements of this element. The called of this
    // method is expected to update this render object accordingly.

    // The cases it tries to optimize for are:
    //  - the old list is empty
    //  - the lists are identical
    //  - there is an insertion or removal of one or more widgets in
    //    only one place in the list
    // If a widget with a key is in both lists, it will be synced.
    // Widgets without keys might be synced but there is no guarantee.

    // The general approach is to sync the entire new list backwards, as follows:
    // 1. Walk the lists from the top, syncing nodes, until you no longer have
    //    matching nodes.
    // 2. Walk the lists from the bottom, without syncing nodes, until you no
    //    longer have matching nodes. We'll sync these nodes at the end. We
    //    don't sync them now because we want to sync all the nodes in order
    //    from beginning to end.
    // At this point we narrowed the old and new lists to the point
    // where the nodes no longer match.
    // 3. Walk the narrowed part of the old list to get the list of
    //    keys and sync null with non-keyed items.
    // 4. Walk the narrowed part of the new list forwards:
    //     * Sync non-keyed items with null
    //     * Sync keyed items with the source if it exists, else with null.
    // 5. Walk the bottom of the list again, syncing the nodes.
    // 6. Sync null with any items in the list of keys that are still
    //    mounted.

    int newChildrenTop = 0;
    int oldChildrenTop = 0;
    int newChildrenBottom = newWidgets.length - 1;
    int oldChildrenBottom = oldChildren.length - 1;

    final List<Element> newChildren = oldChildren.length == newWidgets.length
        ? oldChildren
        : List<Element>(newWidgets.length);

    Element previousChild;

    // Update the top of the list.
    while ((oldChildrenTop <= oldChildrenBottom) &&
        (newChildrenTop <= newChildrenBottom)) {
      final Element oldChild =
          replaceWithNullIfForgotten(oldChildren[oldChildrenTop]);
      final Widget newWidget = newWidgets[newChildrenTop];
      if (oldChild == null || !Widget.canUpdate(oldChild.widget, newWidget))
        break;
      final Element newChild = updateChild(oldChild, newWidget,
          IndexedSlot<Element>(newChildrenTop, previousChild));
      newChildren[newChildrenTop] = newChild;
      previousChild = newChild;
      newChildrenTop += 1;
      oldChildrenTop += 1;
    }

    // Scan the bottom of the list.
    while ((oldChildrenTop <= oldChildrenBottom) &&
        (newChildrenTop <= newChildrenBottom)) {
      final Element oldChild =
          replaceWithNullIfForgotten(oldChildren[oldChildrenBottom]);
      final Widget newWidget = newWidgets[newChildrenBottom];
      if (oldChild == null || !Widget.canUpdate(oldChild.widget, newWidget))
        break;
      oldChildrenBottom -= 1;
      newChildrenBottom -= 1;
    }

    // Scan the old children in the middle of the list.
    final bool haveOldChildren = oldChildrenTop <= oldChildrenBottom;
    Map<Key, Element> oldKeyedChildren;
    if (haveOldChildren) {
      oldKeyedChildren = <Key, Element>{};
      while (oldChildrenTop <= oldChildrenBottom) {
        final Element oldChild =
            replaceWithNullIfForgotten(oldChildren[oldChildrenTop]);
        if (oldChild != null) {
          if (oldChild.widget.key != null)
            oldKeyedChildren[oldChild.widget.key] = oldChild;
          else
            deactivateChild(oldChild);
        }
        oldChildrenTop += 1;
      }
    }

    // Update the middle of the list.
    while (newChildrenTop <= newChildrenBottom) {
      Element oldChild;
      final Widget newWidget = newWidgets[newChildrenTop];
      if (haveOldChildren) {
        final Key key = newWidget.key;
        if (key != null) {
          oldChild = oldKeyedChildren[key];
          if (oldChild != null) {
            if (Widget.canUpdate(oldChild.widget, newWidget)) {
              // we found a match!
              // remove it from oldKeyedChildren so we don't unsync it later
              oldKeyedChildren.remove(key);
            } else {
              // Not a match, let's pretend we didn't see it for now.
              oldChild = null;
            }
          }
        }
      }
      final Element newChild = updateChild(oldChild, newWidget,
          IndexedSlot<Element>(newChildrenTop, previousChild));
      newChildren[newChildrenTop] = newChild;
      previousChild = newChild;
      newChildrenTop += 1;
    }

    // We've scanned the whole list.
    newChildrenBottom = newWidgets.length - 1;
    oldChildrenBottom = oldChildren.length - 1;

    // Update the bottom of the list.
    while ((oldChildrenTop <= oldChildrenBottom) &&
        (newChildrenTop <= newChildrenBottom)) {
      final Element oldChild = oldChildren[oldChildrenTop];
      final Widget newWidget = newWidgets[newChildrenTop];
      final Element newChild = updateChild(oldChild, newWidget,
          IndexedSlot<Element>(newChildrenTop, previousChild));
      newChildren[newChildrenTop] = newChild;
      previousChild = newChild;
      newChildrenTop += 1;
      oldChildrenTop += 1;
    }

    // Clean up any of the remaining middle nodes from the old list.
    if (haveOldChildren && oldKeyedChildren.isNotEmpty) {
      for (final Element oldChild in oldKeyedChildren.values) {
        if (forgottenChildren == null || !forgottenChildren.contains(oldChild))
          deactivateChild(oldChild);
      }
    }

    return newChildren;
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  void unmount() {
    super.unmount();
    widget.didUnmountRenderObject(renderObject);
  }

  void _updateParentData(ParentDataWidget<ParentData> parentDataWidget) {
    parentDataWidget.applyParentData(renderObject);
  }

  @override
  void _updateSlot(newSlot) {
    super._updateSlot(newSlot);
    _ancestorRenderObjectElement.moveChildRenderObject(renderObject, slot);
  }

  @override
  void attachRenderObject(dynamic newSlot) {
    _slot = newSlot;
    _ancestorRenderObjectElement = _findAncestorRenderObjectElement();
    _ancestorRenderObjectElement?.insertChildRenderObject(
        renderObject, newSlot);
    final ParentDataElement<ParentData> parentDataElement =
        _findAncesotrParentDataElement();
    if (parentDataElement != null) {
      _updateParentData(parentDataElement.widget);
    }
  }

  @override
  void detachRenderObject() {
    if (_ancestorRenderObjectElement != null) {
      _ancestorRenderObjectElement.removeChildRenderObject(renderObject);
      _ancestorRenderObjectElement = null;
    }
    _slot = null;
  }

  @protected
  void insertChildRenderObject(
      covariant RenderObject child, covariant dynamic slot);

  @protected
  void moveChildRenderObject(
      covariant RenderObject child, covariant dynamic slot);

  @protected
  void removeChildRenderObject(covariant RenderObject child);
}

@immutable
class IndexedSlot<T> {
  /// Creates an [IndexedSlot] with the provided [index] and slot [value].
  const IndexedSlot(this.index, this.value);

  /// Information to define where the child occupying this slot fits in its
  /// parent's child list.
  final T value;

  /// The index of this slot in the parent's child list.
  final int index;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is IndexedSlot && index == other.index && value == other.value;
  }

  @override
  int get hashCode => hashValues(index, value);
}

/// ParentDataElement
class ParentDataElement<T extends ParentData> extends ProxyElement {
  ParentDataElement(ParentDataWidget<T> widget) : super(widget);

  @override
  ParentDataWidget get widget => super.widget as ParentDataWidget<T>;

  void _applyParentData(ParentDataWidget<T> widget) {
    void applyParentDataToChild(Element child) {
      if (child is RenderObjectElement) {
        child._updateParentData(widget);
      } else {
        child.visitChildren(applyParentDataToChild);
      }
    }

    visitChildren(applyParentDataToChild);
  }

  void applyWidgetOutOfTurn(ParentDataWidget<T> newWidget) {
    _applyParentData(newWidget);
  }

  @override
  void notifyClients(ParentDataWidget<T> oldWidget) {
    _applyParentData(widget);
  }
}

class ParentData {
  @protected
  @mustCallSuper
  void detach() {}

  @override
  String toString() => '<none>';
}

/// StatelessElement
class StatelessElement extends ComponentElement {
  StatelessElement(Widget widget) : super(widget);

  @override
  StatelessWidget get widget => super.widget as StatelessWidget;

  @override
  Widget build() => widget.build(this);

  @override
  void update(Widget newWidget) {
    super.update(newWidget);
    _dirty = true;
    rebuild();
  }
}

/// StatefulElement
class StatefulElement extends ComponentElement {
  StatefulElement(StatefulWidget widget)
      : _state = widget.createState(),
        super(widget) {
    _state._element = this;
    _state._widget = widget;
  }

  @override
  Widget build() => _state.build(this);

  State<StatefulWidget> get state => _state;
  State<StatefulWidget> _state;

  @override
  void reassemble() {
    state.reassemble();
    super.reassemble();
  }

  @override
  void _firstBuild() {
    _state.initState();
    _state.didChangeDependencies();
    super._firstBuild();
  }

  @override
  void performRebuild() {
    if (_didChangeDependencies) {
      _state.didChangeDependencies();
      _didChangeDependencies = false;
    }
    super.performRebuild();
  }

  @override
  void update(StatefulWidget newWidget) {
    super.update(newWidget);
    final StatefulWidget oldWidget = _state.widget;

    _dirty = true;
    _state._widget = widget as StatefulWidget;

    _state.didUpdateWidget(oldWidget);
    rebuild();
  }

  @override
  void activate() {
    super.activate();
    markNeedsBuild();
  }

  @override
  void deactivate() {
    _state.deactivate();
    super.deactivate();
  }

  @override
  void unmount() {
    super.unmount();
    _state.dispose();
    _state._element = null;
    _state = null;
  }

  @override
  InheritedWidget dependOnInheritedElement(Element ancestor, {Object aspect}) {
    return super
        .dependOnInheritedElement(ancestor as InheritedElement, aspect: aspect);
  }

  bool _didChangeDependencies = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _didChangeDependencies = true;
  }
}

/// RenderObject
abstract class RenderObject {
  Size get size;
}
typedef RenderObjectVisitor = void Function(RenderObject child);

/// RenderBox
abstract class RenderBox extends RenderObject {}

/// BuildContext
abstract class BuildContext {
  Widget get widget;

  BuildOwner get owner;

  RenderObject findRenderObject();

  Size get size;

  InheritedWidget dependOnInheritedElement(InheritedElement ancestor,
      {Object aspect});

  T dependOnInheritedWidgetOfExactType<T extends InheritedWidget>(
      {Object aspect});

  InheritedElement
      getElementForInheritedWidgetOfExactType<T extends InheritedWidget>();

  T findAncestorWidgetOfExactType<T extends Widget>();

  T findAncestorStateOfType<T extends State>();

  T findRootAncestorStateOfType<T extends State>();

  T findAncestorRenderObjectOfType<T extends RenderObject>();

  void visitAncestorElements(bool visitor(Element element));

  void visitChildElements(ElementVisitor visitor);
}

typedef ElementVisitor = void Function(Element element);

/// BuildOwner
class BuildOwner {
  BuildOwner({this.onBuildScheduled});

  VoidCallback onBuildScheduled;

  final _InactiveElements _inactiveElements = _InactiveElements();

  final List<Element> _dirtyElements = <Element>[];
  bool _scheduledFlushDirtyElements = false;

  bool _dirtyElementsNeedsResorting;

  FocusManager focusManager = FocusManager();

  void scheduleBuildFor(Element element) {
    if (element._inDirtyList) {
      _dirtyElementsNeedsResorting = true;
      return;
    }

    if (!_scheduledFlushDirtyElements && onBuildScheduled != null) {
      _scheduledFlushDirtyElements = true;
      onBuildScheduled();
    }

    _dirtyElements.add(element);
    element._inDirtyList = true;
  }

  void lockState(void callback()) {
    callback();
  }

  void buildScope(Element context, [VoidCallback callback]) {
    if (callback == null && _dirtyElements.isEmpty) {
      return;
    }

    try {
      _scheduledFlushDirtyElements = true;
      if (callback != null) {
        _dirtyElementsNeedsResorting = true;
        callback();
      }

      _dirtyElements.sort(Element._sort);
      _dirtyElementsNeedsResorting = false;
      int dirtyCount = _dirtyElements.length;
      int index = 0;
      while (index < dirtyCount) {
        _dirtyElements[index].rebuild();
        index += 1;
        if (dirtyCount < _dirtyElements.length ||
            _dirtyElementsNeedsResorting) {
          _dirtyElements.sort(Element._sort);
          _dirtyElementsNeedsResorting = false;
          dirtyCount = _dirtyElements.length;
          while (index > 0 && _dirtyElements[index - 1].dirty) {
            // It is possible for previously dirty but inactive widgets to move right in the list.
            // We therefore have to move the index left in the list to account for this.
            // We don't know how many could have moved. However, we do know that the only possible
            // change to the list is that nodes that were previously to the left of the index have
            // now moved to be to the right of the right-most cleaned node, and we do know that
            // all the clean nodes were to the left of the index. So we move the index left
            // until just after the right-most clean node.
            index -= 1;
          }
        }
      }
    } finally {
      for (final Element element in _dirtyElements) {
        element._inDirtyList = false;
      }

      _dirtyElements.clear();
      _scheduledFlushDirtyElements = false;
      _dirtyElementsNeedsResorting = null;
    }
  }

  void finalizeTree() {
    lockState(() {
      _inactiveElements._unmountAll();
    });
  }

  void reassemble(Element root) {
    root.reassemble();
  }
}

/// _ElementLifecycle
enum _ElementLifecycle {
  initial,
  active,
  inactive,
  defunct,
}

/// _InactiveElements
class _InactiveElements {
  final Set<Element> _elements = HashSet<Element>();

  void _unmount(Element element) {
    element.visitChildren((Element child) {
      _unmount(child);
    });
    element.unmount();
  }

  void _unmountAll() {
    final List<Element> elements = _elements.toList()..sort(Element._sort);
    _elements.clear();
    elements.reversed.forEach(_unmount);
  }

  static void _deactiveRecursively(Element element) {
    element.deactivate();
    element.visitChildren(_deactiveRecursively);
  }

  void add(Element element) {
    if (element._active) {
      _deactiveRecursively(element);
    }
    _elements.add(element);
  }

  void remove(Element element) {
    _elements.remove(element);
  }
}

/// GlobalKey
@optionalTypeArgs
abstract class GlobalKey<T extends State<StatefulWidget>> extends Key {
  factory GlobalKey({String debugLevel}) => LabeledGlobalKey<T>(debugLevel);

  const GlobalKey.constructor() : super.empty();

  static final Map<GlobalKey, Element> _registry = <GlobalKey, Element>{};

  void _register(Element element) {
    _registry[this] = element;
  }

  void _unregister(Element element) {
    if (_registry[this] == element) {
      _registry.remove(this);
    }
  }

  Element get _currentElement => _registry[this];

  BuildContext get currentContext => _currentElement;

  Widget get currentWidget => _currentElement?.widget;

  T get currentState {
    final Element element = _currentElement;
    if (element is StatefulElement) {
      final StatefulElement statefulElement = element;
      final State state = statefulElement.state;
      if (state is T) {
        return state;
      }
    }
    return null;
  }
}

@optionalTypeArgs
class LabeledGlobalKey<T extends State<StatefulWidget>> extends GlobalKey<T> {
  LabeledGlobalKey(this._debugLevel) : super.constructor();

  final String _debugLevel;

  @override
  String toString() {
    final String label = _debugLevel != null ? ' $_debugLevel' : '';
    if (runtimeType == LabeledGlobalKey) {
      return '[GlobalKey#${shortHash(this)}$label]';
    }
    return '[${describeIdentity(this)}$label]';
  }
}
