struct QuadInput
{
	@location(0) Position: vec4<f32>,
};

struct StaticVSinput
{
	@location(1)TexPos: vec2<u32>,
	@location(2)TexSize: vec2<u32>,
	@location(3)Alignment: vec2<u32>,
	@location(4)Scale: vec2<u32>,
};

struct DynamicVSinput
{
	@location(5)Position: vec2<i32>,
	@location(6)Size: vec2<u32>,
	@location(7)Selected: u32,
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
fn vs_main(
    inputvertex: QuadInput, static_input: StaticVSinput, input: DynamicVSinput
) -> VertexOutput {

        var output : VertexOutput;
        var color = vec4<f32>(184.0 / 255.0, 184.0 / 255.0, 184.0 / 255.0, 255.0 / 255.0);

        if (input.Selected == 0u) {
          output.Position = vec4<f32>(0.0, 0.0, 0.0, -1.0);
          output.TexCoord = vec2<f32>(0.0, 0.0);
          output.Color = color;
          return output;
        }

        var pos = vec2<f32>(f32(input.Position.x), f32(input.Position.y));
        var size = vec2<f32>(f32(input.Size.x), f32(input.Size.y));
        var texPos = vec2<f32>(f32(static_input.TexPos.x), f32(static_input.TexPos.y));
        var texSize = vec2<f32>(f32(static_input.TexSize.x), f32(static_input.TexSize.y));
        var alignment = vec2<f32>(f32(static_input.Alignment.x)/ 2.0, f32(static_input.Alignment.y)/ 2.0) ;
        var scale = vec2<f32>(f32(static_input.Scale.x), f32(static_input.Scale.y));


        if (input.Selected == 2u) {
          color = vec4<f32>(215.0 / 255.0, 209.0 / 255.0, 157.0 / 255.0, 255.0 / 255.0);
        } else if (input.Selected > 2u) {
          color = vec4<f32>(236.0 / 255.0, 210.0 / 255.0, 126.0 / 255.0, 255.0 / 255.0);
        }else{
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
// Fragment shader
//==============================================================================
@group(0) @binding(0)
var t_diffuse: texture_2d<f32>;
@group(0) @binding(1)
var s_diffuse: sampler;


@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let color = textureSample(t_diffuse, s_diffuse, in.TexCoord);
	if(color.r == 1.0 && color.g == 0.0 && color.b == 1.0){
		discard;
	}

	if(color.a > 0.0) {
	 return vec4(color.rgba);;
	}
    return vec4(in.Color.rgba);
}


