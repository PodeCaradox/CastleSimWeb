//4 * 12 = 48 //always dividable by 16
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
    all_tiles.tiles[tile.TileIndex] = tile;
}