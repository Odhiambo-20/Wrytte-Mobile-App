import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'dart:async';
import 'dart:math' as math;

class MessageInputField extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isReplying;
  final VoidCallback onAttachmentPressed;
  final VoidCallback onEmojiPressed;
  final VoidCallback onVoiceNotePressed;
  final bool showEmojiPicker;
  final bool showVoiceRecorder;
  final bool isEditing;
  final VoidCallback onSaveEdit;
  final VoidCallback onCancelEdit;

  const MessageInputField({
    super.key,
    required this.controller,
    required this.onSend,
    required this.isReplying,
    required this.onAttachmentPressed,
    required this.onEmojiPressed,
    required this.onVoiceNotePressed,
    this.showEmojiPicker = false,
    this.showVoiceRecorder = false,
    this.isEditing = false,
    required this.onSaveEdit,
    required this.onCancelEdit,
  });

  @override
  State<MessageInputField> createState() => _MessageInputFieldState();
}

class _MessageInputFieldState extends State<MessageInputField>
    with TickerProviderStateMixin {
  bool _hasText = false;
  bool _emojiPickerOpen = false;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  double _textFieldHeight = 52.0;

  // Voice recording states
  bool _isRecording = false;
  bool _isLocked = false;
  bool _isPaused = false;
  bool _showVideoIcon = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  double _slideOffset = 0.0;
  double _verticalSlideOffset = 0.0;

  // Store the starting position of the long press
  Offset? _recordStartPosition;

  AnimationController? _micPulseController;
  AnimationController? _slideArrowController;
  AnimationController? _lockSlideController;
  AnimationController? _waveformController;
  Animation<double>? _micPulseAnimation;
  Animation<Offset>? _slideArrowAnimation;
  Animation<double>? _lockSlideAnimation;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _emojiPickerOpen = widget.showEmojiPicker;
    _focusNode.addListener(_onFocusChanged);

    // Initialize animation controllers
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _slideArrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _lockSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat(reverse: true);

    _micPulseAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _micPulseController!, curve: Curves.easeInOut),
    );

    _slideArrowAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(-0.15, 0),
    ).animate(
      CurvedAnimation(parent: _slideArrowController!, curve: Curves.easeInOut),
    );

    _lockSlideAnimation = Tween<double>(begin: 0.0, end: -8.0).animate(
      CurvedAnimation(parent: _lockSlideController!, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant MessageInputField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.showEmojiPicker != oldWidget.showEmojiPicker) {
      setState(() {
        _emojiPickerOpen = widget.showEmojiPicker;
      });
    }

    // Focus when starting to edit
    if (widget.isEditing &&
        !oldWidget.isEditing &&
        widget.controller.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
        // Move cursor to the end
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: widget.controller.text.length),
        );
      });
    }

    // Clear focus when canceling edit
    if (!widget.isEditing && oldWidget.isEditing) {
      _focusNode.unfocus();
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }

    final textSpan = TextSpan(
      text: widget.controller.text,
      style: const TextStyle(fontSize: 18, color: Colors.white),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 6,
    );
    textPainter.layout(maxWidth: MediaQuery.of(context).size.width - 180);
    final textHeight = textPainter.size.height + 28;
    final newHeight = textHeight.clamp(52.0, 52.0 * 6);

    if (_textFieldHeight != newHeight) {
      setState(() {
        _textFieldHeight = newHeight;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend() {
    if (widget.controller.text.trim().isNotEmpty) {
      if (widget.isEditing) {
        widget.onSaveEdit();
      } else {
        widget.onSend();
      }
      widget.controller.clear();
      setState(() {
        _hasText = false;
        _textFieldHeight = 52.0;
      });
    }
  }

  void _toggleVoiceVideoIcon() {
    setState(() {
      _showVideoIcon = !_showVideoIcon;
    });
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
      _slideOffset = 0.0;
      _verticalSlideOffset = 0.0;
    });

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordingSeconds++;
        });
      }
    });
  }

  void _stopRecording() {
    _recordingTimer?.cancel();
    setState(() {
      _isRecording = false;
      _isLocked = false;
      _isPaused = false;
      _recordingSeconds = 0;
      _slideOffset = 0.0;
      _verticalSlideOffset = 0.0;
      _recordStartPosition = null;
    });
  }

  void _cancelRecording() {
    _stopRecording();
  }

  void _lockRecording() {
    setState(() {
      _isLocked = true;
      _verticalSlideOffset = 0.0;
      _slideOffset = 0.0;
    });
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });

    if (_isPaused) {
      _recordingTimer?.cancel();
    } else {
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingSeconds++;
          });
        }
      });
    }
  }

  void _sendVoiceMessage() {
    _stopRecording();
    widget.onVoiceNotePressed();
  }

  void _deleteVoiceMessage() {
    _stopRecording();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _handleEmojiButtonPressed() {
    if (_emojiPickerOpen) {
      _closeEmojiPickerAndOpenKeyboard();
    } else {
      _closeKeyboardAndOpenEmojiPicker();
    }
  }

  void _closeKeyboardAndOpenEmojiPicker() {
    _focusNode.unfocus();
    Future.delayed(const Duration(milliseconds: 50), () {
      widget.onEmojiPressed();
      setState(() {
        _emojiPickerOpen = true;
      });
    });
  }

  void _closeEmojiPickerAndOpenKeyboard() {
    widget.onEmojiPressed();
    Future.delayed(const Duration(milliseconds: 50), () {
      _focusNode.requestFocus();
      setState(() {
        _emojiPickerOpen = false;
      });
    });
  }

  void _handleTextFieldTap() {
    if (_emojiPickerOpen) {
      _closeEmojiPickerAndOpenKeyboard();
    }
  }

  // Store the starting position when long press begins
  void _onVoiceButtonLongPressStart(LongPressStartDetails details) {
    if (!_hasText && !_showVideoIcon && !widget.isEditing) {
      _recordStartPosition = details.globalPosition;
      _startRecording();
    }
  }

  // Calculate offset based on the starting position - THIS IS THE KEY
  void _onVoiceButtonLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_hasText &&
        !_showVideoIcon &&
        _isRecording &&
        !_isLocked &&
        _recordStartPosition != null &&
        !widget.isEditing) {
      // Calculate delta from the starting position
      final delta = details.globalPosition - _recordStartPosition!;

      setState(() {
        _slideOffset = delta.dx;
        _verticalSlideOffset = delta.dy;
      });

      // Cancel if slid too far left (more than 150 pixels)
      if (_slideOffset < -150) {
        _cancelRecording();
        return;
      }

      // Lock if slid up enough (more than 80 pixels up)
      if (_verticalSlideOffset < -80) {
        _lockRecording();
      }
    }
  }

  void _onVoiceButtonLongPressEnd(LongPressEndDetails details) {
    if (!_hasText &&
        !_showVideoIcon &&
        _isRecording &&
        !_isLocked &&
        !widget.isEditing) {
      if (_slideOffset < -150) {
        _cancelRecording();
      } else {
        _sendVoiceMessage();
      }
    }
  }

  Widget _buildActiveRecordingInterface() {
    final slideProgress = (_slideOffset.abs() / 150).clamp(0.0, 1.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main recording container
        Container(
          height: 52.0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius:
                widget.isReplying
                    ? const BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                      topLeft: Radius.circular(0),
                      topRight: Radius.circular(0),
                    )
                    : BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              // Animated mic icon
              AnimatedBuilder(
                animation: _micPulseAnimation!,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _micPulseAnimation!.value,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.mic, color: Colors.white, size: 20),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),

              // Time display
              Text(
                _formatDuration(_recordingSeconds),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 24),

              // Slide to cancel text with animated arrow
              Expanded(
                child: Opacity(
                  opacity: 1.0 - slideProgress,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Slide to cancel',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_slideArrowAnimation != null)
                        SlideTransition(
                          position: _slideArrowAnimation!,
                          child: Icon(
                            Icons.keyboard_arrow_left,
                            color: Colors.grey.shade500,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 60),
            ],
          ),
        ),

        Positioned(
          right:
              8 +
              _slideOffset.clamp(-150.0, 0.0), // Move horizontally with slide
          top:
              -100 +
              _verticalSlideOffset.clamp(
                -100.0,
                0.0,
              ), // Move vertically with slide
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lock icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A3A),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.lock_outline,
                    color: Colors.grey.shade300,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Animated arrow up
              if (_lockSlideAnimation != null)
                AnimatedBuilder(
                  animation: _lockSlideAnimation!,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _lockSlideAnimation!.value),
                      child: Icon(
                        Icons.keyboard_arrow_up,
                        color: Colors.lightBlue,
                        size: 28,
                      ),
                    );
                  },
                ),
              const SizedBox(height: 8),

              // Mic icon in circle - this now moves with the entire column
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A3A),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(Icons.mic, color: Colors.grey.shade300, size: 22),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLockedRecordingInterface() {
    return Container(
      height: 52.0,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius:
            widget.isReplying
                ? const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                  topLeft: Radius.circular(0),
                  topRight: Radius.circular(0),
                )
                : BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          // Delete button
          IconButton(
            onPressed: _deleteVoiceMessage,
            icon: Icon(
              Icons.delete_outline,
              color: Colors.red.shade400,
              size: 26,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),

          const SizedBox(width: 12),

          // Time display
          Text(
            _formatDuration(_recordingSeconds),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(width: 12),

          // Waveform
          Expanded(child: _buildAnimatedWaveform()),

          const SizedBox(width: 12),

          // Timer/Duration icon (dotted circle)
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: CustomPaint(
              painter: DottedCirclePainter(
                progress: (_recordingSeconds % 60) / 60,
                dotColor: Colors.white,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Pause/Play button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _togglePause,
              icon: Icon(
                _isPaused ? Icons.play_arrow : Icons.pause,
                color: Colors.white,
                size: 24,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ),

          const SizedBox(width: 8),

          // Send button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _sendVoiceMessage,
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedWaveform() {
    return AnimatedBuilder(
      animation: _waveformController!,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(40, (index) {
            // Create varied heights for waveform
            final baseHeights = [
              4.0,
              6.0,
              8.0,
              10.0,
              14.0,
              18.0,
              20.0,
              22.0,
              20.0,
              16.0,
              12.0,
              8.0,
              6.0,
              4.0,
              6.0,
              8.0,
              12.0,
              16.0,
              18.0,
              20.0,
              22.0,
              20.0,
              16.0,
              12.0,
              10.0,
              8.0,
              6.0,
              8.0,
              10.0,
              14.0,
              16.0,
              18.0,
              16.0,
              12.0,
              8.0,
              6.0,
              4.0,
              6.0,
              8.0,
              10.0,
            ];

            double height;
            if (_isPaused) {
              height = 3.0;
            } else {
              final animatedOffset = (_waveformController!.value * 10).round();
              final animatedIndex =
                  (index + animatedOffset) % baseHeights.length;
              height = baseHeights[animatedIndex];
            }

            return Container(
              width: 2.5,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: _isPaused ? Colors.grey.shade600 : Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildSendOrSaveButton() {
    // When editing, show the save button with tick icon
    if (widget.isEditing) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.lightBlue[100],
          boxShadow: [
            BoxShadow(
              color: Colors.lightBlue.withOpacity(0.3),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          onPressed: widget.onSaveEdit,
          icon: Icon(Icons.check, color: Colors.blue, size: 22),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
      );
    }

    // Normal send button
    return GestureDetector(
      onTap: () {
        if (_hasText) {
          _handleSend();
        } else {
          _toggleVoiceVideoIcon();
        }
      },
      onLongPressStart: widget.isEditing ? null : _onVoiceButtonLongPressStart,
      onLongPressMoveUpdate:
          widget.isEditing ? null : _onVoiceButtonLongPressMoveUpdate,
      onLongPressEnd: widget.isEditing ? null : _onVoiceButtonLongPressEnd,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _hasText ? Colors.blue : Colors.transparent,
        ),
        child: Icon(
          _hasText
              ? Icons.send_outlined
              : _showVideoIcon
              ? Icons.videocam_outlined
              : Icons.mic_none_outlined,
          color: _hasText ? Colors.white : Colors.grey.shade400,
          size: _hasText ? 20 : 28,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Hide attachment and voice note buttons when editing
    final showAttachmentButtons = !widget.isEditing;
    final showVoiceButton = !widget.isEditing;

    return IntrinsicHeight(
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isRecording && !_isLocked)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  8,
                  widget.isReplying ? 0 : 6,
                  8,
                  6,
                ),
                child: _buildActiveRecordingInterface(),
              )
            else if (_isLocked)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  8,
                  widget.isReplying ? 0 : 6,
                  8,
                  6,
                ),
                child: _buildLockedRecordingInterface(),
              )
            else
              Padding(
                padding: EdgeInsets.fromLTRB(
                  8,
                  widget.isReplying ? 0 : 6,
                  8,
                  6,
                ),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: 52.0 * 6,
                    minHeight: 52.0,
                  ),
                  height: _textFieldHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius:
                        widget.isReplying
                            ? const BorderRadius.only(
                              bottomLeft: Radius.circular(28),
                              bottomRight: Radius.circular(28),
                              topLeft: Radius.circular(0),
                              topRight: Radius.circular(0),
                            )
                            : BorderRadius.circular(28),
                  ),
                  child: Row(
                    children: [
                      // Emoji button
                      if (showAttachmentButtons)
                        IconButton(
                          onPressed: _handleEmojiButtonPressed,
                          icon:
                              _emojiPickerOpen
                                  ? Icon(
                                    Icons.keyboard,
                                    color: Colors.grey.shade400,
                                    size: 28,
                                  )
                                  : SvgPicture.asset(
                                    'assets/svg/gif_icon.svg',
                                    width: 28,
                                    height: 28,
                                    colorFilter: ColorFilter.mode(
                                      Colors.grey.shade400,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        )
                      else
                        SizedBox(width: 8),

                      // Text field
                      Expanded(
                        child: Container(
                          alignment: Alignment.centerLeft,
                          child: TextField(
                            controller: widget.controller,
                            focusNode: _focusNode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  widget.isEditing ? "Edit message" : "Message",
                              hintStyle: const TextStyle(
                                color: Colors.grey,
                                fontSize: 18,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                            maxLines: 6,
                            minLines: 1,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (value) {
                              if (value.trim().isNotEmpty) _handleSend();
                            },
                            onTap: () {
                              _handleTextFieldTap();
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!_focusNode.hasFocus)
                                  _focusNode.requestFocus();
                              });
                            },
                            onTapOutside: (event) => _focusNode.unfocus(),
                            scrollController: _scrollController,
                            scrollPhysics: const ClampingScrollPhysics(),
                            keyboardAppearance: Brightness.dark,
                            cursorColor: Colors.blue,
                            enableInteractiveSelection: true,
                            enableSuggestions: true,
                          ),
                        ),
                      ),

                      // Attachment button (hidden when editing)
                      if (showAttachmentButtons)
                        IconButton(
                          onPressed: widget.onAttachmentPressed,
                          icon: Icon(
                            Icons.add,
                            color: Colors.grey.shade400,
                            size: 32,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        )
                      else
                        SizedBox(width: 8),

                      // Express message button (hidden when editing)
                      if (showAttachmentButtons)
                        IconButton(
                          onPressed: () {},
                          icon: SvgPicture.asset(
                            'assets/svg/express_message.svg',
                            width: 40,
                            height: 40,
                            colorFilter: ColorFilter.mode(
                              Colors.grey.shade400,
                              BlendMode.srcIn,
                            ),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        )
                      else
                        SizedBox(width: 8),

                      // Send/Save button
                      _buildSendOrSaveButton(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _scrollController.dispose();
    _recordingTimer?.cancel();
    _micPulseController?.dispose();
    _slideArrowController?.dispose();
    _lockSlideController?.dispose();
    _waveformController?.dispose();
    super.dispose();
  }
}

class DottedCirclePainter extends CustomPainter {
  final double progress;
  final Color dotColor;

  DottedCirclePainter({required this.progress, required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final dotCount = 12;
    final sweepAngle = 2 * math.pi * progress;
    final paint =
        Paint()
          ..color = dotColor
          ..style = PaintingStyle.fill;

    for (int i = 0; i < dotCount; i++) {
      final angle = (i / dotCount) * 2 * math.pi - (math.pi / 2);
      if (angle + (math.pi / 2) <= sweepAngle) {
        final x = center.dx + radius * math.cos(angle);
        final y = center.dy + radius * math.sin(angle);
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DottedCirclePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
