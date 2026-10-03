#import world_utils



@group(2) @binding(0) var<storage, read> tiles_data : world_utils::TileDataStorage;
@group(2) @binding(1) var<storage, read> tiles_rotation : world_utils::TileRotationDataStorage;
@group(3) @binding(0) var<storage, read_write> visble_tiles_cp : world_utils::InstancingObjectStorage;


@compute
@workgroup_size(16, 16, 1)
fn instancing_with_elevation(@builtin(global_invocation_id) global_id: vec3<u32>) {
            var index: vec2<i32> = vec2<i32>(world_utils::params.start_pos.x, world_utils::params.start_pos.y);
            let column = i32(global_id.x);
            var row = i32(global_id.y);

            index.x -= row % 2;
            row /= 2;
            index.y += row;
            index.x -= row;
            let actual_row_start = index;
            index.y += column;
            index.x += column;

            if (world_utils::is_in_map_bounds(index) == 0) {
                return;
            }

            if (row >= world_utils::params.rows || column >= world_utils::params.columns){
                return;
            }

           let visible_index = world_utils::calc_visible_index(index, actual_row_start) * 4;

           let rotation_offset = world_utils::params.map_size.x * world_utils::params.map_size.y * i32(world_utils::params.direction);
           let tile_rotation_data = tiles_rotation.tiles[index.y * world_utils::params.map_size.x + index.x + rotation_offset];
           let tile_data = tiles_data.tiles[index.y * world_utils::params.map_size.x + index.x];

           let tick = world_utils::params.tick;
           var animation = (tile_rotation_data.Data >> 8u) & 0x000000ffu;
           var animation_enabled = animation & 0x00000001u;

           var offset_object_y = f32(tile_rotation_data.Data >> 16u);
           var offset_elevation_x =  world_utils::u8_to_i8(tile_rotation_data.Data & 0x000000ffu);


           visble_tiles_cp.tiles[visible_index] = world_utils::CreateSpecificInstance(tile_rotation_data.SingleInstances[0u], index, tile_data.Elevation, animation_enabled, tick, 0xffffffffu, world_utils::ModeGround);
           animation_enabled = ((animation >> 1u) & 0x00000001u);
           visble_tiles_cp.tiles[visible_index + 1] = world_utils::CreateSpecificInstance(tile_rotation_data.SingleInstances[1u], index, tile_data.Elevation, animation_enabled, tick, 0xffffffffu, world_utils::ModeBillboard);
           animation_enabled = ((animation >> 2u) & 0x00000001u);
           visble_tiles_cp.tiles[visible_index + 2] = world_utils::CreateBuildingInstance(tile_rotation_data.SingleInstances[2u], index, tile_data.Elevation, animation_enabled, tick, 0xffffffffu, offset_object_y);
           animation_enabled = ((animation >> 3u) & 0x00000001u);
           let run = face_run(index, tile_rotation_data.SingleInstances[3u], rotation_offset);
           visble_tiles_cp.tiles[visible_index + 3] = world_utils::CreateElevationInstance(tile_rotation_data.SingleInstances[3u], index, tile_data.Elevation, animation_enabled, tick, 0xffffffffu, offset_elevation_x, run, front_ground(index, run, rotation_offset));
}

//Whether `cell` holds a wall face (a wall's masonry, a cliff draws rock). Only `ground_of` asks: a
//wall stands WallHeight over its own ground while a cliff's elevation is its ground.
fn has_wall_face(cell: vec2<i32>, rotation_offset: i32) -> bool {
    if (world_utils::is_in_map_bounds(cell) == 0) {
        return false;
    }
    let face = tiles_rotation.tiles[cell.y * world_utils::params.map_size.x + cell.x + rotation_offset].SingleInstances[3u];
    return face != 0u && world_utils::tile_properties.properties[face].image_index == world_utils::WallFaceImage;
}

//Whether `cell` draws a face at all: its elevation slot is filled. A cliff's rock and a wall's
//masonry are the same thing to the foot (E159).
fn has_face(cell: vec2<i32>, rotation_offset: i32) -> bool {
    if (world_utils::is_in_map_bounds(cell) == 0) {
        return false;
    }
    return tiles_rotation.tiles[cell.y * world_utils::params.map_size.x + cell.x + rotation_offset].SingleInstances[3u] != 0u;
}

