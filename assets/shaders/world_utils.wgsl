#define_import_path world_utils
const TileSizeHalf = vec2<i32>(32,16);
const ImageSize = vec2<f32>(2048.0,2048.0);

//=============================================================================
// Draw order
//=============================================================================
//Every pipeline compares depth GreaterEqual and writes it: the nearer pixel
//wins, a tie goes to whatever is drawn later (terrain, then the entities).
//Nearness is the painter's key of a 2:1 isometric view, PER PIXEL: for the
//point of the surface a pixel shows, the map y of its ground position plus
//the height it stands at. A horizontal surface at height e shows at pixel y
//the ground point y + e, so its nearness is y + 2e; a vertical billboard
//standing at foot row f shows at pixel y a point of height f - y, so its
//nearness is 2f - y; a vertical face standing on the line v(x) shows the
//point of height v(x) - y, nearness 2v(x) - y. That is why one number per
//sprite was never enough: a cliff face spans the nearness of its whole
//height, and the plateau in front of it must win at its foot while the
//plateau behind it loses at its top — measured on the showcase terraces,
//which step by anything from 4 to 100 px between neighbours.
//
//The vertex stage evaluates the part that is linear across the quad and the
//fragment stage (render_terrain.wgsl) the |x| of a face's V and the wall's
//straight foot. `cs_renderer::depth_order` mirrors all of it in Rust and the
//tests count the draw order with it; change both together.
//
//`InstancingObject.Position.z` is not a depth but the instance's DEPTH
//RECIPE, chosen by the mode packed into `image_index` (the atlas image is a
//u8, the rest of the word is free):
//  bits  0- 7  atlas image
//  bits  8-19  depth denominator / 512 (map width + height + headroom)
//  bits 20-21  x offset of a face piece (0, +16, -16), so the fragment knows
//              the apex of the cell's V from the instance position
//  bits 22-23  mode
//  bits 24-25  a wall face continues to its left / right neighbour in the
//              same screen row: its foot is straight there
//  bits 26-31  the GROUND in front of a wall face, in steps of FrontStep px:
//              the height its straight foot has to be drawn over
const ImageIndexMask : u32 = 0xffu;
//the layer of wall.png in the environment atlas
//(cs_initializer::helper::init_images builds that order). Ground art
//from this layer STANDS on its cell; the land layer's tall tiles do not,
//because units walk on them (render_terrain.wgsl fs_main).
const WallAtlasLayer : u32 = 1u;
const DenominatorShift : u32 = 8u;
const DenominatorMask : u32 = 0xfffu;
const OffsetShift : u32 = 20u;
const ModeShift : u32 = 22u;
const RunShift : u32 = 24u;
const FrontShift : u32 = 26u;
const FrontMask : u32 = 0x3fu;
//The step of the elevation brush (`brush_elevation_up`, RandomFactor 4), so
//every height the editor can make is stored exactly. Six bits of the word are
//left, which caps the field: a wall whose ground in front is higher than
//FrontMax keeps the box's V (the old sawtooth) instead of drawing its foot
//over a ground it cannot name — the safe way round, nothing standing there is
//ever covered.
const FrontStep : f32 = 4.0;
const FrontMax : f32 = 252.0;
//Position.z = 2 * elevation; nearness = y + Position.z
const ModeGround : u32 = 0u;
//Position.z = 2 * foot row; nearness = Position.z - y (trees, bushes)
const ModeBillboard : u32 = 1u;
//Position.z = 2 * the cell's front tip row (map y, before the lift); the V
//of the cell's front edges is v(x) = tip - |x - apex| / 2, nearness
//2v(x) - y = Position.z - |x - apex| - y. A building slice is a box
//standing on those edges.
const ModeBox : u32 = 2u;
//ModeBox plus: the pixels above the plateau's front edges (v(x) - elevation)
//are the lower half of the plateau the artist painted into the face's top
//rows and are DISCARDED, and a wall face's pixels below the V toward a wall
//neighbour in the same row are the wall's thickness: nearness y + 2F + 1/2 for
//the ground F in front of the wall, so it is over that ground (Stronghold's
//straight diagonal walls) at EVERY height and under every unit standing on it
//— a unit's own foot row ties with it and the unit, drawn later, wins.
const ModeFace : u32 = 3u;
const RunLeft : u32 = 1u;
const RunRight : u32 = 2u;
//A unit's foot row is its own pixel row, which its own ground shows too: the
//half pixel puts the unit over the ground it stands on instead of leaving
//the row to interpolation rounding.
const UnitNearnessBias : f32 = 0.5;
//Nearness to depth: 16 keys per pixel, and the biggest nearness on the map
//is twice the last row plus the highest wall (cs_core's MAX_HEIGHT_WALL,
//712 px, is 44.5 rows) plus a billboard's height above that.
const KeysPerPixel : f32 = 16.0;
const KeysPerRowPair : u32 = 512u;
const DepthHeadroomRows : i32 = 50;
//`wall_elevation` in cs_initializer's `create_env_image_atlas`
const WallFaceImage : u32 = 5u;

