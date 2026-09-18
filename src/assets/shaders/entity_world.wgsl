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

//The per-pixel nearness of world_utils.wgsl (see "Draw order" there) for a
//unit, which is a billboard standing at its foot row: at a pixel row y it
//shows a point of its body foot - y high, nearness 2 foot - y — linear over
//the quad, so the vertex stage can evaluate it and the rasterizer carries it
//to every pixel. `KeysPerPixel`, `KeysPerRowPair`, `DepthHeadroomRows` and
//`UnitNearnessBias` are copies of the world_utils constants (this shader does
//not import the chunk) and `cs_renderer::depth_order` mirrors them in Rust.
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

//An OVERLAY is a quad that is not a body standing in the world: it HANGS over
//the entity it belongs to, and its `ImageOffset` is that hang, not the row its
//feet are painted on. A healthbar is the only one today. Its offset lifts it
//102 px, so the nearness of its OWN quad makes it a billboard standing about
//six rows BEHIND its unit, and every man, hill or house inside those six rows
//draws over it. No depth before `c0794bf4` did that: the row-major cell index
//read the entity's cell, and `UnitDepth` first read the row BEFORE the image
//offset. Moving the foot row after the offset was right for a body, whose
//feet are painted on the quad's bottom row wherever the frame's offset puts
//it, and wrong for the one quad whose offset is a hang.
//
//So an overlay takes no part in the nearness order at all: it is drawn in
//front of everything the map can produce, which is what `OverlayDepth` is
//worth (`depth_order::an_overlay_is_in_front_of_every_nearness_of_the_map`
//counts it against the crown of the tallest thing on the last row). The
//in-game UI sits at the same z (`game_ui.wgsl`) and is drawn AFTER the
//entities, so it still wins that tie, the way every tie in this depth buffer
//goes to whatever is drawn later.
const OverlayDepth : f32 = 1.0;
//Bit 20 of the instance's data word says so: bits 16..19 are the colour-table
//cell and bits 20..23 were free (`EntityShaderInput::OVERLAY_FLAG`).
const OverlayFlag : u32 = 0x00100000u;

//Bits 21 and 22: the same-screen-row neighbour to the screen LEFT / RIGHT of
//the unit's cell is TALL and rises above the unit — a building slice, or a
//face whose standing height is greater than the unit's
//(`EntityShaderInput::TALL_LEFT_FLAG` / `TALL_RIGHT_FLAG`, built per instance
//by `core_entity::tall_beside`). On such a side the part of the quad that
//hangs past the unit's own tile is ordered by the unit's OWN cell's V, half a
//pixel behind it, instead of by the unit's feet: see SideNearness and the
//three sub-quads in vs_main. Bit 23 (`STEP_BESIDE_FLAG`): every flagged side
//is higher ground with NO building — such a side takes the NEIGHBOUR's V
//instead, the own V would cut its arm over the step against the neighbour's
//lifted plateau. One bit for both sides, the word's last.
const TallLeftFlag : u32 = 0x00200000u;
const TallRightFlag : u32 = 0x00400000u;
const StepBesideFlag : u32 = 0x00800000u;
//Bit 31 of the ImageOffset word — bit 15 of its elevation half
//(`EntityShaderInput::ON_BUILDING_FLAG`): the unit's OWN cell carries a
//building slice under this camera direction and is raised by the building —
//a roof, not the ground inside tower_bigc. The data word has no bit left,
//and the elevation needs 15 at most: a wall crest is MAX_HEIGHT_WALL 712, the
//tallest roof (tower_round, ObjectElevation 912) on the highest ground
//(MAX_HEIGHT 512) is 1424, an arrow's arc MAX_ARC_HEIGHT_PX 200 — cs_core's
//`the_on_building_bit_is_free_of_every_height_the_field_carries` pins all
//three. On such a cell the MIDDLE sub-quad stands on the cell's FRONT TIP
//instead of on the foot: 2 tip - y + 0.5, half a pixel in front of the own
//slice at its apex (2 tip - |dx| - y) and more elsewhere, in front of every
//slice behind, behind the slice of the cell in front but for the one column
//x = apex. A man on the gate roof stood with his foot 16 - fwd px behind the
//tip his own slice stands on, and the slice won |dx| < 31.5 - 2 fwd — at the
//centre every column, the parapet through his legs (depth_order counts it:
//`a_unit_on_a_building_roof_is_in_front_of_its_own_slice_and_behind_the_slice_in_front`).
//Two men in one roof cell are NOT left sharing that depth: the half pixel
//the tip anchor holds over the own slice is spent on their FEET again
//(RoofNearness below), so the ordinary order survives on a roof. The whole
//quad stands on the tip, the flagged sides too: left on SideNearness
//(da852415) a side
//flagged for the same-row neighbour's slice put the shoulder past the tile
//edge behind that neighbour's roof and parapet, which stand beside the man
//on the same floor (343 692 of 343 692 px on gate_0, counted in the same
//test).
const OnBuildingFlag : u32 = 0x80000000u;
const ElevationMask : u32 = 0x7fffu;
//`TileSizeHalf` of world_utils.wgsl, which this shader does not import.
const TileHalf = vec2<f32>(32.0, 16.0);

