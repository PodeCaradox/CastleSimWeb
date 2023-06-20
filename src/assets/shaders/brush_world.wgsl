const TileSizeHalf = vec2<i32>(16,8);
const ImageSize = vec2<f32>(2048.0,2048.0);
const ZStep : f32 = 0.0000001;

//4*4 = 16
struct SingleInstance
{
	Index: u32,//image Index
	Animation: u32,// 1 for Activated // 7 bits for animation length // 12 bits for when update animation // 12 pausing frames TODO
    AtlasCoordPos: u32, //x/y for column/row z/w for image index
	AtlasCoordSize: u32,
};

//4 * 12 = 48 //always dividable by 16
struct TileInstances
{
	Index: u32,
	Color: u32,
	MiniMapColor: u32,
	AnimationOffsetTick: u32,// to set the delays for wind
	ElevationAndOffsetObjectY: u32,//16 bits for Elevation // 16 for OffsetObjectY
	OffsetElevationX: f32,
	SingleInstances: array<u32, 6>,
};

//12 + 4 + 8 + 4 + 4 = 32;
struct InstancingObject
{
    Position: vec3<f32>,
	Index: u32,
	UvCoordPos: vec2<f32>,
	UvCoordSize: u32,
	Color: u32,
};

struct TilePropertiesStorage {
  properties: array<SingleInstance>,
};

struct TileInstancesStorage {
  tiles: array<TileInstances>,
};

struct InstancingObjectStorage {
  tiles: array<InstancingObject>,
};

struct TilesBehindStorage {
  Rows: array<i32>,
};

//=============================================================================
// Compute Shader Functions
//=============================================================================
fn index_to_world_pos(index: u32) -> vec2<i32> {
    var x : i32 = i32(index % u32(params.map_size.x));
    var y : i32 = i32(index / u32(params.map_size.y));
    return vec2<i32>(x, y);
}

fn is_in_map_bounds(map_position: vec2<i32>) -> i32 {
	if(map_position.x >= 0 && map_position.y >= 0 && map_position.y < params.map_size.y && map_position.x < params.map_size.x) { return 1; }

	return 0;
}

fn WorldPosToDepth(world_pos: vec2<i32>) -> f32{
	let size: f32 = f32(params.map_size.x * params.map_size.y);
	return 1.0f - f32(world_pos.y * params.map_size.x + world_pos.x) / size - ZStep;
}

fn WorldToScreenPos(world_pos: vec2<i32>) -> vec2<f32>{
	var screenPos: vec2<f32>;
	screenPos.x = f32(TileSizeHalf.x * world_pos.x - TileSizeHalf.x * world_pos.y);
    screenPos.y = f32(TileSizeHalf.y * world_pos.x + TileSizeHalf.y * world_pos.y + TileSizeHalf.x);
	return screenPos;
}

fn CreateObjectInstance(tile_id: u32, position: vec3<f32>, animation_tick: u32, color: u32) -> InstancingObject{
    var newInstance: InstancingObject;
    newInstance.Color = color;
    newInstance.Position.z = -10.0;
	if (tile_id == 0u){
	    return newInstance;
	}
	var instance = tile_properties.properties[tile_id];
	newInstance.Position = position;
	newInstance.Index = instance.Index;
	var atlas_pos = instance.AtlasCoordPos;
	//	Animation: u32,// 1 for Activated // 7 bits for animation length // 12 bits for when update animation TODO
	if (instance.Animation >> 31u == 1u){
	    let animation_length =  u32((instance.Animation >> 24u) & 0x0000007fu);
	    let pausing_frames =  u32(instance.Animation & 0x00000fffu);
	    let update_tick =  u32((instance.Animation >> 12u) & 0x00000fffu);
	    let uv_size = u32(instance.AtlasCoordSize & 0x0000ffffu);
	    let is_update_time = animation_tick / update_tick;
	    let img_coord = is_update_time % (animation_length + pausing_frames);
	    if(img_coord < animation_length){
	        atlas_pos += uv_size * img_coord;
	    }
	}

	newInstance.UvCoordPos = vec2<f32>(f32(atlas_pos & 0x0000ffffu),f32(atlas_pos >> 16u)) / ImageSize;
	newInstance.UvCoordSize = instance.AtlasCoordSize;
	newInstance.Color = color;
	return newInstance;
}