fn DepthDenominatorRows() -> u32 {
    return u32(params.map_size.x + params.map_size.y + DepthHeadroomRows);
}

//Nearness to depth, the same expression the entity shader evaluates.
fn NearnessToDepth(nearness: f32) -> f32 {
    return (nearness * KeysPerPixel + 64.0) / f32(DepthDenominatorRows() * KeysPerRowPair);
}

//`front_ground` is the height of the ground in front of a wall face (0 for
//everything else); it is stored in FrontStep steps and clamped to FrontMax.
fn PackDepthInfo(image: u32, mode: u32, offset_x: f32, run: u32, front_ground: f32) -> u32 {
    var offset_code = 0u;
    if (offset_x > 0.0) {
        offset_code = 1u;
    } else if (offset_x < 0.0) {
        offset_code = 2u;
    }
    let front_code = u32(clamp(front_ground, 0.0, FrontMax) / FrontStep);
    return (image & ImageIndexMask)
        | (DepthDenominatorRows() << DenominatorShift)
        | (offset_code << OffsetShift)
        | (mode << ModeShift)
        | (run << RunShift)
        | (front_code << FrontShift);
}

//The ground a face's straight foot is drawn over, as the vertex stage unpacks
//it again.
fn UnpackFrontGround(info: u32) -> f32 {
    return f32((info >> FrontShift) & FrontMask) * FrontStep;
}

//=============================================================================
// Compute Shader Functions
//=============================================================================
//row-major index = y * map_size.x + x (mirrors cs_core map_pos_to_index); the
//rotation/visible-row helpers below additionally assume a square map.
fn index_to_world_pos(index: u32) -> vec2<i32> {
    var x : i32 = i32(index % u32(params.map_size.x));
    var y : i32 = i32(index / u32(params.map_size.x));
    return vec2<i32>(x, y);
}

fn u8_to_i8(value: u32) -> f32 {
    if ((value & 0x80u) != 0u) {
        // If the highest bit is set, it's a negative number in i8 terms.
        return f32(value) - 256.0;
    } else {
        return f32(value);
    }
}

fn is_in_map_bounds(map_position: vec2<i32>) -> i32 {
	if(map_position.x >= 0 && map_position.y >= 0 && map_position.y < params.map_size.y && map_position.x < params.map_size.x) { return 1; }

	return 0;
}

fn calculate_rows(start: vec2<i32>, mapSizeX: i32) -> i32{
	var rows = 0;

	if (start.y < start.x)
	{
	    rows = (mapSizeX - 1) - (start.x - start.y);
	}else {
     	rows = (mapSizeX - 1) + (start.y - start.x);
    }

	if (rows < 0) {
	    return 0;
	}

	return rows;
}

fn get_columns_until_border(index: vec2<i32>) -> i32{
	if (index.x < index.y)
	{
		return index.x;
	}
	return index.y;
}

fn is_outside_of_map(start_pos: vec2<i32>) -> i32 {
        var pos = start_pos;
        for (var i: i32 = 0; i < params.columns; i+=1){
            pos.x += 1;
            pos.y += 1;
            if (is_in_map_bounds(pos) == 1) {
                return 0;
            }
        }
        return 1;
}

