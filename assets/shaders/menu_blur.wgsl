// The start menu's soft bands (E458): the world's picture blurred across, then down, in half the
// window's size, and mixed over the sharp picture by a mask in the top and bottom bands.

@group(0) @binding(0)
var picture: texture_2d<f32>;
@group(0) @binding(1)
var picture_sampler: sampler;
@group(1) @binding(0)
var soft: texture_2d<f32>;
@group(1) @binding(1)
var soft_sampler: sampler;

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
}

// One triangle over the whole target.
@vertex
fn vertex_full(@builtin(vertex_index) index: u32) -> VertexOutput {
    var output: VertexOutput;
    output.uv = vec2<f32>(f32((index << 1u) & 2u), f32(index & 2u));
    output.position = vec4<f32>(output.uv.x * 2.0 - 1.0, 1.0 - output.uv.y * 2.0, 0.0, 1.0);
    return output;
}

// The design's blur(6px) is a gaussian of sigma 6 px: 3 texels of the half size target, each
// weighed by its distance from the middle.
const TEXEL_0: f32 = 0.13357;
const TEXEL_1: f32 = 0.12635;
const TEXEL_2: f32 = 0.10695;
const TEXEL_3: f32 = 0.08101;
const TEXEL_4: f32 = 0.05491;
const TEXEL_5: f32 = 0.03331;
const TEXEL_6: f32 = 0.01808;
const TEXEL_7: f32 = 0.00878;
const TEXEL_8: f32 = 0.00382;

fn pair(uv: vec2<f32>, off: vec2<f32>) -> vec4<f32> {
    return textureSampleLevel(picture, picture_sampler, uv + off, 0.0)
        + textureSampleLevel(picture, picture_sampler, uv - off, 0.0);
}

// From the whole picture into the half size target. A bilinear tap spans two pixels there, one
// texel of the half size image, so every texel of the kernel takes a tap of its own. An odd side
// has a half size rounded down: uv is laid on the even size, or the taps drift onto pixel centres.
@fragment
fn blur_across(in: VertexOutput) -> @location(0) vec4<f32> {
    let size = textureDimensions(picture);
    let uv = in.uv * vec2<f32>(size / 2u * 2u) / vec2<f32>(size);
    let step = vec2<f32>(2.0 / f32(size.x), 0.0);
    return textureSampleLevel(picture, picture_sampler, uv, 0.0) * TEXEL_0
        + pair(uv, step) * TEXEL_1 + pair(uv, step * 2.0) * TEXEL_2
        + pair(uv, step * 3.0) * TEXEL_3 + pair(uv, step * 4.0) * TEXEL_4
        + pair(uv, step * 5.0) * TEXEL_5 + pair(uv, step * 6.0) * TEXEL_6
        + pair(uv, step * 7.0) * TEXEL_7 + pair(uv, step * 8.0) * TEXEL_8;
}

// One bilinear tap, at their weighted middle, for two neighbouring texels of the kernel.
fn two_texels(uv: vec2<f32>, step: vec2<f32>, near: f32, far: f32, at: f32) -> vec4<f32> {
    return pair(uv, step * (at + far / (near + far))) * (near + far);
}

// Inside the half size target, where one tap spans two of its texels.
@fragment
fn blur_down(in: VertexOutput) -> @location(0) vec4<f32> {
    let step = vec2<f32>(0.0, 1.0 / f32(textureDimensions(picture).y));
    return textureSampleLevel(picture, picture_sampler, in.uv, 0.0) * TEXEL_0
        + two_texels(in.uv, step, TEXEL_1, TEXEL_2, 1.0)
        + two_texels(in.uv, step, TEXEL_3, TEXEL_4, 3.0)
        + two_texels(in.uv, step, TEXEL_5, TEXEL_6, 5.0)
        + two_texels(in.uv, step, TEXEL_7, TEXEL_8, 7.0);
}

// The design's bands: 30 % of the height at the top, 35 % at the bottom.
const TOP_BAND: f32 = 0.30;
const BOTTOM_BAND: f32 = 0.35;
// The mask is whole over the first 35 % of a band, seen from the window's edge, then fades out.
const BAND_WHOLE: f32 = 0.35;

fn band(from_edge: f32, height: f32) -> f32 {
    return 1.0 - clamp((from_edge / height - BAND_WHOLE) / (1.0 - BAND_WHOLE), 0.0, 1.0);
}

@fragment
fn mix_bands(in: VertexOutput) -> @location(0) vec4<f32> {
    let mask = max(band(in.uv.y, TOP_BAND), band(1.0 - in.uv.y, BOTTOM_BAND));
    let sharp = textureSampleLevel(picture, picture_sampler, in.uv, 0.0);
    let blurred = textureSampleLevel(soft, soft_sampler, in.uv, 0.0);
    return vec4<f32>(mix(sharp.rgb, blurred.rgb, mask), 1.0);
}
