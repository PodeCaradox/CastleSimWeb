#define_import_path common
//Shared constants, structs and functions that name no binding, so every shader can import
//them; world_utils builds on it with the bindings of the terrain and brush compute passes.

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

fn u8_to_i8(value: u32) -> f32 {
    if ((value & 0x80u) != 0u) {
        // If the highest bit is set, it's a negative number in i8 terms.
        return f32(value) - 256.0;
    } else {
        return f32(value);
    }
}

//The camera turns the MAP: a turned map draws cell `cell` where `rotate_cell(cell)` of the unturned
//map stands. `cs_initializer::geometry::rotate_cell` mirrors it: change both together.
fn rotate_cell(cell: vec2<i32>, map_size: vec2<i32>, direction: u32) -> vec2<i32> {
    if (direction == 0u) {
        return cell;
    } else if (direction == 1u) {
        return vec2<i32>(map_size.x - cell.y - 1, cell.x);
    } else if (direction == 2u) {
        return vec2<i32>(map_size.x - cell.x - 1, map_size.y - cell.y - 1);
    }
    return vec2<i32>(cell.y, map_size.y - cell.x - 1);
}

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

struct TileDataStorage {
  tiles: array<TileData>,
};

struct TileRotationDataStorage {
  tiles: array<TileRotationData>,
};