//The V of a box or a face on the cell whose front tip is (apex_x, tip_y) —
//`2 * tip - |x - apex| - y`, what render_terrain.wgsl writes for a building
//slice — half a pixel BEHIND it. On a flagged side the vertices past the
//unit's own tile carry this with the unit's OWN apex instead of UnitDepth.
//Past the own tile the own V is the box of the cell behind the diagonal (E0,
//apex +/- 32, one row back) minus the half pixel, and it lies under the
//same-row neighbour's box (E1, apex +/- 64) by 2 |dx| - 63.5: the unit is
//behind BOTH slices over the overhang. With the NEIGHBOUR's apex (8b488463)
//the side was half a pixel behind E1 but up to 47.5 px in front of E0, and
//wherever E1's art is transparent — a buttress slice, a window edge, the gap
//between pinnacles — E0's wall showed with the sword drawn over it: the
//owner's slivers. Beside HIGHER GROUND alone (the second clause of is_tall,
//no building, StepBesideFlag) the own V would lie behind the neighbour's
//whole lifted plateau diamond and cut the arm over the step from the feet up
//(counted in depth_order: 27 rows in a column), where the neighbour's V loses
//its edge row alone — so such a side keeps the NEIGHBOUR's apex, tip.x -/+
//2 * TileHalf.x, as in 8b488463. Linear in y and in x: on the own apex a
//side starts 32 px from it and runs away, one slope, no fold; on the
//neighbour's apex a side that reaches past it crosses the fold and the
//rasteriser draws the chord under the V between the two vertices.
//`depth_order::side_nearness` and `unit_nearness_at` mirror both.
fn SideNearness(tip_y: f32, apex_x: f32, x: f32, y: f32) -> f32 {
    return 2.0 * tip_y - abs(x - apex_x) - y - UnitNearnessBias;
}

//What a unit on a ROOF cell carries instead of UnitDepth's foot row: his
//cell's front TIP, so the slice painted on his own cell cannot cut him —
//with the half pixel that anchor holds over that slice (UnitNearnessBias)
//given back to his FEET. A man at the cell's front tip keeps the whole half
//pixel, one at its back edge keeps none, and the 32 rows of the diamond
//between them are the scale, so two men in one roof cell are ordered by
//their feet exactly as anywhere else instead of by their draw order
//(depth_order: two_men_on_one_roof_cell_are_ordered_by_their_feet_like_everywhere_else,
//8 708 400 px of gate_0 and 4 838 000 of tower_round drawn by the slot
//before this). Nothing else moves: the man stays at or in front of his own
//slice's V in every column of his quad (a tie is his, the entities are drawn
//after the terrain), in front of every slice of a cell behind, and behind
//the slice of the cell in front but for the hairline column x = apex.
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

//The front tip of the unit's own cell on the rotated screen, from its
//UNROTATED position: the cell by `sim_to_map_pos`'s arithmetic
//(floor((x + 2y) / 64), floor((2y - x) / 64) — the same cell the CPU flagged
//the neighbours of), then the terrain's own two steps, `applyRotation` and
//`WorldToScreenPos`. `depth_order` proves for all four directions that this is
//the tip of the cell `rotate` puts the unit into (up to the half pixel
//`rotate` rounds by), so the same-row neighbours' apexes are tip.x -/+ 64.
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
    ImageIndexAndColorTableIndex: u32,          //u16, u16 image_index, color_table_index
    ColorTableStartPos: u32,        //u16, u16 color_table_start_pos x,y
                                    //Entity Type
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
	@location(1) Position: vec2<f32>,           //Vec2<f32> Z calculated
	@location(2) ImageOffset: u32,           //Vec2<f32> Z calculated
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
    //the feet are painted on the quad's bottom row, and the nearness has to
    //be that row: taken before the offset, the unit's own flat ground wins
    //every row the frame's offset pushes below the position and cuts the
    //legs off (c0794bf4 measured 90 opaque rows instead of 102). The same
    //row is the unit's depth ANCHOR against everything else, and a building
    //compares against the front-edge V of its cell with no offset at all —
    //so a y offset on a standing frame put the anchor 12 to 16 px in front
    //of the unit and drew it through a wall it stood behind
    //(docs/BEFUND-aufpoppen.md). A standing frame's ImageOffset.y is
    //therefore 0 by contract, pinned in the data by cs_initializer
    //(entity_json.rs) and in the mirror by depth_order::UNIT_IMAGE_OFFSET_Y.
    //Do NOT move this line above the offset to get the same effect: that is
    //the cut legs, and the mirror's test reads this order from source.
    let foot = new_pos.y;
    new_pos.y -= elevation;
    let world_y = position_y + new_pos.y;

    //THREE sub-quads side by side, cut at the edges of the unit's own tile
    //(`entity_geometry::ENTITY_VERTICES`): the vertex's x byte is its column
    //ROLE, 0 quad left edge, 1|2 the tile's left edge (twice: one vertex per
    //sub-quad, because the two carry different depths), 3|4 the tile's right
    //edge, 5 quad right edge. A tile edge outside the quad is clamped onto
    //it and that side is zero wide — a frame that does not hang over its
    //tile draws exactly as one quad did.
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
    //the middle sub-quad and an unflagged side: the unit's feet, as always.
    //On a building cell the WHOLE quad stands on the cell's front tip
    //instead, sides included, his feet deciding only against the other men
    //of that cell (see OnBuildingFlag, RoofNearness). Otherwise a flagged
    //side: the unit's OWN cell's V half a pixel behind — behind the slice
    //beside and the slice behind the diagonal alike — or, beside a step
    //alone, the NEIGHBOUR's V half a pixel behind (see SideNearness).
    var depth = UnitDepth(foot, world_y);
    let step = (entity_input.Data & StepBesideFlag) != 0u;
    if ((entity_input.ImageOffset & OnBuildingFlag) != 0u) {
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