//The RunLeft/RunRight mask of a face: which of its two same-screen-row neighbours (the step that is
//(1, -1) after the camera rotation) carries a face too, so the foot is straight towards it. A face
//alone in its row, or in a run along a map column, keeps the box's V.
fn face_run(cell: vec2<i32>, face: u32, rotation_offset: i32) -> u32 {
    if (face == 0u) {
        return 0u;
    }
    var right = vec2<i32>(1, -1);
    if (world_utils::params.direction == 1u) {
        right = vec2<i32>(-1, -1);
    } else if (world_utils::params.direction == 2u) {
        right = vec2<i32>(-1, 1);
    } else if (world_utils::params.direction == 3u) {
        right = vec2<i32>(1, 1);
    }
    var run = 0u;
    if (has_face(cell - right, rotation_offset)) {
        run |= world_utils::RunLeft;
    }
    if (has_face(cell + right, rotation_offset)) {
        run |= world_utils::RunRight;
    }
    return run;
}

//The ground a face's straight foot is drawn over: the LOWER of the two cells in front on screen
//((0, 1) and (1, 0) of the rotated map), so the foot never covers a unit on the lower one. A wall
//there stands on its ground, WallHeight below its elevation.
fn front_ground(cell: vec2<i32>, run: u32, rotation_offset: i32) -> f32 {
    if (run == 0u) {
        return 0.0;
    }
    var left = vec2<i32>(0, 1);
    var right = vec2<i32>(1, 0);
    if (world_utils::params.direction == 1u) {
        left = vec2<i32>(1, 0);
        right = vec2<i32>(0, -1);
    } else if (world_utils::params.direction == 2u) {
        left = vec2<i32>(0, -1);
        right = vec2<i32>(-1, 0);
    } else if (world_utils::params.direction == 3u) {
        left = vec2<i32>(-1, 0);
        right = vec2<i32>(0, 1);
    }
    //ponytail: the run mask says which half of the foot is drawn, so a face with one run could take
    //that cell's ground exactly instead of the min; worth it only if a step in front of a run's end
    //shows
    return min(ground_of(cell + left, rotation_offset), ground_of(cell + right, rotation_offset));
}

const WallHeight : f32 = 200.0;

//The height of the GROUND of a cell: its elevation, less the wall standing on
//it. Outside the map there is nothing to be drawn over.
fn ground_of(cell: vec2<i32>, rotation_offset: i32) -> f32 {
    if (world_utils::is_in_map_bounds(cell) == 0) {
        return 0.0;
    }
    var elevation = tiles_data.tiles[cell.y * world_utils::params.map_size.x + cell.x].Elevation;
    if (has_wall_face(cell, rotation_offset)) {
        elevation -= WallHeight;
    }
    return elevation;
}

@compute
@workgroup_size(16, 16, 1)
fn instancing_without_elevation(@builtin(global_invocation_id) global_id: vec3<u32>) {
            var index: vec2<i32> = vec2<i32>(world_utils::params.start_pos.x, world_utils::params.start_pos.y);
            let column = i32(global_id.x);
            var row = i32(global_id.y);

            index.x -= row % 2;
            row /= 2;
            index.y += row;
            index.x -= row;
            let actual_row_start = index;
            index.y += column;
            index.x += column;

            if (world_utils::is_in_map_bounds(index) == 0) {
                return;
            }

           let visible_index = world_utils::calc_visible_index(index, actual_row_start) * 2;

           let rotation_offset = world_utils::params.map_size.x * world_utils::params.map_size.y * i32(world_utils::params.direction);
           let tile_rotation_data = tiles_rotation.tiles[index.y * world_utils::params.map_size.x + index.x + rotation_offset];

           let tick = world_utils::params.tick;
           var animation = (tile_rotation_data.Data >> 8u) & 0x000000ffu;
           var animation_enabled = animation & 0x00000001u;

           visble_tiles_cp.tiles[visible_index] = world_utils::CreateSpecificInstance(tile_rotation_data.SingleInstances[4u], index, 0.0, animation_enabled, tick, 0xffffffffu, world_utils::ModeGround);
           animation_enabled = ((animation >> 1u) & 0x00000001u);
           visble_tiles_cp.tiles[visible_index + 1] = world_utils::CreateSpecificInstance(tile_rotation_data.SingleInstances[5u], index, 0.0, animation_enabled, tick, 0xffffffffu, world_utils::ModeBillboard);
}

