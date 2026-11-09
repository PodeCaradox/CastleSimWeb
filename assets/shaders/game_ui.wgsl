fn convertU16ToI16(value: u32) -> f32 {
    if ((value & 0x8000u) != 0u) {
        // If the highest bit is set, it's a negative number in i16 terms.
        return f32(value) - 65536.0;
    } else {
        return f32(value);
    }
}

struct QuadInput
{
	@location(0) Position: vec4<f32>,
};

struct VSinput
{
    @location(1) Position: u32,
    @location(2) Size: u32,
	@location(3) TexPos: u32,
	@location(4) TexSize: u32,
	@location(5) Data: u32,  //bytes low->high: alignment.x, alignment.y, scale, state
};

// screen_size in UI px; scale_factor: device px a UI px (the UI's stage, E477), device px a logical px
struct CameraUniform {
    proj: mat4x4<f32>,
    screen_size: vec2<f32>,
    scale_factor: vec2<f32>,
}

@group(1) @binding(0)
var<uniform> camera: CameraUniform;


// TexCoord in texels of the atlas `Font` names: 0 the UI atlas, 1 the font atlas
struct VertexOutput {
    @builtin(position) Position: vec4<f32>,
    @location(0) Color: vec4<f32>,
    @location(1) TexCoord : vec2<f32>,
    @location(2) @interpolate(flat) Font: u32
}

// the font atlas's texel rows follow the UI atlas's (`FONT_ATLAS_TOP`)
const FONT_ATLAS_TOP: f32 = 2048.0;
// the font atlas's width at 1x: a wider one holds every cell at its stage (`font_atlas::rasterize_at`)
const FONT_ATLAS_WIDTH: f32 = 1024.0;
// the clear texels right of and below a cell at 1x, which a glyph at a stage may ink (`FONT_GUTTER`)
const FONT_GUTTER: f32 = 1.0;
// a quad the world places, in logical px and not scaled (`WORLD_QUAD`)
const WORLD_QUAD: u32 = 0x80u;

// a place of the 1x font atlas at its stage, as `font_atlas::staged` rounds it
fn staged(at: vec2<f32>, stage: f32) -> vec2<f32> {
    return floor(at * stage + 0.5);
}

@vertex
fn vertex_ui(
    inputvertex: QuadInput, input: VSinput
) -> VertexOutput {

        var output : VertexOutput;
        let state = input.Data >> 24u;
        var color = vec4<f32>(184.0 / 255.0, 184.0 / 255.0, 184.0 / 255.0, 255.0 / 255.0);

        if (state == 0u) {
          output.Position = vec4<f32>(0.0, 0.0, 0.0, -1.0);
          output.TexCoord = vec2<f32>(0.0, 0.0);
          output.Color = color;
          output.Font = 0u;
          return output;
        }



        var pos = vec2<f32>(convertU16ToI16(input.Position & 0x0000ffffu), convertU16ToI16(input.Position >> 16u));
        var size = vec2<f32>(f32(input.Size & 0x0000ffffu), f32(input.Size >> 16u));
        var texPos = vec2<f32>(f32(input.TexPos & 0x0000ffffu), f32(input.TexPos >> 16u));
        var texSize = vec2<f32>(f32(input.TexSize & 0x0000ffffu), f32(input.TexSize >> 16u));
        let world = (input.Data & WORLD_QUAD) != 0u;
        var alignment = vec2<f32>(f32(input.Data & 0x7fu)/ 2.0, f32((input.Data >> 8u) & 0x000000ffu)/ 2.0) ;
        let scale_data = (input.Data >> 16u) & 0x000000ffu;
        var scale = vec2<f32>(f32(scale_data), f32(scale_data));

        if (state == 2u) {
          color = vec4<f32>(215.0 / 255.0, 209.0 / 255.0, 157.0 / 255.0, 255.0 / 255.0);
        } else if (state > 2u) {
          color = vec4<f32>(236.0 / 255.0, 210.0 / 255.0, 126.0 / 255.0, 255.0 / 255.0);
        }else {
            scale = vec2<f32>(0.0, 0.0);
        }

        var font = 0u;
        var texSpan = texSize;
        let stage = camera.scale_factor.x;
        let device = camera.scale_factor.y;
        let font_stage = f32(textureDimensions(t_font).x) / FONT_ATLAS_WIDTH;
        if (texPos.y >= FONT_ATLAS_TOP) {
          texPos.y -= FONT_ATLAS_TOP;
          font = 1u;
          // the texels of the cell and its gutter at the atlas's stage
          let start = staged(texPos, font_stage);
          texSpan = staged(texPos + texSize + FONT_GUTTER, font_stage) - start;
          texPos = start;
        }
        var texCoord : vec2<f32> = texPos + (texSpan * inputvertex.Position.xy);
        pos -= scale;
        size += scale.xy * 2.0;
        // a letter covers its cell and gutter: at the atlas's stage a texel is a px
        var drawn = size;
        if (font == 1u) {
          drawn = texSpan / font_stage * size / max(texSize, vec2<f32>(1.0));
        }
        // the anchor in device px, then each corner on a whole device px
        let anchor = round(alignment * camera.screen_size * stage);
        var corner: vec2<f32>;
        if (world) {
          corner = anchor / device + pos + drawn * inputvertex.Position.xy;
        } else {
          let start = round(pos * stage);
          var span = round((pos + size) * stage) - start;
          if (font == 1u) {
            span = round(drawn * stage);
          }
          corner = (anchor + start + span * inputvertex.Position.xy) / device;
        }
        var posWorld : vec4<f32> = vec4<f32>(corner, 1.0, 1.0);

        output.Color = color;
        output.TexCoord = texCoord;
        output.Font = font;
        output.Position = camera.proj * posWorld;
        return output;
    }


//==============================================================================
// Fragment shader_bindings
//==============================================================================
@group(0) @binding(0)
var t_diffuse: texture_2d<f32>;
@group(0) @binding(1)
var s_diffuse: sampler;
@group(0) @binding(2)
var t_font: texture_2d<f32>;


@fragment
fn fragment_ui(in: VertexOutput) -> @location(0) vec4<f32> {
    // both sampled, so each call stays in uniform control flow
    let ui = textureSample(t_diffuse, s_diffuse, in.TexCoord / vec2<f32>(textureDimensions(t_diffuse)));
    let glyph = textureSample(t_font, s_diffuse, in.TexCoord / vec2<f32>(textureDimensions(t_font)));
    let color = select(ui, glyph, in.Font == 1u);
	if(color.r == 1.0 && color.g == 0.0 && color.b == 1.0){
		discard;
	}

	if(color.a > 0.0) {
	 return vec4(color.rgba);;
	}
    return vec4(in.Color.rgba);
}