fn calc_start_point_outside_map(start_pos: vec2<i32>) -> vec2<i32> {
        var start = start_pos;
        //above right side of map
        if (params.start_pos.x + params.start_pos.y < params.map_size.x) {
                   var left: vec2<i32> = vec2<i32>(params.start_pos.x - (params.rows - 1), params.start_pos.y + (params.rows - 1));
                   left.x += left.y;
                   left.y -= left.y;

                   var right_bottom_screen: vec2<i32> = vec2<i32>(params.start_pos.x + (params.columns - 1), params.start_pos.y + (params.columns - 1));
                   //check if we are passed the last Tile for MapSizeX with the Camera
                   if (right_bottom_screen.x + right_bottom_screen.y > params.map_size.x) {
                       start = vec2<i32>(params.map_size.x, 0);

                   } else {
                        //we are above the Last Tile so x < MapSizeX for Camera right bottom Position
                       right_bottom_screen.x += right_bottom_screen.y;
                       right_bottom_screen.y -= right_bottom_screen.y;
                       start = right_bottom_screen;
                   }

                   //difference is all tiles on the x axis and because we calculate here x,y different to Isomectric View we need to divide by 2 and for odd number add 1 so % 2
                   var difference = start.x - left.x;
                   difference += difference % 2;
                   difference /= 2;
                   start.x -= difference;
                   start.y -= difference;
                   return start;
       }
       //underneath right side of map
       let to_the_left = params.start_pos.x - params.map_size.x;
       return vec2<i32>(params.start_pos.x - to_the_left, params.start_pos.y + to_the_left);
}

fn get_start_point(start_pos: vec2<i32>) -> vec2<i32> {
      var outside = is_outside_of_map(start_pos);
      if (outside == 1) { //calculate the starting point when outside of map on the right.
        return calc_start_point_outside_map(start_pos);
      }
     //inside the map
     return vec2<i32>(params.start_pos.x, params.start_pos.y);
}

fn calc_visible_index(index: vec2<i32>, actual_row_start: vec2<i32>) -> i32{

        let start = get_start_point(vec2<i32>(params.start_pos.x, params.start_pos.y));
        let rows_behind = calculate_rows(index, params.map_size.x) - calculate_rows(start, params.map_size.x);

        var visible_index = rows_index.Rows[rows_behind];

        //index in current column
        var columns = get_columns_until_border(index);
        if (actual_row_start.x >= 0 && actual_row_start.y >= 0) {
            columns -= get_columns_until_border(actual_row_start);
        }

        visible_index += columns;
        return visible_index;
}

fn WorldToScreenPos(world_pos: vec2<i32>) -> vec2<f32>{
	var screenPos: vec2<f32>;
	screenPos.x = f32(TileSizeHalf.x * world_pos.x - TileSizeHalf.x * world_pos.y);
    screenPos.y = f32(TileSizeHalf.y * world_pos.x + TileSizeHalf.y * world_pos.y + TileSizeHalf.x);


	return screenPos;
}

fn initInstancingObject() -> InstancingObject {
    var obj: InstancingObject;
    obj.Position = vec3<f32>(0.0, 0.0, -10.0);
    obj.image_index = 0u;
    obj.UvCoordPos = vec2<f32>(0.0, 0.0);
    obj.UvCoordSize = 0u;
    obj.Color = 0u;
    return obj;
}

//=============================================================================
// Wind
//=============================================================================
//The wind is PURE PRESENTATION: it only decides WHEN a tile shows which atlas
//frame, it never touches simulation state, so floats and real-time-looking
//maths are legal here where the sim forbids them. Nothing below is read back by
//anything. `cs_renderer::wind` mirrors every formula of this block in Rust and
//its tests count what the model does; change the two together.
//
//WHAT THE FRAME PICKER CAN DO decides the whole model. A tile shows its REST
//frame for the whole pause section of its cycle and plays its swing loop during
//the moving section (`assets/world/animation/animated_tile.data`: grass plays a
//5-frame loop 4 times out of a 120-frame cycle, a tree a 16-frame loop twice out
//of 108). There is no amplitude to scale — a plant either swings or stands. So a
//gust can only be expressed as WHO swings, WHEN, and for HOW MANY repetitions of
//the loop, and a calm as: nobody starts.
//
//The model is a gust PASS. A front travels along the wind; the tick it sweeps a
//tile starts that tile's pass. Inside its pass a tile plays its swing once — as
//many repetitions of the loop as the gust there is strong — and rests for the
//remainder. WHO swings at all is a patch field (a value noise in the wind's own
//frame, reseeded every pass) times a spell (a slow drift shared by the whole
//map), so several separate places gust at once and whole spells pass in which
//nothing moves at all.
//
//What this replaced: one global clock plus a fixed per-tile phase, i.e. a single
//straight band of motion, infinitely long across the map, repeating every 96
//cells, that swept over every plant exactly once every 18.75 s and never stopped.
//
//It blows in MAP space, so turning the camera turns the gust with the world
//instead of dragging it along. (2,-1) normalised sweeps almost horizontally
//across the isometric screen, tilted slightly down.
const WindDirX : f32 = 0.8944272;
const WindDirY : f32 = -0.4472136;
const WindDirection = vec2<f32>(WindDirX, WindDirY);
//Across the wind, for the patch lattice. Right-hand normal of WindDirection.
const WindRight = vec2<f32>(-WindDirY, WindDirX);

