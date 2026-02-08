import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class AdvancedMediaPicker extends StatefulWidget {
  final Function(File imageFile) onImageSelected;
  final Function(List<File> imageFiles)? onMultipleImagesSelected;
  final VoidCallback? onDocumentPressed;
  final VoidCallback? onLocationPressed;
  final VoidCallback? onContactPressed;
  final VoidCallback? onEventPressed;
  final VoidCallback? onPollPressed;
  final VoidCallback? onAudioPressed;

  const AdvancedMediaPicker({
    super.key,
    required this.onImageSelected,
    this.onMultipleImagesSelected,
    this.onDocumentPressed,
    this.onLocationPressed,
    this.onContactPressed,
    this.onEventPressed,
    this.onPollPressed,
    required this.onAudioPressed,
  });

  @override
  State<AdvancedMediaPicker> createState() => _AdvancedMediaPickerState();
}

class _AdvancedMediaPickerState extends State<AdvancedMediaPicker> {
  final ImagePicker _imagePicker = ImagePicker();

  List<AssetEntity> _mediaList = [];
  List<AssetPathEntity> _albums = [];
  final List<String> _selectedMediaIds = [];

  bool _isLoadingGallery = false;
  bool _isLegacyAndroid = false;

  String _currentAlbum = 'Gallery';
  String _activeCategory = 'Gallery';

  @override
  void initState() {
    super.initState();
    _detectLegacyAndroid();
    _initGallery();
  }

  // LEGACY ANDROID DETECTION

  void _detectLegacyAndroid() {
    if (!Platform.isAndroid) return;

    final version = Platform.operatingSystemVersion;
    final apiMatch = RegExp(r'API (\d+)').firstMatch(version);

    if (apiMatch != null) {
      final apiLevel = int.tryParse(apiMatch.group(1) ?? '');
      _isLegacyAndroid = apiLevel != null && apiLevel <= 28;
    }
  }

  // PERMISSION + INIT

  Future<void> _initGallery() async {
    if (_isLegacyAndroid) {
      // 🔥 Legacy Android → filesystem picker
      return;
    }

    final PermissionState ps = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.all,
          mediaLocation: false,
        ),
      ),
    );

    if (!ps.hasAccess) {
      await PhotoManager.openSetting();
      return;
    }

    await PhotoManager.clearFileCache();
    await _loadGallery();
  }

  // LOAD MEDIA

  Future<void> _loadGallery() async {
    if (_isLegacyAndroid) return;

    setState(() => _isLoadingGallery = true);

    try {
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.all,
        onlyAll: false,
      );

      if (albums.isEmpty) {
        setState(() {
          _mediaList = [];
          _isLoadingGallery = false;
        });
        return;
      }

      _albums = albums;

      final AssetPathEntity mainAlbum = albums.firstWhere(
        (a) => a.isAll,
        orElse: () => albums.first,
      );

      _currentAlbum = mainAlbum.name;

      final List<AssetEntity> media = await mainAlbum.getAssetListPaged(
        page: 0,
        size: 300,
      );

      setState(() {
        _mediaList = media;
        _isLoadingGallery = false;
      });
    } catch (e) {
      debugPrint('Gallery load error: $e');
      setState(() => _isLoadingGallery = false);
    }
  }

  Future<void> _changeAlbum(AssetPathEntity album) async {
    if (_isLegacyAndroid) return;

    setState(() {
      _isLoadingGallery = true;
      _currentAlbum = album.name;
    });

    final media = await album.getAssetListPaged(page: 0, size: 300);

    setState(() {
      _mediaList = media;
      _isLoadingGallery = false;
    });
  }

  // MEDIA SELECTION

  void _toggleMediaSelection(String id) {
    setState(() {
      _selectedMediaIds.contains(id)
          ? _selectedMediaIds.remove(id)
          : _selectedMediaIds.add(id);
    });
  }

  Future<void> _sendSelectedMedia() async {
    if (_selectedMediaIds.isEmpty) return;

    final List<File> files = [];

    for (final id in _selectedMediaIds) {
      final asset = _mediaList.firstWhere((e) => e.id == id);
      final file = await asset.file;
      if (file != null) files.add(file);
    }

    Navigator.pop(context);

    if (files.length == 1) {
      widget.onImageSelected(files.first);
    } else if (files.isNotEmpty) {
      widget.onMultipleImagesSelected?.call(files);
    }
  }

  // LEGACY PICKER

  Future<void> _openLegacyPicker() async {
    final XFile? file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );

    if (file != null) {
      Navigator.pop(context);
      widget.onImageSelected(File(file.path));
    }
  }

  // UI

  @override
  Widget build(BuildContext context) {
    if (_isLegacyAndroid) {
      //  No grid on legacy Android (reliable behavior)
      Future.microtask(_openLegacyPicker);
      return const SizedBox.shrink();
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _handleBar(),
          _header(),
          Expanded(child: _galleryGrid()),
          _bottomActions(),
        ],
      ),
    );
  }

  Widget _handleBar() => Container(
    height: 20,
    alignment: Alignment.center,
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white, fontSize: 17),
          ),
        ),
        GestureDetector(
          onTap: _showAlbumPicker,
          child: Row(
            children: [
              Text(
                _currentAlbum,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, color: Colors.white),
            ],
          ),
        ),
        GestureDetector(
          onTap: _selectedMediaIds.isNotEmpty ? _sendSelectedMedia : null,
          child: CircleAvatar(
            backgroundColor:
                _selectedMediaIds.isNotEmpty ? Colors.blue : Colors.transparent,
            child:
                _selectedMediaIds.isNotEmpty
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
          ),
        ),
      ],
    ),
  );

  Widget _galleryGrid() {
    if (_isLoadingGallery) {
      return const Center(child: CircularProgressIndicator(color: Colors.blue));
    }

    if (_mediaList.isEmpty) {
      return const Center(
        child: Text('No media found', style: TextStyle(color: Colors.grey)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _mediaList.length,
      itemBuilder: (_, i) {
        final asset = _mediaList[i];
        final selected = _selectedMediaIds.contains(asset.id);

        return GestureDetector(
          onTap: () => _toggleMediaSelection(asset.id),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AssetEntityImage(
                asset,
                fit: BoxFit.cover,
                isOriginal: false,
                thumbnailSize: const ThumbnailSize.square(400),
              ),
              if (selected) Container(color: Colors.white.withOpacity(0.3)),
            ],
          ),
        );
      },
    );
  }

  Widget _bottomActions() => const SizedBox.shrink();

  void _showAlbumPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      builder:
          (_) => ListView(
            children:
                _albums
                    .map(
                      (a) => ListTile(
                        title: Text(
                          a.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _changeAlbum(a);
                        },
                      ),
                    )
                    .toList(),
          ),
    );
  }
}
