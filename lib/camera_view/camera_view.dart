import 'dart:io';

import 'package:flutter/material.dart';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as imgLib;

class CameraApp extends StatefulWidget {
  /// Default Constructor
  const CameraApp({Key? key}) : super(key: key);

  @override
  State<CameraApp> createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  CameraController? controller;
  List<Image> images = [];
  File? file;
  bool _takePicture = false;

  Future<imgLib.Image> convertYUV420toImageColor(CameraImage image) async {
    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel!;
    const shift = (0xFF << 24);
    var img = imgLib.Image(width, height);
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        final int uvIndex =
            uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
        final int index = y * width + x;
        final yp = image.planes[0].bytes[index];
        final up = image.planes[1].bytes[uvIndex];
        final vp = image.planes[2].bytes[uvIndex];
        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
        img.data[index] = shift | (b << 16) | (g << 8) | r;
      }
    }
    imgLib.PngEncoder pngEncoder = imgLib.PngEncoder(level: 0, filter: 0);
    List<int> png = pngEncoder.encodeImage(img);
    imgLib.Image rgbImage = imgLib.Image.fromBytes(width, height, png);
    return rgbImage;
  }

  Future<void> _initCamera() async {
    List<CameraDescription> _cameras;
    _cameras = await availableCameras();
    controller = CameraController(_cameras[0], ResolutionPreset.high);

    controller!.initialize().then((_) {
      if (!mounted) {
        return;
      }

      controller!.startImageStream((CameraImage availableImage) async {
        if (_takePicture) {
          _takePicture = false;
          imgLib.Image currImage =
              await convertYUV420toImageColor(availableImage);

          Image convertedImage = Image.memory(currImage.getBytes());

          setState(() {
            images.add(convertedImage);
          });
        }
      });

      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            print('User denied camera access.');
            break;
          default:
            print('Handle other errors.');
            break;
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    controller!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return Container();
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Camera example'),
        ),
        body: Column(
          children: [
            const Text("Live camera"),
            const SizedBox(height: 20),
            Expanded(
              child: CameraPreview(controller!),
            ),
            const Text("Pictures taken"),
            const SizedBox(height: 20),
            Expanded(
              child: SizedBox(
                height: double.infinity,
                width: double.infinity,
                child: images.isNotEmpty
                    ? Wrap(
                        children: List.generate(
                          images.length,
                          (index) => SizedBox(
                            width: 150,
                            child: images[index],
                          ),
                        ),
                      )
                    : const SizedBox(),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            if (_takePicture == false) {
              _takePicture = true;
            }
          },
          label: const Text('Take Picture'),
          icon: const Icon(Icons.camera_alt),
        ),
      ),
    );
  }
}