//--- the knobs, in the order you would turn them -----------------------------
//How long one gust pass lasts at a single tile, in sim ticks (the sim runs at
//64 Hz), i.e. the SHORTEST gap between two swings of the same plant. A tile the
//patch field skips waits a whole further pass. 512 ticks = 8 s.
const WindPassTicks : u32 = 512u;
//How far the gust front travels in one pass, in CELLS. With the pass length
//above this is the front's SPEED: 96 cells per 8 s = 12 cells per second. Fixed
//in cells, never derived from the map size: a wind whose front crawls on a
//bigger map is not a wind.
const WindFrontCells : f32 = 96.0;
//Size of one gusty patch in CELLS, measured in the wind's own frame — longer
//along the wind than across it, because wind over a field comes in streaks, not
//in blobs. Small values scatter the map into confetti, values past the screen
//(about 64 cells wide at zoom 1) put the whole view in one state.
const WindPatchLengthCells : f32 = 40.0;
const WindPatchWidthCells : f32 = 22.0;
//How strong a place must be before its plants swing at all. UP = fewer, smaller,
//further apart gusty patches and longer calms; 0 = every plant swings every pass
//and the map is back to one solid band.
const WindGustThreshold : f32 = 0.30;
//How far ABOVE the threshold counts as a full gust — the strength at which a
//plant plays every repetition of its loop instead of a single one. Small = the
//wind is mostly all or nothing, large = mostly single shivers.
const WindFullGust : f32 = 0.25;
//How far one plant may disagree with the patch it stands in, as a share of the
//strength range. It frays the patch EDGE so no straight cut runs through the
//grass; it has to stay small or the patch dissolves into per-tile noise.
const WindEdgeSoftness : f32 = 0.18;
//The weather: how many passes one spell lasts (4 passes = 32 s) and how weak the
//weakest spell gets. The spell scales every patch on the map at once — this, not
//the patch field, is what makes the wind die down EVERYWHERE and pick up again.
//A floor of 1.0 switches the weather off and leaves only the patches.
const WindSpellPasses : u32 = 4u;
const WindSpellFloor : f32 = 0.38;
//----------------------------------------------------------------------------
//The pass a tile is in is found with INTEGER ticks, so nothing drifts after
//hours of play (an f32 built from the raw tick loses its steps after about a
//day and the animation would quietly freeze). Two helpers for that: the origin
//puts the front's coordinate far enough outside every map that it is never
//negative, and the bias keeps `tick + bias - delay` from wrapping. The delay is
//at most (origin + map extent) * WindPassTicks / WindFrontCells ~ 22000 ticks,
//well inside the bias.
const WindOriginCells : f32 = 4096.0;
const WindTickBias : u32 = 4194304u;
//Animation ticks per sim tick: the unit the `Delay` of animated_tile.data is
//counted in. Delay 100 is one frame per 10 sim ticks.
const AnimationTicksPerTick : u32 = 10u;

//A cheap integer hash, used for nothing but scattering gusts.
fn hashTile(pos: vec2<i32>) -> f32 {
    var h = (u32(pos.x) * 0x27d4eb2du) ^ (u32(pos.y) * 0x9e3779b9u);
    h = h ^ (h >> 15u);
    h = h * 0x85ebca6bu;
    h = h ^ (h >> 13u);
    return f32(h >> 8u) / 16777216.0;
}

