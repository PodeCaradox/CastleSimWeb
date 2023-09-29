struct SingleInstance
{
	ImageIndex: u32,
	AtlasCoordSize: u32
};

//12 bytes + 4 * 6 = 28
struct EntityInstance
{
	Position: vec3<f32>,
    ImageIndex: u32,
    AtlasCoordPos: u32,
    AtlasCoordSize: u32,
    MiniMapColor : u32,
    ObjectType : u32,
    Elevation : u32
};

//12 + 4 + 8 + 8 = 32 bytes;
struct InstancingObject
{
    Position: vec3<f32>,
	ImageIndex: u32,
	UvCoordPos: vec2<f32>,
	UvCoordSize: vec2<f32>
};


//==============================================================================
// Vertex shader_bindings
//==============================================================================
struct VertexInput {
    @location(0) Position: vec4<f32>,
    @builtin(instance_index) instance_index: u32,
}

// 16 byte + 8 byte + 4 bytes = 24 bytes
struct VertexOutput {
    @builtin(position) Position: vec4<f32>,
    @location(0) TexCoord : vec2<f32>,
    @location(1) @interpolate(flat)  Index : u32
}

struct CameraUniform {
    view_proj: mat4x4<f32>
};
@group(1) @binding(0)
var<uniform> camera: CameraUniform;