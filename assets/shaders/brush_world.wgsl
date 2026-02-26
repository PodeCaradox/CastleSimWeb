#import world_utils

struct BrushParamsCompute
{
     build_able: u32,
     brush_instance_not_buildable: u32,
     draw_map_behind: u32,
     visible_index: u32,
     instances_to_draw: u32,
     show_offset: u32
};

@group(2) @binding(0) var<uniform> brush_params: BrushParamsCompute;
@group(2) @binding(1) var<storage, read> brush_tiles_data : world_utils::TileDataStorage;
@group(2) @binding(2) var<storage, read> brush_tiles_rotation : world_utils::TileRotationDataStorage;
@group(3) @binding(0) var<storage, read_write> visble_tiles_cp : world_utils::InstancingObjectStorage;

@compute
@workgroup_size(16, 1, 1)
fn instancing_cs_brush(@builtin(global_invocation_id) global_id: vec3<u32>) {
    if (global_id.x >= brush_params.instances_to_draw) {
        return;
    }
    let brush_tile_data = brush_tiles_data.tiles[global_id.x];

    let index = index_to_world_pos(brush_tile_data.TileIndex);

    if  (brush_params.draw_map_behind == 0u && brush_params.build_able == 1u){
      let tiles_y: i32 = (params.start_pos.x - params.start_pos.y) - (index.x - index.y);
        let column = tiles_y / 2 + tiles_y % 2;
        var actual_row_start = vec2(params.start_pos.x, params.start_pos.y + tiles_y);
        actual_row_start.y -= column;
        actual_row_start.x -= column;
        let index_to_delete = calc_visible_index(index, actual_row_start) * i32(brush_params.show_offset);
         for (var y : i32 = 0; y < i32(brush_params.show_offset); y = y + 1) {
            visble_tiles_cp.tiles[index_to_delete + y] = initInstancingObject();
         }
    }



    var elevation : f32 = brush_tile_data.Elevation;
    let pos = index_to_world_pos(brush_tile_data.TileIndex);
	if(brush_params.build_able == 1u){
	   var visible_index : u32 = brush_params.visible_index + global_id.x * 4u;

       let brush_tile_rotation = brush_tiles_rotation.tiles[global_id.x * 4u + params.direction];

       var animation = (brush_tile_rotation.Data >> 8u) & 0x000000ffu;
       var animation_enabled = animation & 0x00000001u;

       var offset_object_y = f32(brush_tile_rotation.Data >> 16u);
       var offset_elevation_x = u8_to_i8(brush_tile_rotation.Data & 0x000000ffu);


        visble_tiles_cp.tiles[visible_index] = CreateSpecificInstance(brush_tile_rotation.SingleInstances[0u], index, elevation, animation_enabled, 0u, brush_tile_data.Color);
        visble_tiles_cp.tiles[visible_index + 1u] = CreateSpecificInstance(brush_tile_rotation.SingleInstances[1u], index, elevation, animation_enabled, 0u, brush_tile_data.Color);
        visble_tiles_cp.tiles[visible_index + 1u].Position.z -= ZStep *  2.0;
        visble_tiles_cp.tiles[visible_index + 2u] = CreateBuildingInstance(brush_tile_rotation.SingleInstances[2u], index, elevation, animation_enabled, 0u, brush_tile_data.Color, offset_object_y);
        visble_tiles_cp.tiles[visible_index + 3u] = CreateElevationInstance(brush_tile_rotation.SingleInstances[3u], index, elevation, animation_enabled, 0u, brush_tile_data.Color, offset_elevation_x);

		return;
	}

	var visible_index : u32 = brush_params.visible_index + global_id.x;
    visble_tiles_cp.tiles[visible_index] = CreateSpecificInstance(brush_params.brush_instance_not_buildable, index, elevation, 0u, 0u, brush_tile_data.Color);
}