//The same hash over three words: a lattice corner plus the pass that reseeds it.
fn windHash(a: u32, b: u32, c: u32) -> f32 {
    var h = (a * 0x27d4eb2du) ^ (b * 0x9e3779b9u) ^ (c * 0x85ebca6bu);
    h = h ^ (h >> 15u);
    h = h * 0x2545f491u;
    h = h ^ (h >> 13u);
    return f32(h >> 8u) / 16777216.0;
}

//How many sim ticks this tile lies BEHIND the gust front. An integer, so the
//pass index and the tick inside the pass stay exact for the whole run.
fn windDelayTicks(pos: vec2<i32>) -> u32 {
    let along = WindOriginCells - dot(vec2<f32>(pos), WindDirection);
    return u32(max(along, 0.0) * (f32(WindPassTicks) / WindFrontCells));
}

//How hard the gust of `gust_pass` blows at `pos`, 0..1. A value noise on a
//lattice laid out in the wind's own frame — reseeded every pass, so the gusty
//places move — scaled by the spell, a slower value noise over the pass index
//that lets the whole map calm down and pick up again.
fn windStrength(pos: vec2<i32>, gust_pass: u32) -> f32 {
    let p = vec2<f32>(pos);
    let c = vec2<f32>(dot(p, WindDirection) / WindPatchLengthCells,
                      dot(p, WindRight) / WindPatchWidthCells);
    let corner = floor(c);
    let f = c - corner;
    //smoothstep weights: a linear blend would show the lattice as creases
    let w = f * f * (3.0 - 2.0 * f);
    let i = vec2<u32>(bitcast<u32>(i32(corner.x)), bitcast<u32>(i32(corner.y)));
    let a = windHash(i.x, i.y, gust_pass);
    let b = windHash(i.x + 1u, i.y, gust_pass);
    let d = windHash(i.x, i.y + 1u, gust_pass);
    let e = windHash(i.x + 1u, i.y + 1u, gust_pass);
    let gust_patch = mix(mix(a, b, w.x), mix(d, e, w.x), w.y);

    let spell_index = gust_pass / WindSpellPasses;
    let spell_step = f32(gust_pass % WindSpellPasses) / f32(WindSpellPasses);
    let s0 = windHash(spell_index, 0x5bf03635u, 0u);
    let s1 = windHash(spell_index + 1u, 0x5bf03635u, 0u);
    let spell = mix(s0, s1, spell_step * spell_step * (3.0 - 2.0 * spell_step));
    return gust_patch * mix(WindSpellFloor, 1.0, spell);
}

//Which frame of its OWN animation a wind tile shows, in [0, cycle). `loop_len`
//is one repetition of the swing, `moving` the whole swing (the loop times its
//repetitions), `delay` the authored animation ticks per frame. `moving` is
//returned for "resting": every frame from there to the end of the cycle draws
//the untouched atlas frame, and so does frame 0, which is why a pass boundary —
//where one tile has just finished its swing and its neighbour is about to start
//— shows no seam.
fn windFrame(pos: vec2<i32>, tick: u32, loop_len: u32, moving: u32, delay: u32) -> u32 {
    if (loop_len == 0u || moving == 0u || delay == 0u) {
        return moving;
    }
    let local = tick + WindTickBias - windDelayTicks(pos);
    //frames since the front reached this tile, at the speed the artist authored
    let frame = ((local % WindPassTicks) * AnimationTicksPerTick) / delay;
    //past its own swing: resting — where three fifths of the grass and three
    //eighths of the trees sit at any tick, and the gust field below is never
    //read for them
    if (frame >= moving) {
        return moving;
    }
    let gust_pass = local / WindPassTicks;
    let strength = windStrength(pos, gust_pass);
    //the patch edge frayed per tile, so no straight cut runs through the grass
    let gate = WindGustThreshold + (hashTile(pos) - 0.5) * WindEdgeSoftness;
    if (strength <= gate) {
        return moving;
    }
    //how hard it blows here decides how many repetitions of the loop this plant
    //plays: one shiver in a breath of wind, the whole swing in a real gust
    let repeats = moving / loop_len;
    let excess = clamp((strength - gate) / WindFullGust, 0.0, 1.0);
    let played = min(1u + u32(excess * f32(repeats)), repeats);
    if (frame >= loop_len * played) {
        return moving;
    }
    return frame;
}

