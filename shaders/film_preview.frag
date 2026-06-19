#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform float u_temperature;
uniform float u_saturation;
uniform float u_contrast;
uniform float u_brightness;
uniform float u_shadow_lift;
uniform float u_tint_strength;
uniform float u_red_gamma;
uniform float u_green_gamma;
uniform float u_blue_gamma;
uniform vec3 u_highlight_tint;
uniform vec3 u_shadow_tint;
uniform float u_grain;
uniform float u_grain_size;
uniform float u_grain_colored;
uniform float u_vignette;
uniform float u_scratch;
uniform float u_leak;
uniform float u_dust;
uniform float u_halation;

uniform sampler2D u_input;
uniform sampler2D u_scratch_texture;
uniform sampler2D u_leak_texture;
uniform sampler2D u_dust_texture;

out vec4 frag_color;

float hash_noise(vec2 p) {
  float h = sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453;
  return fract(h);
}

float smooth_tone(float edge0, float edge1, float x) {
  float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

float contrast_curve(float x, float contrast) {
  x = clamp(x, 0.0, 1.5);
  if (contrast >= 0.0) {
    float curve = x < 0.5 ? 2.0 * x * x : 1.0 - 2.0 * (1.0 - x) * (1.0 - x);
    return mix(x, curve, clamp(contrast, 0.0, 1.0));
  }
  return 0.5 + (x - 0.5) * (1.0 + clamp(contrast, -1.0, 0.0));
}

float shoulder(float x) {
  x = clamp(x, 0.0, 1.5);
  float start = 200.0 / 255.0;
  if (x <= start) {
    return x;
  }
  float t = clamp((x - start) / (55.0 / 255.0), 0.0, 2.0);
  float shaped = (t * 1.35) / (1.0 + 0.35 * t);
  return start + (55.0 / 255.0) * clamp(shaped, 0.0, 1.0);
}

vec3 screen_blend(vec3 base, vec4 overlay, float strength) {
  float alpha = overlay.a * strength * 0.5;
  return 1.0 - (1.0 - base) * (1.0 - overlay.rgb * alpha);
}

vec3 halation_from_sample(vec3 sample_color) {
  float luminance = dot(sample_color, vec3(0.299, 0.587, 0.114));
  float red_bias = max(0.0, sample_color.r - max(sample_color.g, sample_color.b) * 0.5);
  float amount = smooth_tone(0.78, 1.0, luminance) * (0.2 + red_bias) * u_halation * (24.0 / 255.0);
  return vec3(amount, amount * 0.35, amount * 0.06);
}

vec3 add_halation(vec2 uv, vec3 color) {
  if (u_halation <= 0.0) {
    return color;
  }

  vec2 texel = 1.0 / u_size;
  vec3 halo = vec3(0.0);
  halo += halation_from_sample(texture(u_input, uv + vec2(-texel.x, 0.0)).rgb);
  halo += halation_from_sample(texture(u_input, uv + vec2(texel.x, 0.0)).rgb);
  halo += halation_from_sample(texture(u_input, uv + vec2(0.0, -texel.y)).rgb);
  halo += halation_from_sample(texture(u_input, uv + vec2(0.0, texel.y)).rgb);
  return color + halo;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif

  vec4 source = texture(u_input, uv);
  vec3 color = add_halation(uv, source.rgb);

  float luminance = dot(color, vec3(0.299, 0.587, 0.114));
  float temperature = u_temperature * (24.0 / 255.0) * (1.0 - luminance * luminance);
  color += vec3(temperature, temperature * 0.18, -temperature);
  color = clamp(color, 0.0, 1.0);

  color = pow(color, vec3(u_red_gamma, u_green_gamma, u_blue_gamma));

  luminance = dot(color, vec3(0.299, 0.587, 0.114));
  color = vec3(luminance) + (color - vec3(luminance)) * u_saturation;

  color.r = contrast_curve(color.r, u_contrast);
  color.g = contrast_curve(color.g, u_contrast);
  color.b = contrast_curve(color.b, u_contrast);

  if (u_brightness > 0.0) {
    color += u_brightness * (1.0 - color);
  } else {
    color += vec3(u_brightness);
  }

  if (u_tint_strength > 0.0) {
    luminance = dot(color, vec3(0.299, 0.587, 0.114));
    float highlight_mix = smooth_tone(0.55, 0.92, luminance) * u_tint_strength;
    float shadow_mix = (1.0 - smooth_tone(0.08, 0.45, luminance)) * u_tint_strength;
    color = mix(color, u_highlight_tint * (240.0 / 255.0), highlight_mix);
    color = mix(color, u_shadow_tint, shadow_mix);
  }

  color += u_shadow_lift * pow(1.0 - color, vec3(2.0));
  color = vec3(shoulder(color.r), shoulder(color.g), shoulder(color.b));

  if (u_grain > 0.0) {
    float scale = 3.4 * clamp(u_grain_size, 0.5, 2.0);
    float visibility = 0.35 + (1.0 - dot(color, vec3(0.299, 0.587, 0.114))) * 0.65;
    float amount = u_grain * (38.0 / 255.0) * visibility;
    vec2 p = FlutterFragCoord().xy / scale;
    float noise_r = hash_noise(p) - 0.5;
    float noise_g = hash_noise(p + vec2(11.0, 7.0)) - 0.5;
    float noise_b = hash_noise(p + vec2(23.0, 19.0)) - 0.5;
    vec3 mono = vec3(noise_r);
    vec3 chroma = vec3(noise_r, noise_g * 0.85, noise_b * 1.1);
    color += mix(mono, chroma, clamp(u_grain_colored, 0.0, 1.0)) * amount;
  }

  vec2 centered = uv - vec2(0.5);
  float distance_from_center = length(centered) / 0.70710678;
  float vignette_amount = clamp(distance_from_center - 0.4, 0.0, 1.0) * u_vignette;
  color *= 1.0 - vignette_amount;

  color = screen_blend(color, texture(u_scratch_texture, uv), u_scratch);
  color = screen_blend(color, texture(u_leak_texture, uv), u_leak);
  color = screen_blend(color, texture(u_dust_texture, uv), u_dust);

  frag_color = vec4(clamp(color, 0.0, 1.0), source.a);
}