//Tile and Object
fn CreateBuildingInstance(tile_id: u32, world_pos: vec2<i32>, elevation: u32, animation_tick: u32, Color: u32) -> InstancingObject{
	let depth: f32 = WorldPosToDepth(world_pos);
	var position = WorldToScreenPos(world_pos);
	position.y -= f32(elevation) + 7.0f;;
	return CreateObjectInstance(tile_id, vec3(position, depth), animation_tick, Color);
}

fn CreateElevationInstance(tile_id: u32, world_pos: vec2<i32>, elevation: u32, animation_tick: u32, Color: u32, offset_elevation_x: f32) -> InstancingObject{
	let depth: f32 = WorldPosToDepth(world_pos) + ZStep;
	var position = WorldToScreenPos(world_pos);
	position.x += offset_elevation_x;
	var instance: InstancingObject  = CreateObjectInstance(tile_id, vec3(position, depth), animation_tick, Color);
	var size = (elevation + 7u);
	size += size % 4u;//because of zooming there needs to be a number which has no odd number when zommed out 2 times
    instance.UvCoordSize = (instance.UvCoordSize & 0x0000ffffu) | (size << 16u);
	return instance;
}

fn CreateSpecificInstance(tile_id: u32, world_pos: vec2<i32>, elevation: u32, animation_tick: u32, Color: u32) -> InstancingObject{
	let depth: f32 = WorldPosToDepth(world_pos);
	var position = WorldToScreenPos(world_pos);
	position.y -= f32(elevation);
	return CreateObjectInstance(tile_id, vec3(position, depth), animation_tick, Color);
}

struct ComputeParams {
    start_pos: vec2<i32>,
    map_size: vec2<i32>,
    columns: i32,
    rows: i32,
    tick: u32,
    offset: u32
};

struct BrushParamsCompute
{
     build_able: u32,
     brush_instance_not_buildable: u32,
     visible_index: u32,
     instances_to_draw: u32
};

@group(0) @binding(0) var<uniform> params: ComputeParams;
@group(1) @binding(0) var<storage, read> tile_properties : TilePropertiesStorage;
@group(2) @binding(0) var<uniform> brush_params: BrushParamsCompute;
@group(2) @binding(1) var<storage, read> brush_tiles : TileInstancesStorage;
@group(3) @binding(0) var<storage, read_write> visble_tiles_cp : InstancingObjectStorage;
@compute
@workgroup_size(16, 1, 1)
fn instancing_cs_brush(@builtin(global_invocation_id) global_id: vec3<u32>) {
if (global_id.x > brush_params.instances_to_draw) {
        return;
    }
	var tile: TileInstances = brush_tiles.tiles[global_id.x];

    var elevation : u32 = (tile.ElevationAndOffsetObjectY >> 16u);
    let pos = index_to_world_pos(tile.Index);
	if(brush_params.build_able == 1u){
		var visible_index : u32 = brush_params.visible_index + global_id.x * 4u;
       visble_tiles_cp.tiles[visible_index] = CreateSpecificInstance(tile.SingleInstances[0], pos, elevation, 0u, tile.Color);
       visble_tiles_cp.tiles[visible_index + 1u] = CreateSpecificInstance(tile.SingleInstances[1], pos, elevation, 0u, tile.Color);
       visble_tiles_cp.tiles[visible_index + 2u] = CreateBuildingInstance(tile.SingleInstances[2], pos, elevation, 0u, tile.Color);
       visble_tiles_cp.tiles[visible_index + 3u] = CreateElevationInstance(tile.SingleInstances[3], pos, elevation, 0u, tile.Color, tile.OffsetElevationX);
       visble_tiles_cp.tiles[visible_index + 3u].Position.z -= ZStep;
		return;
	}

	var visible_index : u32 = brush_params.visible_index + global_id.x;
    visble_tiles_cp.tiles[visible_index] = CreateSpecificInstance(brush_params.brush_instance_not_buildable, pos, elevation, 0u, tile.Color);
}