fn applyRotation(map_pos: vec2<i32>) -> vec2<i32> {
    //rotation
    if (params.direction == 0u) {
        return map_pos;
    } else if(params.direction == 1u) {
        return vec2<i32>(params.map_size.x - map_pos.y - 1, map_pos.x);
    } else if(params.direction == 2u) {
        return vec2<i32>(params.map_size.x - map_pos.x - 1, params.map_size.y - map_pos.y - 1);
    }
    return vec2<i32>(map_pos.y, params.map_size.y - map_pos.x - 1);
}

fn CaclAnimationFrame(instance: SingleInstance, animation_enabled: u32, tick: u32, pos: vec2<i32>) -> u32{
	//Animation: u32 1 for Wind // 7 bits for animation length // 12 bits for when update animation // 5 bits repeat frames // 7 bits pausing frames TODO
    if (animation_enabled == 0u){
        return instance.AtlasCoordPos;
    }

    var atlas_pos = instance.AtlasCoordPos;
    let animation_length =  u32((instance.Animation >> 24u) & 0x0000007fu);
    let reiteration =  u32((instance.Animation >> 7u) & 0x0000001fu);
    let pausing_frames =  u32(instance.Animation & 0x0000007fu) * 2u;
    let update_tick =  u32((instance.Animation >> 12u) & 0x00000fffu);
    let uv_size = vec2<u32>(instance.atlas_coord_size & 0x0000ffffu, instance.atlas_coord_size >> 16u);
    let animation_length_wih_reiterattions = animation_length + animation_length * reiteration;
    let cycle_frames = animation_length_wih_reiterattions + pausing_frames;

    //water and the disabled-building blink are not wind: they keep the plain
    //steady ramp, only wind tiles are handed to the gust model.
    var animation_tick = tick * AnimationTicksPerTick;
    // wind animation
    if (instance.Animation >> 31u == 1u){
        //the gust names the FRAME outright, so grass and a tree next to it
        //start their swing on the same tick and each then takes its own
        //authored time (grass 3.1 s, a tree 5.0 s). Multiplying by update_tick
        //undoes the division below exactly — this is the frame, not a clock.
        animation_tick = windFrame(pos, tick, animation_length,
                                   animation_length_wih_reiterattions, update_tick) * update_tick;
    }

    let is_update_time = animation_tick / update_tick;
    let img_coord = is_update_time % cycle_frames;
    if(img_coord < animation_length_wih_reiterattions){
        let current_pos_x = (atlas_pos & 0x00000fffu);
        let new_pos_x = current_pos_x + (uv_size.x * (img_coord % animation_length));
        let end_pixels = (u32(ImageSize.x) - current_pos_x) % uv_size.x;
        let real_size = u32(ImageSize.x) - end_pixels;
        let pos_y = (new_pos_x / real_size) * uv_size.y;
        let pos_x = new_pos_x % real_size - current_pos_x;

        atlas_pos += pos_x + (pos_y << 16u);
    }
    return atlas_pos;
}

fn CreateObjectInstance(tile_id: u32, map_pos: vec2<i32>, position: vec3<f32>, animation_enabled: u32, animation_tick: u32, color: u32) -> InstancingObject {
	var instance = tile_properties.properties[tile_id];
	var newInstance: InstancingObject;
	newInstance.Position = position;
	newInstance.image_index = instance.image_index;

	var atlas_pos = CaclAnimationFrame(instance, animation_enabled, animation_tick, map_pos);

	newInstance.UvCoordPos = vec2<f32>(f32(atlas_pos & 0x0000ffffu),f32(atlas_pos >> 16u)) / ImageSize;
	newInstance.UvCoordSize = instance.atlas_coord_size;
	newInstance.Color = color;
	return newInstance;
}

//Tile and Object
fn CreateBuildingInstance(tile_id: u32, world_pos: vec2<i32>, elevation: f32, animation_enabled: u32, animation_tick: u32, Color: u32, offsetObjectY: f32) -> InstancingObject{
    if (tile_id == 0u){
        return initInstancingObject();
    }
    let pos = applyRotation(world_pos);
	var position = WorldToScreenPos(pos);
	let recipe = 2.0 * position.y;
	position.y -= elevation + 7.0f;
	position.y -= offsetObjectY;
	var instance = CreateObjectInstance(tile_id, world_pos, vec3(position, recipe), animation_enabled, animation_tick, Color);
	instance.image_index = PackDepthInfo(instance.image_index, ModeBox, 0.0, 0u, 0.0);
	return instance;
}

