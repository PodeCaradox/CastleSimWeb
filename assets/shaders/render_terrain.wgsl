#import world_utils

//4 * 4 = 16 bytes
struct TileData
{//TODO make less bytes
	TileIndex: u32,
	Color: u32,//Shadow Color
	MiniMapColor: u32,
	Elevation: f32,
};

//4 * 8 = 32 bytes
struct TileRotationData
{//TODO make less bytes
    Data: u32,//16 bits for ObjectY //8 bit AnimationData //8 bit OffsetElevationX
    SingleInstances: array<u32, 6>,
    Free: u32
};



struct TileDataStorage {
  tiles: array<TileData>,
};

struct TileRotationDataStorage {
  tiles: array<TileRotationData>,
};

struct InstancingObjectStorage {
  tiles: array<world_utils::InstancingObject>,
};

@group(2) @binding(0) var<storage, read> tiles_data : TileDataStorage;
@group(2) @binding(1) var<storage, read> tiles_rotation : TileRotationDataStorage;
@group(3) @binding(0) var<storage, read_write> visble_tiles_cp : InstancingObjectStorage;


@compute
@workgroup_size(16, 16, 1)
fn instancing_with_elevation(@builtin(global_invocation_id) global_id: vec3<u32>) {
            var index: vec2<i32> = vec2<i32>(world_utils::params.start_pos.x, world_utils::params.start_pos.y);
            let column = i32(global_id.x);
            var row = i32(global_id.y);

            index.x -= row % 2;
            row /= 2;
            index.y += row;
            index.x -= row;
            let actual_row_start = index;
            index.y += column;
            index.x += column;

            if (world_utils::is_in_map_bounds(index) == 0) {
                return;
            }

            if (row >= world_utils::params.rows || column >= world_utils::params.columns){
                return;
            }

           let visible_index = world_utils::calc_visible_index(index, actual_row_start) * 4;

           let rotation_offset = world_utils::params.map_size.x * world_utils::params.map_size.y * i32(world_utils::params.direction);
           let tile_rotation_data = tiles_rotation.tiles[index.y * world_utils::params.map_size.x + index.x + rotation_offset];
           let tile_data = tiles_data.tiles[index.y * world_utils::params.map_size.x + index.x];

           let tick = world_utils::params.tick;
           var animation = (tile_rotation_data.Data >> 8u) & 0x000000ffu;
           var animation_enabled = animation & 0x00000001u;

           var offset_object_y = f32(tile_rotation_data.Data >> 16u);
           var offset_elevation_x =  world_utils::u8_to_i8(tile_rotation_data.Data & 0x000000ffu);


           visble_tiles_cp.tiles[visible_index] = world_utils::CreateSpecificInstance(tile_rotation_data.SingleInstances[0u], index, tile_data.Elevation, animation_enabled, tick, 0xffffffffu);
           animation_enabled = ((animation >> 1u) & 0x00000001u);
           visble_tiles_cp.tiles[visible_index + 1] = world_utils::CreateSpecificInstance(tile_rotation_data.SingleInstances[1u], index, tile_data.Elevation, animation_enabled, tick, 0xffffffffu);
           visble_tiles_cp.tiles[visible_index + 1].Position.z += world_utils::ZStep *  2.0;
           animation_enabled = ((animation >> 2u) & 0x00000001u);
           visble_tiles_cp.tiles[visible_index + 2] = world_utils::CreateBuildingInstance(tile_rotation_data.SingleInstances[2u], index, tile_data.Elevation, animation_enabled, tick, 0xffffffffu, offset_object_y);
           animation_enabled = ((animation >> 3u) & 0x00000001u);
           visble_tiles_cp.tiles[visible_index + 3] = world_utils::CreateElevationInstance(tile_rotation_data.SingleInstances[3u], index, tile_data.Elevation, animation_enabled, tick, 0xffffffffu, offset_elevation_x);
}

