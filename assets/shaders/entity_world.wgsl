const ImageSize = vec2<f32>(2048.0,2048.0);
const ColorTableImageSize = vec2<f32>(1024.0, 1024.0);
const ColorTableSize = vec2<f32>(256.0, 1.0);
const TileSize = vec2<f32>(64.0, 32.0);
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

//A unit is a billboard standing at its foot row: nearness 2 foot - y, linear over the quad, so the
//vertex stage evaluates it (world_utils "Draw order"). These constants copy world_utils' (this
//shader does not import the chunk) and `cs_renderer::depth_order` mirrors them.
const KeysPerPixel : f32 = 16.0;
const KeysPerRowPair : i32 = 512;
const DepthHeadroomRows : i32 = 50;
const UnitNearnessBias : f32 = 0.5;

fn NearnessToDepth(nearness: f32) -> f32 {
    return (nearness * KeysPerPixel + 64.0) / f32((params.map_size.x + params.map_size.y + DepthHeadroomRows) * KeysPerRowPair);
}

//`foot` is the rotated, whole-pixel row of the quad's BOTTOM edge — the frame's
//image offset included, the elevation lift not; `vertex_y` the vertex's world
//row after both.
fn UnitDepth(foot: f32, vertex_y: f32) -> f32 {
    return NearnessToDepth(2.0 * foot - vertex_y + UnitNearnessBias);
}

//An overlay (a healthbar) hangs over its entity, so its offset is a hang and not a foot row: it
//takes no part in the nearness order and is drawn in front of everything on the map. The in-game UI
//shares this z and is drawn later.
const OverlayDepth : f32 = 1.0;
//Bit 20 of the instance's data word marks an overlay, beside the colour-table cell in bits 16..19
//(`EntityShaderInput::OVERLAY_FLAG`).
const OverlayFlag : u32 = 0x00100000u;

//Bits 21 and 22: the same-row neighbour left/right rises above the unit (a slice or a higher face;
//`core_entity::tall_beside`), so the quad past the own tile takes the own cell's V half a pixel
//behind. Bit 23: higher ground only, use the neighbour's V.
const TallLeftFlag : u32 = 0x00200000u;
const TallRightFlag : u32 = 0x00400000u;
const StepBesideFlag : u32 = 0x00800000u;
//Bit 31 of ImageOffset (bit 15 of the elevation half): the unit stands on a roof, a cell the
//building raises. The whole quad then stands on the cell's front tip: in front of its own slice and
//those behind, behind the one in front.
const OnBuildingFlag : u32 = 0x80000000u;
//bit 30 (bit 14 of the elevation): the unit's own cell's ground art stands (a "StandsUp" rock
//pile), so the middle sub-quad alone takes the front tip; the sides keep the ordinary rule, because
//beside him stands a wall rising out of his ground and not a roof he shares
const OnStandingArtFlag : u32 = 0x40000000u;
const ElevationMask : u32 = 0x3fffu;
//`TileSizeHalf` of world_utils.wgsl, which this shader does not import.
const TileHalf = vec2<f32>(32.0, 16.0);

//The V of a box on the cell with front tip (apex_x, tip_y), half a pixel behind: a flagged side's
//vertices carry it with the own apex, or with the neighbour's beside a step alone
//(`depth_order::side_nearness`).
fn SideNearness(tip_y: f32, apex_x: f32, x: f32, y: f32) -> f32 {
    return 2.0 * tip_y - abs(x - apex_x) - y - UnitNearnessBias;
}

//What a unit on a roof carries instead of UnitDepth: his cell's front tip, so his own slice cannot
//cut him, with the half pixel the anchor holds over that slice given to his feet (front tip 0.5,
//back edge 0), so two men in one roof cell keep the ordinary order.
fn RoofNearness(tip_y: f32, foot: f32, y: f32) -> f32 {
    let back = clamp((tip_y - foot) / (2.0 * TileHalf.y), 0.0, 1.0);
    return 2.0 * tip_y - y + UnitNearnessBias * (1.0 - back);
}

//`applyRotation` of world_utils.wgsl, copied: the terrain's permutation of the
//cells under the camera direction.
fn rotateCell(cell: vec2<i32>) -> vec2<i32> {
    if (params.direction == 0) {
        return cell;
    } else if (params.direction == 1) {
        return vec2<i32>(params.map_size.x - cell.y - 1, cell.x);
    } else if (params.direction == 2) {
        return vec2<i32>(params.map_size.x - cell.x - 1, params.map_size.y - cell.y - 1);
    }
    return vec2<i32>(cell.y, params.map_size.y - cell.x - 1);
}

