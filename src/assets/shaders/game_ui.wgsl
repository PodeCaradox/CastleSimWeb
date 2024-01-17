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
	@location(5) @interpolate(flat)  Data: u32,  //16 alignment, 8 state, 8 Scale
};

struct CameraUniform {
    proj: mat4x4<f32>,
    screen_size: vec2<f32>,
    scale_factor: vec2<f32>,
}

@group(1) @binding(0)
var<uniform> camera: CameraUniform;


// 16 byte + 16 byte + 12 bytes = 44 bytes
struct VertexOutput {
    @builtin(position) Position: vec4<f32>,
    @location(0) Color: vec4<f32>,
    @location(1) TexCoord : vec2<f32>
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
          return output;
        }



        var pos = vec2<f32>(convertU16ToI16(input.Position & 0x0000ffffu), convertU16ToI16(input.Position >> 16u));
        var size = vec2<f32>(f32(input.Size & 0x0000ffffu), f32(input.Size >> 16u));
        var texPos = vec2<f32>(f32(input.TexPos & 0x0000ffffu), f32(input.TexPos >> 16u));
        var texSize = vec2<f32>(f32(input.TexSize & 0x0000ffffu), f32(input.TexSize >> 16u));
        var alignment = vec2<f32>(f32(input.Data& 0x000000ffu)/ 2.0, f32((input.Data >> 8u) & 0x000000ffu)/ 2.0) ;
        let scale_data = (input.Data >> 16u) & 0x000000ffu;
        var scale = vec2<f32>(f32(scale_data), f32(scale_data));

        if (state == 2u) {
          color = vec4<f32>(215.0 / 255.0, 209.0 / 255.0, 157.0 / 255.0, 255.0 / 255.0);
        } else if (state > 2u) {
          color = vec4<f32>(236.0 / 255.0, 210.0 / 255.0, 126.0 / 255.0, 255.0 / 255.0);
        }else {
            scale = vec2<f32>(0.0, 0.0);
        }

        var texCoord : vec2<f32> = (texPos + (texSize * inputvertex.Position.xy)) / 2048.0;
        pos -= scale;
        size += scale.xy * 2.0;
        var posWorld : vec4<f32> = vec4<f32>((pos + (size * inputvertex.Position.xy) + round(alignment * camera.screen_size)), 0.0, 1.0);

        output.Color = color;
        output.TexCoord = texCoord;
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


@fragment
fn fragment_ui(in: VertexOutput) -> @location(0) vec4<f32> {
    let color = textureSample(t_diffuse, s_diffuse, in.TexCoord);
	if(color.r == 1.0 && color.g == 0.0 && color.b == 1.0){
		discard;
	}

	if(color.a > 0.0) {
	 return vec4(color.rgba);;
	}
    return vec4(in.Color.rgba);
}


