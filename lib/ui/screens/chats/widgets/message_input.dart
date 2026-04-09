import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MessageInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final VoidCallback onSend;
  final double inputPillHeight;

  const MessageInputField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
    this.inputPillHeight = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              stops: const [0.0, 0.7, 1.0],
              colors: [
                const Color(0xFF08090B).withOpacity(0.98),
                const Color(0xFF08090B).withOpacity(0.80),
                const Color(0xFF08090B).withOpacity(0.0),
              ],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // ── Attachment ──────────────────────────────────────────
                  _glassPill(
                    width: inputPillHeight,
                    height: inputPillHeight,
                    child: Icon(
                      Icons.add,
                      color: Colors.white.withOpacity(0.7),
                      size: 25,
                    ),
                    onTap: () {},
                  ),
                  const SizedBox(width: 8),

                  // ── Text field ──────────────────────────────────────────
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: Container(
                          constraints: BoxConstraints(
                            minHeight: inputPillHeight,
                            maxHeight: 120,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF23262C).withOpacity(0.30),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF23262C),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const SizedBox(width: 14),
                              Expanded(
                                child: TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  maxLines: null,
                                  minLines: 1,
                                  keyboardType: TextInputType.multiline,
                                  textInputAction: TextInputAction.newline,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    height: 1.4,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Message',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.3),
                                      fontSize: 15,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    isDense: true,
                                  ),
                                ),
                              ),

                              // ── Express / emoji SVG ───────────────────
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: 4,
                                  bottom: 4,
                                ),
                                child: GestureDetector(
                                  onTap: () {},
                                  child: SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: Center(
                                      child: SvgPicture.asset(
                                        'assets/svg/gif_icon.svg',
                                        width: 23,
                                        height: 23,
                                        colorFilter: ColorFilter.mode(
                                          Colors.white.withOpacity(0.4),
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // ── GIF SVG pill ────────────────────────────────────────
                  _glassPill(
                    width: inputPillHeight,
                    height: inputPillHeight,
                    child: SvgPicture.asset(
                      'assets/svg/express_message.svg',
                      width: 40,
                      height: 40,
                      colorFilter: ColorFilter.mode(
                        Colors.white.withOpacity(0.7),
                        BlendMode.srcIn,
                      ),
                    ),
                    onTap: () {},
                  ),
                  const SizedBox(width: 8),

                  // ── Send / mic ──────────────────────────────────────────
                  hasText
                      ? GestureDetector(
                        onTap: onSend,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: inputPillHeight,
                          height: inputPillHeight,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4DA3FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child:
                              isSending
                                  ? const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                        ),
                      )
                      : _glassPill(
                        width: inputPillHeight,
                        height: inputPillHeight,
                        child: Icon(
                          Icons.mic_outlined,
                          color: Colors.white.withOpacity(0.7),
                          size: 25,
                        ),
                        onTap: () {},
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _glassPill({
    required double width,
    required double height,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: const Color(0xFF23262C).withOpacity(0.30),
              borderRadius: BorderRadius.circular(height / 2),
              border: Border.all(color: const Color(0xFF23262C), width: 1.0),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
