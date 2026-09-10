//https://alejandro61299.github.io/Minimaps_Personal_Research/
struct MiniMapParams {
    map_size: vec2<u32>,
    map_size_in_tiles: i32,
    x_offset: f32,
    mini_map_tile_size: vec2<f32>,
    minimap_image_pos: vec2<i32>,
    direction: u32,
};

struct TileInstances
{
	TileIndex: u32,
	Color: u32,//Shadow Color
	MiniMapColor: u32,
	Elevation: f32,
};

struct TileInstancesStorage {
  tiles: array<TileInstances>,
};

fn map_to_minimap_pos(pos_x: i32, pos_y: i32) -> vec2<i32> {
    return vec2<i32>(i32(f32(pos_x - pos_y) * params.mini_map_tile_size.x * 0.5f + params.x_offset), i32(f32(pos_x + pos_y) * params.mini_map_tile_size.y * 0.5f));
}

//rotate the tile coords by the camera direction, so the generated minimap turns with the camera
fn apply_rotation(x: i32, y: i32) -> vec2<i32> {
    if (params.direction == 1u) {
        return vec2<i32>(i32(params.map_size.x) - y - 1, x);
    } else if (params.direction == 2u) {
        return vec2<i32>(i32(params.map_size.x) - x - 1, i32(params.map_size.y) - y - 1);
    } else if (params.direction == 3u) {
        return vec2<i32>(y, i32(params.map_size.y) - x - 1);
    }
    return vec2<i32>(x, y);
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
fn update_minimap(@builtin(global_invocation_id) global_id: vec3<u32>) {
    if (global_id.x >= u32(params.map_size.x) || global_id.y >= u32(params.map_size.y)) {
        return;
    }

    let tile: TileInstances = all_tiles.tiles[global_id.y * params.map_size.x + global_id.x];
    let linear = srgb_to_linear(u32ColorToVec4Color(tile.MiniMapColor));
    let tile_size = vec2<i32>(params.mini_map_tile_size);
    let rotated = apply_rotation(i32(global_id.x), i32(global_id.y));
    let pos: vec2<i32> = params.minimap_image_pos + map_to_minimap_pos(rotated.x, rotated.y);
    //asymmetric x range: that is the diamond fill of one iso tile
    if (tile_size.x > 1 && tile_size.y > 1) {
        for (var y : i32 = 0; y < tile_size.y; y = y + 1) {
            for (var x : i32 = -tile_size.x; x < tile_size.x; x = x + 1) {
                textureStore(t_interface, pos + vec2<i32>(x, y), linear);
            }
        }
    } else {
        textureStore(t_interface, pos, linear);
    }
}

fn srgb_to_linear(color: vec4<f32>) -> vec4<f32> {
    let c = color.rgb;
    return vec4<f32>(
        mix(
            c / 12.92,
            pow((c + 0.055) / 1.055, vec3<f32>(2.4)),
            step(vec3<f32>(0.04045), c)
        ),
        color.a
    );
}