//Vertex shader bindings; 16 bytes
struct VertexInput {
    @location(0) Position: vec2<f32>,
    @builtin(instance_index) instance_index: u32,
}

// 16 byte + 16 byte + 12 bytes + 32 bytes = 76 bytes
struct VertexOutput {
    @builtin(position) Position: vec4<f32>,
    @location(0) Color: vec4<f32>,
    @location(1) TexCoord : vec2<f32>,
    @location(2) @interpolate(flat)  image_index : u32,
    //the fragment stage's share of the depth: world position, the V's apex (the lifted tip for a
    //ground quad), the face or quad height less 16, the depth a column takes off, the thickness
    //depth, the packed mode and run
    @location(3) world : vec2<f32>,
    @location(4) @interpolate(flat) apex : vec2<f32>,
    @location(5) @interpolate(flat) height : f32,
    @location(6) @interpolate(flat) depth_per_column : f32,
    @location(7) thickness_depth : f32,
    @location(8) @interpolate(flat) depth_info : u32,
}

struct CameraUniform {
    view_proj: mat4x4<f32>
};
@group(1) @binding(0)
var<uniform> camera: CameraUniform;

@group(2) @binding(0) var<storage, read> visble_tiles: world_utils::InstancingObjectStorage;

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
          0u,
          vec2<f32>(0.0, 0.0),
          vec2<f32>(0.0, 0.0),
          0.0,
          0.0,
          0.0,
          0u
        );
      }
      let imageSize = vec2<f32>(f32(instance.UvCoordSize & 0x0000ffffu), f32(instance.UvCoordSize >> 16u));

      // Calculate ImageSizeToDraw - vec2(imageSize.x/2,imageSize.y) because images have different
      // starting points
      let position = input.Position * imageSize - vec2<f32>(imageSize.x / 2.0, imageSize.y);

      let world = position.xy + instance.Position.xy;
      let info = instance.image_index;
      let mode = (info >> world_utils::ModeShift) & 3u;
      let denominator = f32(((info >> world_utils::DenominatorShift) & world_utils::DenominatorMask) * world_utils::KeysPerRowPair);
      let offset_code = (info >> world_utils::OffsetShift) & 3u;
      var offset_x = 0.0;
      if (offset_code == 1u) {
          offset_x = 16.0;
      } else if (offset_code == 2u) {
          offset_x = -16.0;
      }

      //the linear part of the nearness at this vertex (see world_utils):
      //ground y + 2e, billboard 2f - y, box and face 2tip - y before the |x|
      var nearness = world.y + instance.Position.z;
      if (mode != world_utils::ModeGround) {
          nearness = instance.Position.z - world.y;
      }
      //one column away from the apex the V is half a row lower and the face pixel over it half a
      //row higher: one pixel of nearness in window depth; fs_main applies it to a box, a face and
      //standing ground art
      let depth_per_column = world_utils::KeysPerPixel / denominator * camera.view_proj[2][2];
      let depth = (nearness * world_utils::KeysPerPixel + 64.0) / denominator;
      //the wall's thickness, just over the ground in front. It is written to frag_depth, so it goes
      //through the projection's z scale and translation as `pos.z` does; the orthographic camera's
      //x and y columns add nothing to z
      var thickness = world.y + 2.0 * world_utils::UnpackFrontGround(info) + 0.5;
      var apex_y = instance.Position.z / 2.0;
      if (mode == world_utils::ModeGround) {
          //a ground quad has no thickness: the varying carries the linear part of the box its
          //standing art is ordered as, 2 tip - y with the tip the quad's bottom before the lift
          //(Position.y + Position.z / 2)
          thickness = 2.0 * (instance.Position.y + instance.Position.z / 2.0) - world.y;
          apex_y = instance.Position.y;
      }
      let thickness_depth = (thickness * world_utils::KeysPerPixel + 64.0) / denominator * camera.view_proj[2][2] + camera.view_proj[3][2];

      var pos : vec4<f32> = vec4<f32>(world, depth, 1.0);
      pos = camera.view_proj * pos;

      let texCoord = vec2<f32>(instance.UvCoordPos + (imageSize * input.Position) / world_utils::ImageSize);

      let output = VertexOutput(
        pos,
        vec4<f32>(f32(instance.Color >> 24u), f32((instance.Color >> 16u) & 0x000000ffu), f32((instance.Color >> 8u) & 0x000000ffu), f32(instance.Color & 0x000000ffu) ) / 255.0,
        texCoord,
        info & world_utils::ImageIndexMask,
        world,
        vec2<f32>(instance.Position.x - offset_x, apex_y),
        imageSize.y - 16.0,
        depth_per_column,
        thickness_depth,
        info
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

//Writing frag_depth disables the early depth test for the whole pipeline, not only for the box and
//the face that need it; splitting ground and billboard into a pipeline of their own would take a
//second pass and buffer layout, and was measured not worth it (docs/rendering.md).
struct FragmentOutput {
    @location(0) color: vec4<f32>,
    @builtin(frag_depth) depth: f32,
};


@fragment
fn fs_main(in: VertexOutput) -> FragmentOutput {
    let color = textureSample(t_diffuse, s_diffuse, in.TexCoord, in.image_index);
    if(color.a <= 0.0){
        discard;
    }
    let mode = (in.depth_info >> world_utils::ModeShift) & 3u;
    let dx = abs(in.world.x - in.apex.x);
    //the window depth as the rasterizer interpolated it, minus the V for a
    //box or a face: the fragment's column is dx away from the apex
    var depth = in.Position.z;
    if (mode == world_utils::ModeBox || mode == world_utils::ModeFace) {
        depth -= in.depth_per_column * dx;
    }
    //ground-slot art taller than the diamond that STANDS (the wall layer or the tile's own StandsUp
    //knob) is a box above the cell's back edges, the V a building slice stands on; its diamond
    //stays ground. A plain 64 x 32 tile never takes this branch (depth_order::ground_quad_nearness)
    let stands_up = in.image_index == world_utils::WallAtlasLayer
        || (in.depth_info & world_utils::StandsUpFlag) != 0u;
    //ponytail: a pillar filling its cell wants the box over its diamond's upper half too (a man at
    //its shared corner paints a few rows of feet over its base); that needs a second per-tile knob
    if (mode == world_utils::ModeGround && stands_up && in.height > 16.0 && in.world.y < in.apex.y - 32.0 + dx / 2.0) {
        depth = in.thickness_depth - in.depth_per_column * dx;
    }
    if (mode == world_utils::ModeFace) {
        //above the plateau's front edges is the plateau's own lower half,
        //painted into the face's top rows: the real plateau is drawn there
        if (in.world.y < in.apex.y - in.height - dx / 2.0) {
            discard;
        }
        //towards a run neighbour: the wall's thickness, the triangles between the front edges and
        //the line through the bottom tip, both lifted by the ground in front; only while that
        //ground lies below the face
        let run = (in.depth_info >> world_utils::RunShift) & 3u;
        let towards_run = ((run & world_utils::RunLeft) != 0u && in.world.x < in.apex.x)
            || ((run & world_utils::RunRight) != 0u && in.world.x >= in.apex.x);
        let front = world_utils::UnpackFrontGround(in.depth_info);
        if (towards_run && front < in.height && in.world.y > in.apex.y - dx / 2.0 - front && in.world.y <= in.apex.y - front) {
            depth = in.thickness_depth;
        }
    }
    var out: FragmentOutput;
    out.color = color * in.Color;
    out.depth = depth;
    return out;
}