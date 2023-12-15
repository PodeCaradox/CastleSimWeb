const ImageSize = vec2<f32>(2048.0,2048.0);
const ColorTableImageSize = vec2<f32>(1024.0, 1024.0);
const ColorTableSize = vec2<f32>(256.0, 1.0);
const TileSize = vec2<f32>(64.0, 32.0);
const ZStep : f32 = 0.0000001;
//==============================================================================
// Vertex shader_bindings
//==============================================================================
fn u8_to_i8(value: u32) -> f32 {
    if ((value & 0x80u) != 0u) {
        // If the highest bit is set, it's a negative number in i8 terms.
        return f32(value) - 256.0;
    } else {
        return f32(value);
    }
}

fn screen_to_map_pos(position: vec2<f32>) -> vec2<i32> {
    var x: f32 = (position.y / TileSize.y) + (position.x / TileSize.x);
    var y: f32 = (position.y / TileSize.y) - (position.x / TileSize.x);
    if (x < 0.0) {
        x -= 1.0;
    }

    if (y < 0.0) {
        y -= 1.0;
    }

    return vec2<i32>(i32(x), i32(y));
}

fn WorldPosToDepth(world_pos: vec2<i32>) -> f32{
	let size: f32 = f32(params.map_size.x * params.map_size.y);
	return 1.0f - f32(world_pos.y * params.map_size.x + world_pos.x) / size;
}

fn rotate(pos_to_rotate: vec2<f32>) -> vec2<f32> {
    let pos = pos_to_rotate - params.map_center;

    // Convert direction to radians
    let radians: f32 = radians(f32(params.direction * 90));

    // Convert Cartesian coordinates to isometric
    let cart_x: f32 = (2.0 * pos.y + pos.x) / 2.0;
    let cart_y: f32 = (2.0 * pos.y - pos.x) / 2.0;

    // Apply rotation
    let rotated_x: f32 = cart_x * cos(radians) - cart_y * sin(radians);
    let rotated_y: f32 = cart_x * sin(radians) + cart_y * cos(radians);

    // Convert back to isometric coordinates
    let iso_rotated_x: f32 = rotated_x - rotated_y;
    let iso_rotated_y: f32 = (rotated_x + rotated_y) / 2.0;
    var new_pos = vec2<f32>(round(iso_rotated_x), round(iso_rotated_y));

    // Round and return the result as vec2<f32>
    return new_pos + params.map_center;
}

fn applyRotation(map_pos: vec2<i32>) -> vec2<i32> {
    //rotation
    if (params.direction == 0) {
        return map_pos;
    } else if(params.direction == 1) {
        return vec2<i32>(params.map_size.x - map_pos.y - 1, map_pos.x);
    } else if(params.direction == 2) {
        return vec2<i32>(params.map_size.x - map_pos.x - 1, params.map_size.y - map_pos.y - 1);
    }
    return vec2<i32>(map_pos.y, params.map_size.y - map_pos.x - 1);
}

//2 * 4 = 8 bytes
struct EntityProperties
{
    ImageIndexAndColorTableIndex: u32,
    //image_index            color_table_index
    //1111 1111 1111 1111 , 1111 1111 1111 1111
    ColorTableStartPos: u32,
    //color_table_start_pos x,y
    //1111 1111 1111 1111 ,    1111 1111 1111 1111
    //EntityType
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
	@location(1) Position: vec2<f32>,           //Vec2<f32> Z calculated
	@location(2) ImageOffset: u32,           //Vec2<f32> Z calculated
    @location(3) Data: u32,
    //Widht                 ColorTableOffsetX          entity_properties_index
    //1111 1111             1111 1111                  1111 1111 1111 1111
    @location(4) Size: u32,
    //AtlasCoordPos X       AtlasCoordPos Y        Height
    //1111 1111 1111        1111 1111 1111       1111 1111
};

