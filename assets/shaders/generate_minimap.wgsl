//https://alejandro61299.github.io/Minimaps_Personal_Research/
struct MiniMapParams {
    map_size: vec2<u32>,
    map_size_in_tiles: i32,
    x_offset: f32,
    mini_map_tile_size: vec2<f32>,
    minimap_image_pos: vec2<i32>,
};

//4 * 12 = 48 bytes //always dividable by 16
struct TileInstances
{
	TileIndex: u32,
	Color: u32,//Shadow Color
	MiniMapColor: u32,
	Elevation: f32,
    ObjectY: array<u32, 2>,//16 bits for Y //16 bits for Y //16 bits for Y //16 bits for Y
	AnimationData: u32,// 8 bit enabled, 8 bit enabled, 8 bit enabled, 8 bit enabled
	OffsetElevationX: u32,// 8 bit OffsetX, 8 bit OffsetX, 8 bit OffsetX, 8 bit OffsetX
    SingleInstances: array<u32, 24>,
};

struct TileInstancesStorage {
  tiles: array<TileInstances>,
};

fn map_to_minimap_pos(pos_x: i32, pos_y: i32) -> vec2<i32> {
    return vec2<i32>(i32(f32(pos_x - pos_y) * params.mini_map_tile_size.x * 0.5f + params.x_offset), i32(f32(pos_x + pos_y) * params.mini_map_tile_size.y * 0.5f));
}

fn u32ColorToVec4Color(u32_color: u32) -> vec4<f32> {
    // Return the color as a vec4<f32> with normalized values
    return vec4<f32>(f32(u32_color >> 24u), f32((u32_color >> 16u) & 0xFFu), f32((u32_color >> 8u) & 0xFFu), f32(u32_color & 0xFFu) ) / 255.0;
}

@group(0) @binding(0) var<uniform> params: MiniMapParams;
@group(1) @binding(0) var<storage, read> all_tiles : TileInstancesStorage;
@group(2) @binding(0) var t_interface: texture_storage_2d<rgba8unorm, write>;


@compute
@workgroup_size(16, 16, 1)
fn generate_minimap(@builtin(global_invocation_id) global_id: vec3<u32>) {
    if (global_id.x >= u32(params.map_size.x) || global_id.y >= u32(params.map_size.y)) {
        return;
    }

	let tile: TileInstances = all_tiles.tiles[global_id.y * params.map_size.x + global_id.x];
	var color: vec4<f32> = u32ColorToVec4Color(tile.MiniMapColor);
	let pos: vec2<i32> = map_to_minimap_pos(i32(global_id.x), i32(global_id.y));
   if (i32(params.mini_map_tile_size.y) > 1 && i32(params.mini_map_tile_size.x) > 1) {
     for (var y : i32 = 0; y < i32(params.mini_map_tile_size.y); y = y + 1) {
           for (var x : i32 = -i32(params.mini_map_tile_size.x); x < i32(params.mini_map_tile_size.x); x = x + 1) {

                textureStore(t_interface, params.minimap_image_pos + pos + vec2<i32>(x,y), color);
           }
       }
   }else{

     textureStore(t_interface, params.minimap_image_pos + pos, color);
   }


}