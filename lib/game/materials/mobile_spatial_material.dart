import 'dart:ui';

import 'package:flame_3d/game.dart';
import 'package:flame_3d/graphics.dart';
import 'package:flame_3d/resources.dart';

/// A safer material profile for mobile drivers that fail on light UBO binding.
class MobileSpatialMaterial extends Material {
  MobileSpatialMaterial({
    this.albedoColor = const Color(0xFFFFFFFF),
    Texture? albedoTexture,
    this.metallic = 0.8,
    this.roughness = 0.6,
    this.ambientColor = const Color(0xFFFFFFFF),
    this.ambientIntensity = 4.0,
  }) : albedoTexture = albedoTexture ?? Texture.standard,
       super(
         vertexShader: Shader.vertex(
           asset:
               'packages/flame_3d/assets/shaders/spatial_material.shaderbundle',
           slots: [
             UniformSlot.value('VertexInfo', {
               'model',
               'view',
               'projection',
             }),
             UniformSlot.value(
               'JointMatrices',
               List.generate(_maxJoints, (index) => 'joint$index').toSet(),
             ),
           ],
         ),
         fragmentShader: Shader.fragment(
           asset:
               'packages/flame_3d/assets/shaders/spatial_material.shaderbundle',
           slots: [
             UniformSlot.sampler('albedoTexture'),
             UniformSlot.value('Material', {
               'albedoColor',
               'metallic',
               'roughness',
             }),
             UniformSlot.value('AmbientLight', {'color', 'intensity'}),
             UniformSlot.value('Camera', {'position'}),
           ],
         ),
       );

  Color albedoColor;
  Texture albedoTexture;
  double metallic;
  double roughness;
  Color ambientColor;
  double ambientIntensity;

  @override
  void bind(GraphicsDevice device) {
    vertexShader
      ..setMatrix4('VertexInfo.model', device.model)
      ..setMatrix4('VertexInfo.view', device.view)
      ..setMatrix4('VertexInfo.projection', device.projection);

    final jointTransforms = device.jointsInfo.jointTransforms;
    if (jointTransforms.length > _maxJoints) {
      throw Exception(
        'At most $_maxJoints joints per surface are supported;'
        ' found ${jointTransforms.length}',
      );
    }
    for (final (index, transform) in jointTransforms.indexed) {
      vertexShader.setMatrix4('JointMatrices.joint$index', transform);
    }

    final cameraPosition =
        Matrix4.inverted(device.view).transform3(Vector3.zero());

    fragmentShader
      ..setTexture('albedoTexture', albedoTexture)
      ..setColor('Material.albedoColor', albedoColor)
      ..setFloat('Material.metallic', metallic)
      ..setFloat('Material.roughness', roughness)
      ..setColor('AmbientLight.color', ambientColor)
      ..setFloat('AmbientLight.intensity', ambientIntensity)
      ..setVector3('Camera.position', cameraPosition);
  }

  static const _maxJoints = 16;
}
