//4 * 4 = 16 bytes
struct TileData
{
	TileIndex: u32,
	Color: u32,//Shadow Color
	MiniMapColor: u32,
	Elevation: f32,
};

//4 * 8 = 32 bytes
struct TileRotationData
{
    Data: u32,//16 bits for ObjectY //8 bit AnimationData //8 bit OffsetElevationX
    SingleInstances: array<u32, 6>,
    Free: u32
};

struct ComputeParams {
    instances_to_update: i32,
    map_size_offset: u32,
};

struct TileDataStorage {
  tiles: array<TileData>,
};

struct TileRotationDataStorage {
  tiles: array<TileRotationData>,
};

@group(0) @binding(0) var<uniform> params: ComputeParams;
@group(1) @binding(0) var<storage, read> update_tiles_data : TileDataStorage;
@group(1) @binding(1) var<storage, read> update_tiles_rotation : TileRotationDataStorage;
@group(2) @binding(0) var<storage, read_write> all_tiles_data : TileDataStorage;
@group(2) @binding(1) var<storage, read_write> all_tiles_rotation : TileRotationDataStorage;

@compute
@workgroup_size(16, 1, 1)
fn update_world(@builtin(global_invocation_id) global_id: vec3<u32>) {
    if (global_id.x >= u32(params.instances_to_update)) {
        return;
    }
	var tile: TileData = update_tiles_data.tiles[global_id.x];
    all_tiles_data.tiles[tile.TileIndex] = tile;

    for(var i = 0u; i < 4u; i++){
        all_tiles_rotation.tiles[tile.TileIndex + params.map_size_offset * i] = update_tiles_rotation.tiles[global_id.x * 4u + i];
    }

}