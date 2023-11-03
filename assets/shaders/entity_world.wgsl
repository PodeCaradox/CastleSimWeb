const ImageSize = vec2<f32>(2048.0,2048.0);
const ColorTableImageSize = vec2<f32>(1024.0, 1024.0);
const ColorTableSize = vec2<f32>(64.0, 64.0);

//8 * 4 = 32 bytes
struct EntityInstance
{
	Position: vec3<f32>,
    ImageIndex: u32,
    ColorTableIndex: u32,
    ColorTablePos: u32,
    AtlasCoordPos: u32,
    AtlasCoordSize: u32
};

//==============================================================================
// Vertex shader_bindings
//==============================================================================
struct VertexInput {
    @location(0) Position: vec4<f32>,
    @builtin(instance_index) instance_index: u32,
}

// 8 = 24 bytes
struct VertexOutput {
    @builtin(position) Position: vec4<f32>,
    @location(0) TexCoord : vec2<f32>,
    @location(1) ImageIndex : u32,
    @location(2) ColorTableIndex : u32,
    @location(3) ColorTablePos : vec2<f32>,
}

struct CameraUniform {
    view_proj: mat4x4<f32>
};
@group(1) @binding(0)
var<uniform> camera: CameraUniform;