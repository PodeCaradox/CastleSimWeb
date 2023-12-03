const TileSizeHalf = vec2<i32>(16,8);
const ImageSize = vec2<f32>(2048.0,2048.0);
const ZStep : f32 = 0.0000001;

struct SingleInstance
{
	image_index: u32,
	Animation: u32,// 1 bit wind animation // 7 bits for animation length // 12 bits for when update animation // 5 bits repeat frames // 7 bits pausing frames
    AtlasCoordPos: u32, //x/y for column/row z/w for image index
	atlas_coord_size: u32,
};

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

//12 + 4 + 8 + 4 + 4 = 32 bytes;
struct InstancingObject
{
    Position: vec3<f32>,
	image_index: u32,
	UvCoordPos: vec2<f32>,
	UvCoordSize: u32,
	Color: u32,
};

struct TilePropertiesStorage {
  properties: array<SingleInstance>,
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

struct TilesBehindStorage {
  Rows: array<i32>,
};


//=============================================================================
// Compute Shader Functions
//=============================================================================
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

fn WorldPosToDepth(world_pos: vec2<i32>) -> f32{
	let size: f32 = f32(params.map_size.x * params.map_size.y);
	return 1.0f - f32(world_pos.y * params.map_size.x + world_pos.x) / size;
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

fn calculateValue(x: f32, mapSizeX: f32) -> f32 {
    var halfMapSizeX = mapSizeX / 2.0;
    var absDiff = abs(x - halfMapSizeX);
    var value = 1.0 + 2.0 * absDiff / mapSizeX;
    value = 1.0 - pow(value, 2.0);
    return value;
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

    var animation_tick = tick;
    // wind animation
    if (instance.Animation >> 31u == 1u){
       //animation_tick += u32(pos.y + params.map_size.y * 10 + (pos.y - params.map_size.y)) * 50u;
        animation_tick += u32(f32(pos.y + params.map_size.y) * 50.0 + calculateValue(f32(pos.x), f32(params.map_size.x)) * 1400.0);//pos.y * 50 +
    }

    var atlas_pos = instance.AtlasCoordPos;
    let animation_length =  u32((instance.Animation >> 24u) & 0x0000007fu);
    let reiteration =  u32((instance.Animation >> 7u) & 0x0000001fu);
    let pausing_frames =  u32(instance.Animation & 0x0000007fu) * 2u;
    let update_tick =  u32((instance.Animation >> 12u) & 0x00000fffu);
    let uv_size = vec2<u32>(instance.atlas_coord_size & 0x0000ffffu, instance.atlas_coord_size >> 16u);
    let is_update_time = animation_tick / update_tick;
    let animation_length_wih_reiterattions = animation_length + animation_length * reiteration;
    let img_coord = is_update_time % (animation_length_wih_reiterattions + pausing_frames);
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
	let depth: f32 = WorldPosToDepth(pos);
	var position = WorldToScreenPos(pos);
	position.y -= elevation + 7.0f;
	position.y -= offsetObjectY;
	return CreateObjectInstance(tile_id, world_pos, vec3(position, depth), animation_enabled, animation_tick, Color);
}

fn CreateElevationInstance(tile_id: u32, world_pos: vec2<i32>, elevation: f32, animation_enabled: u32, animation_tick: u32, Color: u32, offset_elevation_x: f32) -> InstancingObject{
    if (tile_id == 0u){
        return initInstancingObject();
    }
    let pos = applyRotation(world_pos);
	let depth: f32 = WorldPosToDepth(pos) + ZStep;
	var position = WorldToScreenPos(pos);
	position.x += offset_elevation_x;
	var size = u32(elevation) + 8u;
	var instance: InstancingObject  = CreateObjectInstance(tile_id, world_pos, vec3(position, depth), animation_enabled, animation_tick, Color);
    instance.UvCoordSize = (instance.UvCoordSize & 0x0000ffffu) | (size << 16u);
	return instance;
}

fn CreateSpecificInstance(tile_id: u32, world_pos: vec2<i32>, elevation: f32, animation_enabled: u32, animation_tick: u32, Color: u32) -> InstancingObject{
	if (tile_id == 0u){
	    return initInstancingObject();
	}
	let pos = applyRotation(world_pos);
	let depth: f32 = WorldPosToDepth(pos);
	var position = WorldToScreenPos(pos);
	position.y -= elevation;
	return CreateObjectInstance(tile_id, world_pos, vec3(position, depth), animation_enabled, animation_tick, Color);
}


//=============================================================================
// Compute Shader
//=============================================================================
struct ComputeParams {
    start_pos: vec2<i32>,
    map_size: vec2<i32>,
    columns: i32,
    rows: i32,
    tick: u32,
    direction: u32
};

@group(0) @binding(0) var<uniform> params: ComputeParams;
@group(0) @binding(1) var<storage, read> rows_index : TilesBehindStorage;
@group(1) @binding(0) var<storage, read> tile_properties : TilePropertiesStorage;
@group(2) @binding(0) var<storage, read> tiles_data : TileDataStorage;
@group(2) @binding(1) var<storage, read> tiles_rotation : TileRotationDataStorage;
@group(3) @binding(0) var<storage, read_write> visble_tiles_cp : InstancingObjectStorage;


@compute
@workgroup_size(16, 16, 1)
fn instancing_with_elevation(@builtin(global_invocation_id) global_id: vec3<u32>) {
            var index: vec2<i32> = vec2<i32>(params.start_pos.x, params.start_pos.y);
            let column = i32(global_id.x);
            var row = i32(global_id.y);

            index.x -= row % 2;
            row /= 2;
            index.y += row;
            index.x -= row;
            let actual_row_start = index;
            index.y += column;
            index.x += column;

            if (is_in_map_bounds(index) == 0) {
                return;
            }

            if (row >= params.rows || column >= params.columns){
                return;
            }

           let visible_index = calc_visible_index(index, actual_row_start) * 4;

           let rotation_offset = params.map_size.x * params.map_size.y * i32(params.direction);
           let tile_rotation_data = tiles_rotation.tiles[index.y * params.map_size.x + index.x + rotation_offset];
           let tile_data = tiles_data.tiles[index.y * params.map_size.x + index.x];
           
           let tick = params.tick;
           var animation = (tile_rotation_data.Data >> 8u) & 0x000000ffu;
           var animation_enabled = animation & 0x00000001u;

           var offset_object_y = f32(tile_rotation_data.Data >> 16u);
           var offset_elevation_x =  u8_to_i8(tile_rotation_data.Data & 0x000000ffu);


           visble_tiles_cp.tiles[visible_index] = CreateSpecificInstance(tile_rotation_data.SingleInstances[0u], index, tile_data.Elevation, animation_enabled, tick, 0xffffffffu);
           animation_enabled = ((animation >> 1u) & 0x00000001u);
           visble_tiles_cp.tiles[visible_index + 1] = CreateSpecificInstance(tile_rotation_data.SingleInstances[1u], index, tile_data.Elevation, animation_enabled, tick, 0xffffffffu);
           visble_tiles_cp.tiles[visible_index + 1].Position.z -= ZStep *  2.0;
           animation_enabled = ((animation >> 2u) & 0x00000001u);
           visble_tiles_cp.tiles[visible_index + 2] = CreateBuildingInstance(tile_rotation_data.SingleInstances[2u], index, tile_data.Elevation, animation_enabled, tick, 0xffffffffu, offset_object_y);
           animation_enabled = ((animation >> 3u) & 0x00000001u);
           visble_tiles_cp.tiles[visible_index + 3] = CreateElevationInstance(tile_rotation_data.SingleInstances[3u], index, tile_data.Elevation, animation_enabled, tick, 0xffffffffu, offset_elevation_x);
}

@compute
@workgroup_size(16, 16, 1)
fn instancing_without_elevation(@builtin(global_invocation_id) global_id: vec3<u32>) {
            var index: vec2<i32> = vec2<i32>(params.start_pos.x, params.start_pos.y);
            let column = i32(global_id.x);
            var row = i32(global_id.y);

            index.x -= row % 2;
            row /= 2;
            index.y += row;
            index.x -= row;
            let actual_row_start = index;
            index.y += column;
            index.x += column;

            if (is_in_map_bounds(index) == 0) {
                return;
            }

           let visible_index = calc_visible_index(index, actual_row_start) * 2;

           let rotation_offset = params.map_size.x * params.map_size.y * i32(params.direction);
           let tile_rotation_data = tiles_rotation.tiles[index.y * params.map_size.x + index.x + rotation_offset];

           let tick = params.tick;
           var animation = (tile_rotation_data.Data >> 8u) & 0x000000ffu;
           var animation_enabled = animation & 0x00000001u;

           visble_tiles_cp.tiles[visible_index] = CreateSpecificInstance(tile_rotation_data.SingleInstances[4u], index, 0.0, animation_enabled, tick, 0xffffffffu);
           animation_enabled = ((animation >> 1u) & 0x00000001u);
           visble_tiles_cp.tiles[visible_index + 1] = CreateSpecificInstance(tile_rotation_data.SingleInstances[5u], index, 0.0, animation_enabled, tick, 0xffffffffu);
           visble_tiles_cp.tiles[visible_index + 1].Position.z -= ZStep *  2.0;
}

//==============================================================================
// Vertex shader_bindings
//==============================================================================
//16 bytes
struct VertexInput {
    @location(0) Position: vec4<f32>,
    @builtin(instance_index) instance_index: u32,
}

// 16 byte + 16 byte + 12 bytes = 44 bytes
struct VertexOutput {
    @builtin(position) Position: vec4<f32>,
    @location(0) Color: vec4<f32>,
    @location(1) TexCoord : vec2<f32>,
    @location(2) @interpolate(flat)  image_index : u32,
}

struct CameraUniform {
    view_proj: mat4x4<f32>
};
@group(1) @binding(0)
var<uniform> camera: CameraUniform;

@group(2) @binding(0) var<storage, read> visble_tiles: InstancingObjectStorage;

@vertex
fn vs_main(
    input: VertexInput,
) -> VertexOutput {

    let tileID = input.instance_index;
    let instance = visble_tiles.tiles[tileID];
      if (instance.Position.z == -10.0) {
        return VertexOutput(
          vec4<f32>(-100.0, -100.0, -100.0, 0.0),
          vec4<f32>(0.0, 0.0, 0.0, 0.0),
          vec2<f32>(0.0, 0.0),
          0u
        );
      }
      let imageSize = vec2<f32>(f32(instance.UvCoordSize & 0x0000ffffu), f32(instance.UvCoordSize >> 16u));

      // Calculate ImageSizeToDraw - vec2(imageSize.x/2,imageSize.y) because images have different starting points
      let position = input.Position.xy * imageSize - vec2<f32>(imageSize.x / 2.0, imageSize.y);

      var pos : vec4<f32> = vec4<f32>(position.xy + instance.Position.xy, instance.Position.z, 1.0);
      pos = camera.view_proj * pos;

      let texCoord = vec2<f32>(instance.UvCoordPos + (imageSize * input.Position.xy) / ImageSize);

      let output = VertexOutput(
        pos,
        vec4<f32>(f32(instance.Color >> 24u), f32((instance.Color >> 16u) & 0x000000ffu), f32((instance.Color >> 8u) & 0x000000ffu), f32(instance.Color & 0x000000ffu) ) / 255.0,
        texCoord,
        instance.image_index
      );
      return output;
    }

//==============================================================================
// Fragment shader_bindings
//==============================================================================
@group(0) @binding(0)
var t_diffuse: texture_2d_array<f32>;
@group(0) @binding(1)
var s_diffuse: sampler;


@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let color = textureSample(t_diffuse, s_diffuse, in.TexCoord, in.image_index);
    if(color.a <= 0.0){
        discard;
    }
    return color * in.Color;
}



 

 