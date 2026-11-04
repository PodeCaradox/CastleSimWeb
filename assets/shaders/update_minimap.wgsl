#import common
//https://alejandro61299.github.io/Minimaps_Personal_Research/
struct MiniMapParams {
    map_size: vec2<u32>,
    map_size_in_tiles: i32,
    x_offset: f32,
    mini_map_tile_size: vec2<f32>,
    minimap_image_pos: vec2<i32>,
    direction: u32,
    image_width: u32,
    image_height: u32,
    team_colours: array<vec4<u32>, 2>,
};

//the alpha byte of a structure's colour: drawn over the ground, not averaged with it
//(`cs_initializer::render_types::terrain::MINIMAP_ON_TOP_ALPHA`)
const MINIMAP_ON_TOP_ALPHA : u32 = 0xFEu;
const NO_CELL : u32 = 0xFFFFFFFFu;

fn u32ColorToVec4Color(u32_color: u32) -> vec4<f32> {
    // Return the color as a vec4<f32> with normalized values
    return vec4<f32>(f32(u32_color >> 24u), f32((u32_color >> 16u) & 0xFFu), f32((u32_color >> 8u) & 0xFFu), f32(u32_color & 0xFFu) ) / 255.0;
}

@group(0) @binding(0) var<uniform> params: MiniMapParams;
@group(1) @binding(0) var<storage, read> all_tiles : TileDataStorage;
//four bits per pixel, row-major: 0 no man, else his team + 1 (`MinimapUnits` of update_minimap/mod.rs)
@group(1) @binding(1) var<storage, read> units : array<u32>;
@group(2) @binding(0) var t_interface: texture_storage_2d<rgba8unorm, write>;

//the centre of a turned cell's diamond in minimap pixels
fn cell_centre(rotated: vec2<i32>) -> vec2<f32> {
    let half = params.mini_map_tile_size * 0.5;
    return vec2<f32>(f32(rotated.x - rotated.y) * half.x + params.x_offset, f32(rotated.x + rotated.y + 1) * half.y);
}

//a minimap point in turned cell coordinates, the cell's diamond being [x, x + 1) x [y, y + 1)
fn cell_space(point: vec2<f32>) -> vec2<f32> {
    let half = params.mini_map_tile_size * 0.5;
    let u = (point.x - params.x_offset) / half.x;
    let v = point.y / half.y;
    return vec2<f32>((v + u) * 0.5, (v - u) * 0.5);
}

//the index of the unturned cell drawn at `rotated` (the inverse of `rotate_cell`), NO_CELL off the map
fn cell_index(rotated: vec2<i32>) -> u32 {
    let size = vec2<i32>(params.map_size);
    var cell = rotated;
    if (params.direction == 1u) {
        cell = vec2<i32>(rotated.y, size.x - 1 - rotated.x);
    } else if (params.direction == 2u) {
        cell = vec2<i32>(size.x - 1 - rotated.x, size.y - 1 - rotated.y);
    } else if (params.direction == 3u) {
        cell = vec2<i32>(size.y - 1 - rotated.y, rotated.x);
    }
    if (any(cell < vec2<i32>(0)) || any(cell >= size)) {
        return NO_CELL;
    }
    return u32(cell.y) * params.map_size.x + u32(cell.x);
}

fn on_top(color: u32) -> bool {
    return (color & 0xFFu) == MINIMAP_ON_TOP_ALPHA;
}

//a structure is drawn opaque, the ground with its own alpha
fn linear_color(color: u32) -> vec4<f32> {
    let linear = srgb_to_linear(u32ColorToVec4Color(color));
    return select(linear, vec4<f32>(linear.rgb, 1.0), on_top(color));
}

//One thread per minimap pixel, so no two threads write one pixel: a man's team colour, else the linear
//mean of the ground cells whose centre lies in it, unless a structure's does (the smallest cell
//index wins). With no centre in it (cells bigger than a pixel) it takes the cell under its own centre.
@compute
@workgroup_size(16, 16, 1)
fn update_minimap(@builtin(global_invocation_id) global_id: vec3<u32>) {
    if (global_id.x >= params.image_width || global_id.y >= params.image_height) {
        return;
    }
    let pixel = vec2<i32>(global_id.xy);
    let texel = params.minimap_image_pos + pixel;
    //a man lies on top of everything
    let at = global_id.y * params.image_width + global_id.x;
    let team = (units[at / 8u] >> ((at % 8u) * 4u)) & 0xFu;
    if (team != 0u) {
        let colour = params.team_colours[(team - 1u) / 4u][(team - 1u) % 4u];
        textureStore(t_interface, texel, vec4<f32>(srgb_to_linear(u32ColorToVec4Color(colour)).rgb, 1.0));
        return;
    }
    let corner = vec2<f32>(pixel);
    //the cells whose centre can lie in the pixel: the box around its corners in cell space
    let box_min = vec2<i32>(floor(vec2<f32>(cell_space(corner).x, cell_space(corner + vec2<f32>(1.0, 0.0)).y))) - 1;
    let box_max = vec2<i32>(floor(vec2<f32>(cell_space(corner + vec2<f32>(1.0)).x, cell_space(corner + vec2<f32>(0.0, 1.0)).y))) + 1;

    var sum = vec4<f32>(0.0);
    var count = 0u;
    var top_cell = NO_CELL;
    //ponytail: every cell of the box is tested; a map far bigger than the minimap pays for its box
    for (var y = box_min.y; y <= box_max.y; y = y + 1) {
        for (var x = box_min.x; x <= box_max.x; x = x + 1) {
            let rotated = vec2<i32>(x, y);
            if (any(vec2<i32>(floor(cell_centre(rotated))) != pixel)) {
                continue;
            }
            let index = cell_index(rotated);
            if (index == NO_CELL) {
                continue;
            }
            let color = all_tiles.tiles[index].MiniMapColor;
            if (on_top(color)) {
                top_cell = min(top_cell, index);
            } else {
                sum = sum + linear_color(color);
                count = count + 1u;
            }
        }
    }

    if (top_cell != NO_CELL) {
        textureStore(t_interface, texel, linear_color(all_tiles.tiles[top_cell].MiniMapColor));
    } else if (count > 0u) {
        textureStore(t_interface, texel, sum / f32(count));
    } else {
        let index = cell_index(vec2<i32>(floor(cell_space(corner + vec2<f32>(0.5)))));
        if (index != NO_CELL) {
            textureStore(t_interface, texel, linear_color(all_tiles.tiles[index].MiniMapColor));
        }
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
