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
           let run = wall_run(index, tile_rotation_data.SingleInstances[3u], rotation_offset);
           visble_tiles_cp.tiles[visible_index + 3] = world_utils::CreateElevationInstance(tile_rotation_data.SingleInstances[3u], index, tile_data.Elevation, animation_enabled, tick, 0xffffffffu, offset_elevation_x, run, front_ground(index, run, rotation_offset));
}

//Whether `cell` holds a wall face: the elevation slot of a wall cell draws
//the wall's masonry, a cliff's draws rock.
fn has_wall_face(cell: vec2<i32>, rotation_offset: i32) -> bool {
    if (world_utils::is_in_map_bounds(cell) == 0) {
        return false;
    }
    let face = tiles_rotation.tiles[cell.y * world_utils::params.map_size.x + cell.x + rotation_offset].SingleInstances[3u];
    return face != 0u && world_utils::tile_properties.properties[face].image_index == world_utils::WallFaceImage;
}

//The RunLeft/RunRight mask of a wall face: which of the two neighbours in
//the same SCREEN row — the step that is (1, -1) after the camera rotation —
//continues the wall, so the face's foot is drawn straight towards it. The
//run is the only thing that decides between a straight foot and the box's
//V: a run along a column of the map is a staircase of boxes and keeps the V.
fn wall_run(cell: vec2<i32>, face: u32, rotation_offset: i32) -> u32 {
    if (face == 0u || world_utils::tile_properties.properties[face].image_index != world_utils::WallFaceImage) {
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
    if (has_wall_face(cell - right, rotation_offset)) {
        run |= world_utils::RunLeft;
    }
    if (has_wall_face(cell + right, rotation_offset)) {
        run |= world_utils::RunRight;
    }
    return run;
}

//The ground a wall's straight foot is drawn over: the two cells in FRONT of
//`cell` on screen — down-left and down-right of its diamond, which are (0, 1)
//and (1, 0) of the ROTATED map — carry the strip below the cell's V. One
//number has to serve both halves of the quad, and it is the LOWER of the two:
//over the higher one the foot falls back to the box's V (today's sawtooth),
//which is the harmless way to be wrong — the other way round the foot would
//cover a unit standing on the lower cell.
//A wall in front stands on its own ground, WALL_HEIGHT below its elevation
//(`cs_core::map_editing`), and it is that ground the foot must sit over.
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

//==============================================================================
// Vertex shader_bindings
//==============================================================================
//16 bytes
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
    //the fragment stage's share of the depth (world_utils "Draw order"): the
    //fragment's world position, the apex of the cell's V (its front tip: the
    //map row before the lift for a box and a face, the LIFTED tip — the
    //quad's bottom — for a ground quad, so its edge test needs no elevation),
    //the height of a face or of a ground quad less the 16 px of the diamond's
    //lower half, how much depth one column away from the apex takes off (the
    //fragment stage applies it to a box, a face and the standing part of tall
    //ground art), the depth of the wall's thickness at this pixel — for a
    //ground quad the linear part of the box its standing art is ordered as —
    //and the packed mode and run mask
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

      // Calculate ImageSizeToDraw - vec2(imageSize.x/2,imageSize.y) because images have different starting points
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
      //one column away from the apex the V is half a row lower, and the
      //face pixel over it half a row higher: one pixel of nearness, in
      //window depth through the projection's z scale. Every mode carries
      //it; fs_main applies it to a box, a face and the standing part of tall
      //ground art
      let depth_per_column = world_utils::KeysPerPixel / denominator * camera.view_proj[2][2];
      let depth = (nearness * world_utils::KeysPerPixel + 64.0) / denominator;
      //the wall's thickness: just over the ground in front of the face, at
      //whatever height that ground lies. It is written to frag_depth, so it
      //has to go through the projection the same way `pos.z` does — the z
      //column's scale AND its translation (the rasterizer would have added
      //both). The camera is orthographic and its view moves only x and y, so
      //the x and y columns contribute nothing to z; a projection that mixed
      //them in would need their terms here too.
      var thickness = world.y + 2.0 * world_utils::UnpackFrontGround(info) + 0.5;
      var apex_y = instance.Position.z / 2.0;
      if (mode == world_utils::ModeGround) {
          //a ground quad has no thickness: the varying carries the linear
          //part of the BOX its standing art is ordered as in fs_main, 2 tip -
          //y with the tip the quad's bottom before the lift (Position.y +
          //elevation, elevation being Position.z / 2), and the apex is the
          //LIFTED tip, the quad's bottom, so the edge test there needs no
          //elevation of its own
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

//Writing frag_depth costs the EARLY DEPTH TEST for the whole pipeline — not
//only for the fragments that take the box branch: a shader that CAN write it
//makes every fragment's depth unknown until it has run. Only the box and the
//face need it; ground and billboard carry a depth that is linear over the quad
//and the vertex stage has it exactly. Splitting them apart takes two
//pipelines, and with them a compute pass that writes the four slots of a cell
//into two buffers instead of one interleaved run (`visible_index * 4 + slot`)
//and a render pass that draws both — nothing a shader can do on its own.
//MEASURED what it would win (pt_scene on the showcase map, zoom 1, the camera
//over the 512 px terraces at cell 250,200; three runs each, alternating, on
//the shared machine): with only the ground and billboard instances drawn,
//frag_depth on 1245 fps against 1437 fps without it — 0.107 ms of a 0.82 ms
//frame. Over the same camera the whole terrain pass runs at 1219 fps and,
//with frag_depth taken off ALL modes (the picture then wrong), 1464. At a
//flat camera (cell 250,250) the difference disappears into the run-to-run
//spread: 1507 against 1509 fps.
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
    //WALL art in the ground slot TALLER than the 32 px diamond — the
    //crenellation 64 x 94 and the wooden spikes 64 x 122 of wall_tiles.data
    //— is not ground OUTSIDE the diamond, above the cell's BACK edges: it
    //STANDS there, and y + 2e ordered every standing row as the flat
    //surface at that row, so a man one screen row behind a crenellation
    //painted his whole body over the pillar. Above the back edges (the
    //front edge V mirrored through the diamond's centre row: 32 rows up,
    //dx / 2 down) it is the box on the cell, the same V a building slice
    //stands on (depth_order::ground_quad_nearness counts it); the diamond
    //itself stays the ground it was, exact. The split used to sit on the
    //FRONT edge, which is the diamond's LOWER boundary: the whole floor of
    //the tile was a box too.
    //The key is the atlas LAYER and the height TOGETHER: layer 1 is
    //wall.png (cs_initializer::helper::init_images), and the two tiles of
    //that layer taller than the diamond — this crenellation and the wooden
    //spikes — are the only two Obstacle entries of wall_tiles.data, while
    //its other 256 are Wall (walkable: a wall walk is walked on) and
    //stair_tiles.data puts a walkable Portal stair on the same layer in the
    //same ground slot, 64 x 32 and so never in this branch. No walkable
    //tile of the layer is TALL, which is the invariant depth_order's
    //no_walkable_tile_of_the_wall_layer_is_taller_than_its_diamond pins
    //over every data file. The twelve tall tiles of the LAND layer — rock piles
    //and tufts, 40 to 64 px — stay ground: four land brushes paint nothing
    //else, and a box there put up to 90 % of the pile over the body of the
    //man walking on that very cell (depth_order counts it in
    //a_man_on_his_own_land_tile_keeps_his_body_out_of_its_standing_art).
    //A plain 64 x 32 tile is not tall and never takes this branch;
    //billboards are another mode. Above the back edges the art beats the
    //ground tiles behind it strictly where it used to tie them.
    //ponytail: a pillar FILLING its cell would want the box over its
    //diamond's upper half as well — a man on the wall walk at the pillar's
    //shared corner paints a few rows of feet over the pillar base (counted
    //in depth_order). The way up is a standing bit per tile; the layer is
    //what ships.
    if (mode == world_utils::ModeGround && in.image_index == world_utils::WallAtlasLayer && in.height > 16.0 && in.world.y < in.apex.y - 32.0 + dx / 2.0) {
        depth = in.thickness_depth - in.depth_per_column * dx;
    }
    if (mode == world_utils::ModeFace) {
        //above the plateau's front edges is the plateau's own lower half,
        //painted into the face's top rows: the real plateau is drawn there
        if (in.world.y < in.apex.y - in.height - dx / 2.0) {
            discard;
        }
        //towards a wall neighbour in the same row: the wall's thickness. It
        //fills the corner triangles between the cell's front edges and the
        //straight line through the cell's bottom tip — both LIFTED by the
        //ground in front, which is where the wall meets that ground — and it
        //is drawn just over it. Below that line the pixels stay the box and
        //the ground in front covers them, so the foot is a straight line at
        //every height instead of the V's sawtooth.
        let run = (in.depth_info >> world_utils::RunShift) & 3u;
        let towards_run = ((run & world_utils::RunLeft) != 0u && in.world.x < in.apex.x)
            || ((run & world_utils::RunRight) != 0u && in.world.x >= in.apex.x);
        let front = world_utils::UnpackFrontGround(in.depth_info);
        if (towards_run && in.world.y > in.apex.y - dx / 2.0 - front && in.world.y <= in.apex.y - front) {
            depth = in.thickness_depth;
        }
    }
    var out: FragmentOutput;
    out.color = color * in.Color;
    out.depth = depth;
    return out;
}