import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

import '../../models/input_clear_mode.dart';
import '../../models/send_button_visibility_mode.dart';
import '../../util.dart';
import '../state/inherited_chat_theme.dart';
import '../state/inherited_l10n.dart';
import 'attachment_button.dart';
import 'input_text_field_controller.dart';
import 'send_button.dart';
import 'special_text/at_special_text_span_builder.dart';

/// A class that represents bottom bar widget with a text field, attachment and
/// send buttons inside. By default hides send button when text field is empty.
class Input extends StatefulWidget {
  /// Creates [Input] widget.
  const Input({
    super.key,
    this.isAttachmentUploading,
    this.onAttachmentPressed,
    required this.onSendPressed,
    this.options = const InputOptions(),
  });

  /// Whether attachment is uploading. Will replace attachment button with a
  /// [CircularProgressIndicator]. Since we don't have libraries for
  /// managing media in dependencies we have no way of knowing if
  /// something is uploading so you need to set this manually.
  final bool? isAttachmentUploading;

  /// See [AttachmentButton.onPressed].
  final VoidCallback? onAttachmentPressed;

  /// Will be called on [SendButton] tap. Has [types.PartialText] which can
  /// be transformed to [types.TextMessage] and added to the messages list.
  final void Function(types.PartialText) onSendPressed;

  /// Customisation options for the [Input].
  final InputOptions options;

  @override
  State<Input> createState() => _InputState();
}

/// [Input] widget state.
class _InputState extends State<Input> with WidgetsBindingObserver, RouteAware {
  late final _inputFocusNode = FocusNode(
    onKeyEvent: (node, event) {
      if (event.physicalKey == PhysicalKeyboardKey.enter &&
          !HardwareKeyboard.instance.physicalKeysPressed.any(
            (el) => <PhysicalKeyboardKey>{
              PhysicalKeyboardKey.shiftLeft,
              PhysicalKeyboardKey.shiftRight,
            }.contains(el),
          )) {
        if (event is KeyDownEvent) {
          _handleSendPressed();
        }
        return KeyEventResult.handled;
      } else {
        return KeyEventResult.ignored;
      }
    },
  );

  bool _sendButtonVisible = false;
  late TextEditingController _textController;

  OverlayEntry? atSomeoneOverlay;
  double overlayDy = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _textController = widget.options.textEditingController ?? InputTextFieldController();
    _textController.addListener(() {
      _onCursorChange(_textController.selection.baseOffset);
      widget.options.onCursorChanged?.call(_textController.selection.baseOffset);
    });