//10 * 4 = 40 bytes
struct VertexOutput {
    @builtin(position) Position: vec4<f32>,
    @location(0) TexCoord : vec2<f32>,
    @location(1) @interpolate(flat) image_index : u32,
    @location(2) @interpolate(flat) color_table_index : u32,
    @location(3) @interpolate(flat) ColorTablePos : vec2<f32>,
}

struct CameraUniform {
    view_proj: mat4x4<f32>,
    map_size: vec2<i32>,
    map_center: vec2<f32>,
    direction: i32
};
@group(0) @binding(0)
var<uniform> params: CameraUniform;
@group(1) @binding(0) var<storage, read> entity_properties : EntityPropertiesStorage;

@vertex
fn vs_main(
    vertex_input: VertexInput,
    entity_input: EntityInput,
) -> VertexOutput {
    let entityPropertiesIndex = entity_input.Data & 0x0000ffffu;
    let entity_property = entity_properties.properties[entityPropertiesIndex];

    let imageIndex = entity_property.ImageIndexAndColorTableIndex >> 16u;
    let colorTableIndex = entity_property.ImageIndexAndColorTableIndex & 0x0000ffffu;
    let atlasCoordSize = vec2<f32>(f32(entity_input.Data >> 24u) * 2.0, f32(entity_input.Size & 0x000000ffu) * 2.0);
    let colorTableOffsetValue = (entity_input.Data >> 16u) & 0x0000000fu;
    let colorTableOffset = vec2<f32>(f32(colorTableOffsetValue % 4u), f32(colorTableOffsetValue / 4u));
    let colorTablePos = (vec2<f32>(f32(entity_property.ColorTableStartPos & 0x0000ffffu), f32((entity_property.ColorTableStartPos >> 16u) & 0x0000ffffu)) + colorTableOffset) * ColorTableSize;
    let atlasCoordPos = vec2<f32>(f32((entity_input.Size >> 20u) & 0x00000fffu), f32((entity_input.Size >> 8u) &  0x00000fffu));
    let image_offset = vec2<f32>(u8_to_i8(entity_input.ImageOffset & 0x000000ffu), u8_to_i8((entity_input.ImageOffset >> 8u) & 0x000000ffu));
    let elevation = f32((entity_input.ImageOffset >> 16u) & 0x0000ffffu);
    let imageSize = atlasCoordSize;

    let position = vertex_input.Position.xy * imageSize - vec2<f32>(imageSize.x / 2.0, imageSize.y);
    //let pos_rotated = rotate(entity_input.Position);

    var new_pos = entity_input.Position;
    new_pos = rotate(new_pos);
    let map_pos = screen_to_map_pos(new_pos);
    let depth = WorldPosToDepth(map_pos);
    new_pos += image_offset;
    new_pos.y -= elevation;
    var pos : vec4<f32> = vec4<f32>(position.xy + new_pos, depth, 1.0);
    pos = params.view_proj * pos;

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
@group(2) @binding(0)
var t_diffuse: texture_2d_array<f32>;
@group(2) @binding(1)
var s_diffuse: sampler;
@group(3) @binding(0)
var t_color_table: texture_2d_array<f32>;
@group(3) @binding(1)
var s_color_diffuse: sampler;


@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let pos = vec2<f32>(textureSample(t_diffuse, s_diffuse, in.TexCoord, in.image_index).r, 0.0) * vec2<f32>(255.0, 0.0);
    if(pos.x <= 0.0 && pos.y <= 0.0){
        discard;
    }
    let final_color = tsw(t_color_table, s_color_diffuse, in, pos);
    return final_color;
}


fn tsw(t_diffuse: texture_2d_array<f32>, s_diffuse: sampler, in: VertexOutput, pos: vec2<f32>) -> vec4<f32> {
    return textureSample(t_diffuse, s_diffuse, (pos + in.ColorTablePos) / ColorTableImageSize, in.color_table_index);
}