@compute
@workgroup_size(16, 16, 1)
fn instancing_without_elevation(@builtin(global_invocation_id) global_id: vec3<u32>) {
            var index: vec2<i32> = vec2<i32>(world_utils::params.start_pos.x, world_utils::params.start_pos.y);
            let column = i32(global_id.x);
            var row = i32(global_id.y);

            index.x -= row % 2;
            row /= 2;
            index.y += row;
            index.x -= row;
            let actual_row_start = index;
            index.y += column;
            index.x += column;

            if (world_utils::is_in_map_bounds(index) == 0) {
                return;
            }

           let visible_index = world_utils::calc_visible_index(index, actual_row_start) * 2;

           let rotation_offset = world_utils::params.map_size.x * world_utils::params.map_size.y * i32(world_utils::params.direction);
           let tile_rotation_data = tiles_rotation.tiles[index.y * world_utils::params.map_size.x + index.x + rotation_offset];

           let tick = world_utils::params.tick;
           var animation = (tile_rotation_data.Data >> 8u) & 0x000000ffu;
           var animation_enabled = animation & 0x00000001u;

           visble_tiles_cp.tiles[visible_index] = world_utils::CreateSpecificInstance(tile_rotation_data.SingleInstances[4u], index, 0.0, animation_enabled, tick, 0xffffffffu);
           animation_enabled = ((animation >> 1u) & 0x00000001u);
           visble_tiles_cp.tiles[visible_index + 1] = world_utils::CreateSpecificInstance(tile_rotation_data.SingleInstances[5u], index, 0.0, animation_enabled, tick, 0xffffffffu);
           visble_tiles_cp.tiles[visible_index + 1].Position.z += world_utils::ZStep *  2.0;
}

//==============================================================================
// Vertex shader_bindings
//==============================================================================
//16 bytes
struct VertexInput {
    @location(0) Position: vec2<f32>,
    @builtin(instance_index) instance_index: u32,
}

// 16 byte + 16 byte + 12 bytes = 44 bytes
struct VertexOutput {
    @builtin(position) Position: vec4<f32>,
    @location(0) Color: vec4<f32>,
    @location(1) TexCoord : vec2<f32>,
    @location(2) @interpolate(flat)  image_index : u32,
}

struct CameraUniform {
    view_proj: mat4x4<f32>
};
@group(1) @binding(0)
var<uniform> camera: CameraUniform;

@group(2) @binding(0) var<storage, read> visble_tiles: InstancingObjectStorage;

@vertex
fn vs_main(
    input: VertexInput,
) -> VertexOutput {

    let tileID = input.instance_index;
    let instance = visble_tiles.tiles[tileID];
      if (instance.Position.z == -10.0) {
        return VertexOutput(
          vec4<f32>(-100.0, -100.0, -100.0, 0.0),
          vec4<f32>(0.0, 0.0, 0.0, 0.0),
          vec2<f32>(0.0, 0.0),
          0u
        );
      }
      let imageSize = vec2<f32>(f32(instance.UvCoordSize & 0x0000ffffu), f32(instance.UvCoordSize >> 16u));

      // Calculate ImageSizeToDraw - vec2(imageSize.x/2,imageSize.y) because images have different starting points
      let position = input.Position * imageSize - vec2<f32>(imageSize.x / 2.0, imageSize.y);

      var pos : vec4<f32> = vec4<f32>(position.xy + instance.Position.xy, instance.Position.z, 1.0);
      pos = camera.view_proj * pos;
      
      let texCoord = vec2<f32>(instance.UvCoordPos + (imageSize * input.Position) / world_utils::ImageSize);

      let output = VertexOutput(
        pos,
        vec4<f32>(f32(instance.Color >> 24u), f32((instance.Color >> 16u) & 0x000000ffu), f32((instance.Color >> 8u) & 0x000000ffu), f32(instance.Color & 0x000000ffu) ) / 255.0,
        texCoord,
        instance.image_index
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

struct FragmentOutput {
    @location(0) color: vec4<f32>,
    //@builtin(frag_depth) depth: f32,  // Critical for writing
};


@fragment
fn fs_main(in: VertexOutput) -> FragmentOutput {
    let color = textureSample(t_diffuse, s_diffuse, in.TexCoord, in.image_index);
    if(color.a <= 0.0){
        discard;
    }
    var out: FragmentOutput;
    out.color = color * in.Color;
    //out.depth = in.Position.z;
    return out;
}