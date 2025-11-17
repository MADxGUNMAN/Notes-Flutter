import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable PIN input screen for creating or verifying a 6-digit PIN
/// Supports keyboard and on-screen number pad input
class PinInputScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final Function(String) onPinComplete;
  final bool obscurePin;

  const PinInputScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onPinComplete,
    this.obscurePin = true,
  });

  @override
  State<PinInputScreen> createState() => _PinInputScreenState();
}

class _PinInputScreenState extends State<PinInputScreen> {
  final List<String> _pinDigits = List.filled(6, '');
  int _currentIndex = 0;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus for keyboard input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onNumberPressed(String number) {
    if (_currentIndex < 6) {
      setState(() {
        _pinDigits[_currentIndex] = number;
        _currentIndex++;
      });

      if (_currentIndex == 6) {
        // PIN complete
        final pin = _pinDigits.join();
        widget.onPinComplete(pin);
      }
    }
  }

  void _onBackspace() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _pinDigits[_currentIndex] = '';
      });
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        _onBackspace();
        return;
      }

      // Handle number keys from top row (Digit0-9)
      if (event.logicalKey == LogicalKeyboardKey.digit0 || event.logicalKey == LogicalKeyboardKey.numpad0) {
        _onNumberPressed('0');
      } else if (event.logicalKey == LogicalKeyboardKey.digit1 || event.logicalKey == LogicalKeyboardKey.numpad1) {
        _onNumberPressed('1');
      } else if (event.logicalKey == LogicalKeyboardKey.digit2 || event.logicalKey == LogicalKeyboardKey.numpad2) {
        _onNumberPressed('2');
      } else if (event.logicalKey == LogicalKeyboardKey.digit3 || event.logicalKey == LogicalKeyboardKey.numpad3) {
        _onNumberPressed('3');
      } else if (event.logicalKey == LogicalKeyboardKey.digit4 || event.logicalKey == LogicalKeyboardKey.numpad4) {
        _onNumberPressed('4');
      } else if (event.logicalKey == LogicalKeyboardKey.digit5 || event.logicalKey == LogicalKeyboardKey.numpad5) {
        _onNumberPressed('5');
      } else if (event.logicalKey == LogicalKeyboardKey.digit6 || event.logicalKey == LogicalKeyboardKey.numpad6) {
        _onNumberPressed('6');
      } else if (event.logicalKey == LogicalKeyboardKey.digit7 || event.logicalKey == LogicalKeyboardKey.numpad7) {
        _onNumberPressed('7');
      } else if (event.logicalKey == LogicalKeyboardKey.digit8 || event.logicalKey == LogicalKeyboardKey.numpad8) {
        _onNumberPressed('8');
      } else if (event.logicalKey == LogicalKeyboardKey.digit9 || event.logicalKey == LogicalKeyboardKey.numpad9) {
        _onNumberPressed('9');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        elevation: 0,
      ),
      body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      widget.subtitle,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 48),
                  // PIN digit display
                  _buildPinDisplay(),
                  const SizedBox(height: 48),
                  // Number pad
                  _buildNumberPad(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinDisplay() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: List.generate(6, (index) {
          final hasDigit = _pinDigits[index].isNotEmpty;
          final isActive = index == _currentIndex;

          return Container(
            width: 48,
            height: 56,
            decoration: BoxDecoration(
              border: Border.all(
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
                width: isActive ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: widget.obscurePin && hasDigit
                  ? Icon(
                      Icons.circle,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : Text(
                      _pinDigits[index],
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNumberPad() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        children: [
          _buildNumberRow(['1', '2', '3']),
          const SizedBox(height: 12),
          _buildNumberRow(['4', '5', '6']),
          const SizedBox(height: 12),
          _buildNumberRow(['7', '8', '9']),
          const SizedBox(height: 12),
          _buildNumberRow(['', '0', 'backspace']),
        ],
      ),
    );
  }

  Widget _buildNumberRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((number) {
        if (number.isEmpty) {
          return const SizedBox(width: 72, height: 72);
        }

        if (number == 'backspace') {
          return _buildNumberButton(
            onPressed: _onBackspace,
            child: const Icon(Icons.backspace_outlined),
          );
        }

        return _buildNumberButton(
          onPressed: () => _onNumberPressed(number),
          child: Text(
            number,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNumberButton({
    required VoidCallback onPressed,
    required Widget child,
  }) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(36),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
