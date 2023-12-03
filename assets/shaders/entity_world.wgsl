const ImageSize = vec2<f32>(2048.0,2048.0);
const ColorTableImageSize = vec2<f32>(1024.0, 1024.0);
const ColorTableSize = vec2<f32>(64.0, 64.0);

//==============================================================================
// Vertex shader_bindings
//==============================================================================


//2 * 4 = 8 bytes
struct EntityProperties
{
    ImageIndexAndColorTableIndex: u32,
    //image_index            color_table_index
    //1111 1111 1111 1111 , 1111 1111 1111 1111
    AtlasCoordSizeAndColorTableStartPos: u32,
    //atlas_coord_size W, H       color_table_start_pos x,y
    //1111 1111, 1111 1111 ,    1111 1111, 1111 1111
};

struct EntityPropertiesStorage {
  properties: array<EntityProperties>,
};

struct VertexInput {
    @location(0) Position: vec4<f32>
}

//4 * 4 = 16 bytes
struct EntityInput
{
	@location(1) Position: vec3<f32>,
    @location(2) Data: u32,
    //AtlasCoordPos X|Y     ColorTableOffsetX          entity_properties_index
    //1111 11|11 1111       1111                       1111 1111 1111 1111
    //Image Smallest        0 - 15 = 16                65535
    //Size = 32 PX
    // * atlas_coord_size
    //for position
};

//10 * 4 = 40 bytes
struct VertexOutput {
    @builtin(position) Position: vec4<f32>,
    @location(0) TexCoord : vec2<f32>,
    @location(1) @interpolate(flat) image_index : u32,
    @location(2) @interpolate(flat) color_table_index : u32,
    @location(3) ColorTablePos : vec2<f32>,
}

struct CameraUniform {
    view_proj: mat4x4<f32>
//    direction: u32,
//    map_center: vec2<i32>
};
@group(2) @binding(0)
var<uniform> camera: CameraUniform;
@group(3) @binding(0) var<storage, read> entity_properties : EntityPropertiesStorage;

@vertex
fn vs_main(
    vertex_input: VertexInput,
    entity_input: EntityInput,
) -> VertexOutput {
    let entityPropertiesIndex = entity_input.Data & 0x0000ffffu;
    let entity_property = entity_properties.properties[entityPropertiesIndex];

    let imageIndex = entity_property.ImageIndexAndColorTableIndex >> 16u;
    let colorTableIndex = entity_property.ImageIndexAndColorTableIndex & 0x0000ffffu;
    let atlasCoordSize = vec2<f32>(f32(entity_property.AtlasCoordSizeAndColorTableStartPos >> 24u), f32((entity_property.AtlasCoordSizeAndColorTableStartPos >> 16u) & 0x000000ffu));
    let colorTableOffset = f32((entity_input.Data >> 16u) & 0x0000000fu);
    let colorTablePos = vec2<f32>(f32((entity_property.AtlasCoordSizeAndColorTableStartPos >> 8u) & 0x000000ffu) + colorTableOffset, f32(entity_property.AtlasCoordSizeAndColorTableStartPos & 0x000000ffu)) * ColorTableSize;
    let atlasCoordPos = vec2<f32>(f32(entity_input.Data >> 26u), f32((entity_input.Data >> 20u) & 0x0000003fu)) * atlasCoordSize;

    let imageSize = atlasCoordSize;//vec2<f32>(f32(entity_input.atlas_coord_size & 0x0000ffffu), f32(entity_input.atlas_coord_size >> 16u));

    let position = vertex_input.Position.xy * imageSize - vec2<f32>(imageSize.x / 2.0, imageSize.y);

    var pos : vec4<f32> = vec4<f32>(position.xy + entity_input.Position.xy, entity_input.Position.z, 1.0);
    pos = camera.view_proj * pos;

    let imagePos = atlasCoordPos;//vec2<f32>(f32(entity_input.AtlasCoordPos & 0x0000ffffu), f32(entity_input.AtlasCoordPos >> 16u));
    let texCoord = vec2<f32>((imagePos + imageSize * vertex_input.Position.xy) / ImageSize);

    //      let colorTablePos = vec2<f32>(f32(entity_input.ColorTableIndexAndPos & 0x000000ffu), f32((entity_input.ColorTableIndexAndPos >> 8u) & 0x000000ffu));
    //      let colorTableIndex = entity_input.ColorTableIndexAndPos >> 16u;
    let output = VertexOutput(
    pos,
    texCoord,
    imageIndex,
    colorTableIndex,
    colorTablePos
    );
    return output;
}

//==============================================================================
// Fragment shader_bindings
//==============================================================================
@group(0) @binding(0)
var t_diffuse: texture_2d_array<f32>;
@group(0) @binding(1)
var s_diffuse: sampler;
@group(1) @binding(0)
var t_color_table: texture_2d_array<f32>;
@group(1) @binding(1)
var s_color_diffuse: sampler;


@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let pos = textureSample(t_diffuse, s_diffuse, in.TexCoord, in.image_index).xy * vec2<f32>(255.0, 255.0);
//    return vec4<f32>(1.0, 1.0, 1.0, 1.0);
    if(pos.x <= 0.0 && pos.y <= 0.0){
        discard;
    }
    let final_color = tsw(t_color_table, s_color_diffuse, in, pos);
    return final_color;
}


fn tsw(t_diffuse: texture_2d_array<f32>, s_diffuse: sampler, in: VertexOutput, pos: vec2<f32>) -> vec4<f32> {
    return textureSample(t_diffuse, s_diffuse, (pos + in.ColorTablePos) / ColorTableImageSize.xy, in.color_table_index);
}