    widget.options.onControllerSet?.call(_textController);
    _handleSendButtonVisibilityModeChange();
    if (widget.options.enabledAtSomeone) {
      atSomeoneOverlay = OverlayEntry(
        builder: (context) => Positioned(
          left: 0,
          right: 0,
          bottom: overlayDy,
          child: widget.options.atSomeoneView!,
        ),
      );
      widget.options.onAtSomeoneViewCreated?.call(atSomeoneOverlay);
    }
  }

  void _handleSendButtonVisibilityModeChange() {
    _textController.removeListener(_handleTextControllerChange);
    if (widget.options.sendButtonVisibilityMode == SendButtonVisibilityMode.hidden) {
      _sendButtonVisible = false;
    } else if (widget.options.sendButtonVisibilityMode == SendButtonVisibilityMode.editing) {
      _sendButtonVisible = _textController.text.trim() != '';
      _textController.addListener(_handleTextControllerChange);
    } else {
      _sendButtonVisible = true;
    }
  }

  void _onCursorChange(int offset) {
    if (widget.options.enabledAtSomeone) {
      final renderBox = context.findRenderObject() as RenderBox;
      overlayDy = View.of(context).viewInsets.bottom / View.of(context).devicePixelRatio + renderBox.size.height;
      try {
        if (_textController.text.isEmpty) {
          removeOverlay();
          return;
        }

        if (_textController.text[offset - 1] == '@') {
          Overlay.of(context).insert(atSomeoneOverlay!);
        } else {
          removeOverlay();
        }
      } catch (_) {}
    }
  }

  void removeOverlay() {
    if (atSomeoneOverlay != null && atSomeoneOverlay?.mounted == true) {
      atSomeoneOverlay?.remove();
    }
  }

  void _handleSendPressed() {
    final trimmedText = _textController.text;
    if (trimmedText != '') {
      final partialText = types.PartialText(text: trimmedText);
      widget.onSendPressed(partialText);

      if (widget.options.inputClearMode == InputClearMode.always) {
        _textController.clear();
      }
    }
  }

  void _handleTextControllerChange() {
    setState(() {
      _sendButtonVisible = _textController.text.trim() != '';
    });
  }

  Widget _inputBuilder() {
    final query = MediaQuery.of(context);
    final buttonPadding = InheritedChatTheme.of(context).theme.inputPadding.copyWith(left: 16, right: 16);
    final safeAreaInsets = isMobile
        ? EdgeInsets.fromLTRB(
            query.padding.left,
            0,
            query.padding.right,
            query.viewInsets.bottom + query.padding.bottom,
          )
        : EdgeInsets.zero;
    final textPadding = InheritedChatTheme.of(context).theme.inputPadding.copyWith(left: 0, right: 0).add(
          EdgeInsets.fromLTRB(
            widget.onAttachmentPressed != null ? 0 : 24,
            0,
            _sendButtonVisible ? 0 : 24,
            0,
          ),
        );

    return Focus(
      autofocus: !widget.options.autofocus,
      child: Padding(
        padding: InheritedChatTheme.of(context).theme.inputMargin,
        child: Material(
          borderRadius: InheritedChatTheme.of(context).theme.inputBorderRadius,
          color: InheritedChatTheme.of(context).theme.inputBackgroundColor,
          child: Container(
            decoration: InheritedChatTheme.of(context).theme.inputContainerDecoration,
            padding: safeAreaInsets,
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                if (widget.onAttachmentPressed != null)
                  AttachmentButton(
                    isLoading: widget.isAttachmentUploading ?? false,
                    onPressed: widget.onAttachmentPressed,
                    padding: buttonPadding,
                  ),
                Expanded(
                  child: Padding(
                    padding: textPadding,
                    child: ExtendedTextField(
                      enabled: widget.options.enabled,
                      specialTextSpanBuilder: AtSpecialTextSpanBuilder(
                        atCallback: (showText, actualText) {},
                        atStyle: InheritedChatTheme.of(context).theme.inputTextStyle.copyWith(
                              color: Colors.blue,
                            ),
                        allAtMap: widget.options.atMembersMap,
                      ),
                      autocorrect: widget.options.autocorrect,
                      autofocus: widget.options.autofocus,
                      enableSuggestions: widget.options.enableSuggestions,
                      controller: _textController,
                      cursorColor: InheritedChatTheme.of(context).theme.inputTextCursorColor,
                      decoration: InheritedChatTheme.of(context).theme.inputTextDecoration.copyWith(
                            hintStyle: InheritedChatTheme.of(context).theme.inputTextStyle.copyWith(
                                  color: InheritedChatTheme.of(context).theme.inputTextColor.withOpacity(0.5),
                                ),
                            hintText: InheritedL10n.of(context).l10n.inputPlaceholder,
                          ),
                      focusNode: _inputFocusNode,
                      keyboardType: widget.options.keyboardType,
                      maxLines: 5,
                      minLines: 1,
                      onChanged: widget.options.onTextChanged,
                      onTap: widget.options.onTextFieldTap,
                      style: InheritedChatTheme.of(context).theme.inputTextStyle.copyWith(
                            color: InheritedChatTheme.of(context).theme.inputTextColor,
                          ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: buttonPadding.bottom + buttonPadding.top + 24,
                  ),
                  child: Visibility(
                    visible: _sendButtonVisible,
                    child: SendButton(
                      onPressed: _handleSendPressed,
                      padding: buttonPadding,
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

  @override
  void didUpdateWidget(covariant Input oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.options.sendButtonVisibilityMode != oldWidget.options.sendButtonVisibilityMode) {
      _handleSendButtonVisibilityModeChange();
    }
  }

  @override
  void dispose() {
    _inputFocusNode.dispose();
    _textController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    widget.options.routeObserver?.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPop() {
    removeOverlay();
  }

  @override
  void didPushNext() {
    FocusScope.of(context).unfocus();
    removeOverlay();
  }

  @override
  void didChangeDependencies() {
    widget.options.routeObserver?.subscribe(this, ModalRoute.of(context) as PageRoute);

    super.didChangeDependencies();
  }

  @override
  void didChangeMetrics() {
    if (atSomeoneOverlay != null && widget.options.enabledAtSomeone) {
      final renderBox = context.findRenderObject() as RenderBox;
      overlayDy = View.of(context).viewInsets.bottom / View.of(context).devicePixelRatio + renderBox.size.height;
      atSomeoneOverlay!.markNeedsBuild();
    }
    super.didChangeMetrics();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => _inputFocusNode.requestFocus(),
        child: _inputBuilder(),
      );
}

@immutable
class InputOptions {
  const InputOptions({
    this.inputClearMode = InputClearMode.always,
    this.keyboardType = TextInputType.multiline,
    this.onTextChanged,
    this.onTextFieldTap,
    this.sendButtonVisibilityMode = SendButtonVisibilityMode.editing,
    this.textEditingController,
    this.autocorrect = true,
    this.autofocus = false,
    this.enableSuggestions = true,
    this.enabled = true,
    this.enabledAtSomeone = true,
    this.routeObserver,
    this.atSomeoneView,
    this.onAtSomeoneViewCreated,
    this.onControllerSet,
    this.onCursorChanged,
    this.atMembersMap = const {},
  });

  /// Controls the [Input] clear behavior. Defaults to [InputClearMode.always].
  final InputClearMode inputClearMode;

  /// Controls the [Input] keyboard type. Defaults to [TextInputType.multiline].
  final TextInputType keyboardType;

  /// Will be called whenever the text inside [TextField] changes.
  final void Function(String)? onTextChanged;

  final void Function(int)? onCursorChanged;

  /// Will be called on [TextField] tap.
  final VoidCallback? onTextFieldTap;

  /// Controls the visibility behavior of the [SendButton] based on the
  /// [TextField] state inside the [Input] widget.
  /// Defaults to [SendButtonVisibilityMode.editing].
  final SendButtonVisibilityMode sendButtonVisibilityMode;

  /// Custom [TextEditingController]. If not provided, defaults to the
  /// [InputTextFieldController], which extends [TextEditingController] and has
  /// additional fatures like markdown support. If you want to keep additional
  /// features but still need some methods from the default [TextEditingController],
  /// you can create your own [InputTextFieldController] (imported from this lib)
  /// and pass it here.
  final TextEditingController? textEditingController;

  /// Controls the [TextInput] autocorrect behavior. Defaults to [true].
  final bool autocorrect;

  /// Whether [TextInput] should have focus. Defaults to [false].
  final bool autofocus;

  /// Controls the [TextInput] enableSuggestions behavior. Defaults to [true].
  final bool enableSuggestions;

  /// Controls the [TextInput] enabled behavior. Defaults to [true].
  final bool enabled;

  final bool enabledAtSomeone;

  final RouteObserver? routeObserver;

  final Widget? atSomeoneView;

  final Function(OverlayEntry? overlayEntry)? onAtSomeoneViewCreated;

  final Function(TextEditingController textEditingController)? onControllerSet;

  final Map<String, String> atMembersMap;
}
