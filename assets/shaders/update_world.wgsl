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

struct ComputeParams {
    instances_to_update: i32
};

struct TileInstancesStorage {
  tiles: array<TileInstances>,
};

@group(0) @binding(0) var<uniform> params: ComputeParams;
@group(1) @binding(0) var<storage, read> update_tiles : TileInstancesStorage;
@group(2) @binding(0) var<storage, read_write> all_tiles : TileInstancesStorage;

@compute
@workgroup_size(16, 1, 1)
fn update_world(@builtin(global_invocation_id) global_id: vec3<u32>) {
    if (global_id.x >= u32(params.instances_to_update)) {
        return;
    }
	var tile: TileInstances = update_tiles.tiles[global_id.x];
    all_tiles.tiles[tile.Index] = tile;
}