//`run` is the RunLeft/RunRight mask of a wall face (0 for a cliff and for the
//brush preview) and `front_ground` the height of the ground the straight foot
//towards that run is drawn over
fn CreateElevationInstance(tile_id: u32, world_pos: vec2<i32>, elevation: f32, animation_enabled: u32, animation_tick: u32, Color: u32, offset_elevation_x: f32, run: u32, front_ground: f32) -> InstancingObject{
    if (tile_id == 0u){
        return initInstancingObject();
    }
    let pos = applyRotation(world_pos);
	var position = WorldToScreenPos(pos);
	let recipe = 2.0 * position.y;
	position.x += offset_elevation_x;
	var size = u32(elevation) + 16u;//TileSizeHalf
	var instance: InstancingObject  = CreateObjectInstance(tile_id, world_pos, vec3(position, recipe), animation_enabled, animation_tick, Color);
    instance.UvCoordSize = (instance.UvCoordSize & 0x0000ffffu) | (size << 16u);
	instance.image_index = PackDepthInfo(instance.image_index, ModeFace, offset_elevation_x, run, front_ground);
	return instance;
}

//`mode` is ModeGround or ModeBillboard
fn CreateSpecificInstance(tile_id: u32, world_pos: vec2<i32>, elevation: f32, animation_enabled: u32, animation_tick: u32, Color: u32, mode: u32) -> InstancingObject{
	if (tile_id == 0u){
	    return initInstancingObject();
	}
	let pos = applyRotation(world_pos);
	var position = WorldToScreenPos(pos);
	var recipe = 2.0 * elevation;
	if (mode == ModeBillboard) {
	    recipe = 2.0 * position.y;
	}
	position.y -= elevation;
	var instance = CreateObjectInstance(tile_id, world_pos, vec3(position, recipe), animation_enabled, animation_tick, Color);
	instance.image_index = PackDepthInfo(instance.image_index, mode, 0.0, 0u, 0.0);
	return instance;
}


//=============================================================================
// Compute Shader
//=============================================================================
struct SingleInstance
{//TODO add color here and TileData can be lessed
	image_index: u32,//maybe here tile on top offset -16 + 16 or 0 so i can squeeze texture atlas more
	Animation: u32,// 1 bit wind animation // 7 bits for animation length // 12 bits for when update animation // 5 bits repeat frames // 7 bits pausing frames
    AtlasCoordPos: u32, //x/y for column/row z/w for image index
	atlas_coord_size: u32,
};

struct TilePropertiesStorage {
  properties: array<SingleInstance>,
};

struct TilesBehindStorage {
  Rows: array<i32>,
};

struct TileDataStorage {
  tiles: array<TileData>,
};

struct TileRotationDataStorage {
  tiles: array<TileRotationData>,
};

struct InstancingObjectStorage {
  tiles: array<InstancingObject>,
};

struct ComputeParams {
    start_pos: vec2<i32>,
    map_size: vec2<i32>,
    columns: i32,
    rows: i32,
    tick: u32,
    direction: u32
};

//12 + 4 + 8 + 4 + 4 = 32 bytes;
struct InstancingObject
{
    Position: vec3<f32>,
	image_index: u32,
	UvCoordPos: vec2<f32>,
	UvCoordSize: u32,
	Color: u32,
};

//4 * 4 = 16 bytes
struct TileData
{//TODO make less bytes
	TileIndex: u32,//used in update and BrusPreview Buffer
	Color: u32,//used in BrusPreview Buffer
	MiniMapColor: u32,//used in Update Minimap Buffer
	Elevation: f32,
};

//4 * 8 = 32 bytes
struct TileRotationData
{//TODO make less bytes
    Data: u32,//16 bits for ObjectY //8 bit AnimationData //8 bit OffsetElevationX
    SingleInstances: array<u32, 6>,
    Free: u32
};


@group(0) @binding(0) var<uniform> params: ComputeParams;
@group(0) @binding(1) var<storage, read> rows_index : TilesBehindStorage;
@group(1) @binding(0) var<storage, read> tile_properties : TilePropertiesStorage;