//The front tip of the unit's own cell on the rotated screen, from its unrotated position: the cell
//by `sim_to_map_pos`'s arithmetic, then applyRotation and WorldToScreenPos. `depth_order` proves it
//is the tip of the cell `rotate` puts the unit into, up to the half pixel `rotate` rounds by.
fn OwnTip(position: vec2<f32>) -> vec2<f32> {
    let cell = vec2<i32>(i32(floor((position.x + 2.0 * position.y) / 64.0)), i32(floor((2.0 * position.y - position.x) / 64.0)));
    let rotated = rotateCell(cell);
    return vec2<f32>(TileHalf.x * f32(rotated.x - rotated.y), TileHalf.y * f32(rotated.x + rotated.y) + TileHalf.x);
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

//2 * 4 = 8 bytes
struct EntityProperties
{
    ImageIndexAndColorTableIndex: u32,          //image index in the high u16, colour table in the low
    ColorTableStartPos: u32,        //u16, u16 color_table_start_pos x,y
};

struct EntityPropertiesStorage {
  properties: array<EntityProperties>,
};

struct VertexInput {
    @location(0) Position: vec4<f32>
}


//5 * 4 = 20 bytes
struct EntityInput
{
	@location(1) Position: vec2<f32>,           //the unit's map position in pixels
	@location(2) ImageOffset: u32,           //i8 x and y offset, then the elevation and the stand-on flags
    @location(3) Data: u32,
    @location(4) Size: u32,
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
    let elevation = f32((entity_input.ImageOffset >> 16u) & ElevationMask);
    let imageSize = atlasCoordSize;

    //the quad's bottom row is the anchor; its columns come from the vertex's
    //ROLE below, not from a unit square
    let half_width = imageSize.x / 2.0;
    let position_y = vertex_input.Position.y * imageSize.y - imageSize.y;

    var new_pos = entity_input.Position;
    new_pos = rotate(new_pos);
    new_pos += image_offset;
    //the nearness is the row the feet are painted on, after the frame's offset (before it, the
    //unit's own ground cuts the legs off); a standing frame's ImageOffset.y is 0 by contract, and a
    //test reads this order from source
    let foot = new_pos.y;
    new_pos.y -= elevation;
    let world_y = position_y + new_pos.y;

    //three sub-quads cut at the own tile's edges (`entity_geometry::ENTITY_VERTICES`); the x byte
    //is the column role: 0 quad left, 1|2 tile left, 3|4 tile right, 5 quad right, a tile edge
    //outside the quad clamped onto it
    let role = u32(round(vertex_input.Position.x * 5.0));
    let quad_left = new_pos.x - half_width;
    let quad_right = new_pos.x + half_width;
    let tip = OwnTip(entity_input.Position);
    let tile_left = clamp(tip.x - TileHalf.x, quad_left, quad_right);
    let tile_right = clamp(tip.x + TileHalf.x, quad_left, quad_right);
    var world_x = quad_left;
    if (role == 1u || role == 2u) {
        world_x = tile_left;
    } else if (role == 3u || role == 4u) {
        world_x = tile_right;
    } else if (role == 5u) {
        world_x = quad_right;
    }
    //the middle and an unflagged side: the unit's feet; on a roof the whole quad stands on the
    //front tip; otherwise a flagged side takes the own cell's V half a pixel behind, or the
    //neighbour's beside a step
    var depth = UnitDepth(foot, world_y);
    let step = (entity_input.Data & StepBesideFlag) != 0u;
    //the standing-art flag takes the MIDDLE sub-quad only (roles 2 and 3);
    //the roof flag takes all six
    let middle = role == 2u || role == 3u;
    let on_tip = (entity_input.ImageOffset & OnBuildingFlag) != 0u
        || (middle && (entity_input.ImageOffset & OnStandingArtFlag) != 0u);
    if (on_tip) {
        depth = NearnessToDepth(RoofNearness(tip.y, foot, world_y));
    } else if (role <= 1u && (entity_input.Data & TallLeftFlag) != 0u) {
        depth = NearnessToDepth(SideNearness(tip.y, select(tip.x, tip.x - 2.0 * TileHalf.x, step), world_x, world_y));
    } else if (role >= 4u && (entity_input.Data & TallRightFlag) != 0u) {
        depth = NearnessToDepth(SideNearness(tip.y, select(tip.x, tip.x + 2.0 * TileHalf.x, step), world_x, world_y));
    }
    //a hanging marker, not a body: over everything (see OverlayDepth)
    if ((entity_input.Data & OverlayFlag) != 0u) {
        depth = OverlayDepth;
    }
    var pos : vec4<f32> = vec4<f32>(world_x, world_y, depth, 1.0);
    pos = params.view_proj * pos;

    let imagePos = atlasCoordPos;
    //the texel column follows the world column: a clamped side samples the
    //frame where its edge really is
    let u = (world_x - quad_left) / max(imageSize.x, 1.0);
    let texCoord = vec2<f32>((imagePos + imageSize * vec2<f32>(u, vertex_input.Position.y)) / ImageSize);

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
    let final_color = image_pos_to_color(t_color_table, s_color_diffuse, in, pos);
    return final_color;
}


fn image_pos_to_color(t_diffuse: texture_2d_array<f32>, s_diffuse: sampler, in: VertexOutput, pos: vec2<f32>) -> vec4<f32> {
    return textureSample(t_diffuse, s_diffuse, (pos + in.ColorTablePos) / ColorTableImageSize, in.color_table_index);
}