#define_import_path world_utils
const TileSizeHalf = vec2<i32>(32,16);
const ImageSize = vec2<f32>(2048.0,2048.0);

//Draw order: depth is NEARNESS per pixel, the map y of the ground point a pixel shows plus its
//height (a surface y + 2e, a billboard 2f - y, a face 2v(x) - y); `cs_renderer::depth_order`
//mirrors it. `Position.z` is the recipe of the mode packed into `image_index`.
const ImageIndexMask : u32 = 0x3fu; //bits 0-5: the environment atlas layer
//the layer of wall.png in the environment atlas (cs_initializer's init_images order); ground art
//from it stands on its cell, as does any tile whose .data says "StandsUp": true (E158)
const WallAtlasLayer : u32 = 1u;
//that per-tile knob, as it arrives from the CPU: bit 31 of a tile property's
//`image_index` (PropertyShaderInstance::STANDS_UP). PackDepthInfo keeps
//ImageIndexMask of the layer, so the bit never reaches the sampler.
const StandsUpBit : u32 = 0x80000000u;
//and where CreateSpecificInstance puts it in a ground quad's depth word: the lowest bit of the
//FrontShift field, which a ground quad packs as 0; read in fs_main under the mode test
const StandsUpFlag : u32 = 1u << 24u;
const DenominatorShift : u32 = 8u; //bits 8-19: depth denominator / 512
const DenominatorMask : u32 = 0xfffu;
const OffsetShift : u32 = 20u; //bits 20-21: a face piece's x offset (0, +16, -16)
const ModeShift : u32 = 22u; //bits 22-23: the mode
const RunShift : u32 = 6u; //bits 6-7: the face's run to its left / right neighbour
const FrontShift : u32 = 24u; //bits 24-31: the ground in front of a face, in FrontStep steps
const FrontMask : u32 = 0xffu;
//the elevation brush's step, so every height the editor makes is stored exactly; FrontMax =
//FrontMask * FrontStep = 1020 px, twice the editor's highest ground. A face told a ground it cannot
//name keeps the box's V, which covers nothing standing there.
const FrontStep : f32 = 4.0;
const FrontMax : f32 = 1020.0;
//Position.z = 2 * elevation; nearness = y + Position.z
const ModeGround : u32 = 0u;
//Position.z = 2 * foot row; nearness = Position.z - y (trees, bushes)
const ModeBillboard : u32 = 1u;
//Position.z = 2 * the cell's front tip row (map y, before the lift); the front edges' V is
//v(x) = tip - |x - apex| / 2, nearness Position.z - |x - apex| - y: a building slice
const ModeBox : u32 = 2u;
//ModeBox, but the pixels above the plateau's front edges (its painted lower half) are discarded,
//and towards a run neighbour the pixels below the V are the wall's thickness, nearness y + 2F + 1/2
//over the ground F in front: a straight foot at every height, under every unit standing on it
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

//Compute shader functions. Row-major index = y * map_size.x + x (cs_core's map_pos_to_index); the
//rotation and visible-row helpers below assume a square map.
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
                        //we are above the Last Tile so x < MapSizeX for Camera right bottom
                        //Position
                       right_bottom_screen.x += right_bottom_screen.y;
                       right_bottom_screen.y -= right_bottom_screen.y;
                       start = right_bottom_screen;
                   }

                   //difference is all tiles on the x axis and because we calculate here x,y
                   //different to Isomectric View we need to divide by 2 and for odd number add 1 so
                   //% 2
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

//Wind: pure presentation, it only picks WHEN a tile shows which atlas frame, so floats are fine
//here; `cs_renderer::wind` mirrors this block. A front along the wind starts each tile's pass, and
//a patch noise times a map-wide spell decides who swings and how much. It blows in map space.
const WindDirX : f32 = 0.8944272;
const WindDirY : f32 = -0.4472136;
const WindDirection = vec2<f32>(WindDirX, WindDirY);
//Across the wind, for the patch lattice. Right-hand normal of WindDirection.
const WindRight = vec2<f32>(-WindDirY, WindDirX);

//The knobs. How long one gust pass lasts at a tile, in sim ticks (64 Hz): the shortest gap between
//two swings of one plant; a tile the patch field skips waits a whole further pass. 512 = 8 s.
const WindPassTicks : u32 = 512u;
//How far the front travels in one pass, in cells: 96 per 8 s is 12 cells a second, fixed in cells
//and never derived from the map size.
const WindFrontCells : f32 = 96.0;
//One gusty patch in cells, in the wind's own frame, longer along the wind than across it (streaks);
//smaller scatters the map, past the screen (about 64 cells) the whole view is in one state.
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
//The weather: passes per spell (4 = 32 s) and how weak the weakest spell gets. The spell scales
//every patch at once, which makes the wind die down everywhere; a floor of 1.0 switches it off.
const WindSpellPasses : u32 = 4u;
const WindSpellFloor : f32 = 0.38;
//The pass is found with integer ticks, so nothing drifts over hours of play: the origin keeps the
//front's coordinate positive on every map, the bias keeps `tick + bias - delay` from wrapping.
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

//How hard the gust of `gust_pass` blows at `pos`, 0..1: value noise on a lattice in the wind's own
//frame, reseeded every pass, times the spell, a slower noise over the pass index.
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

//Which frame of its own animation a wind tile shows, in [0, cycle): `loop_len` is one repetition,
//`moving` the whole swing, `delay` the authored ticks per frame. `moving` means resting: it and
//frame 0 draw the untouched atlas frame, so a pass boundary shows no seam.
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
	//Animation: u32 1 for Wind // 7 bits for animation length // 12 bits for when update animation //
	//5 bits repeat frames // 7 bits pausing frames TODO
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
        //the gust names the frame outright, so grass and a tree beside it start on the same tick
        //and each takes its own authored time; multiplying by update_tick undoes the division below
        //exactly
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

//`run` is the RunLeft/RunRight mask of a face, a wall's or a cliff's (0 for the brush preview), and
//`front_ground` the height of the ground its straight foot towards that run is drawn over
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
	let stands_up = instance.image_index & StandsUpBit;
	instance.image_index = PackDepthInfo(instance.image_index, mode, 0.0, 0u, 0.0);
	//the tile's own StandsUp knob, moved from the layer word into the depth
	//word. Only a GROUND quad: a billboard shares this function and is
	//another mode, and the flag's bit belongs to a FACE there.
	if (mode == ModeGround && stands_up != 0u) {
	    instance.image_index |= StandsUpFlag;
	}
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


