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
uniform float u_vignette;
uniform float u_scratch;
uniform float u_leak;
uniform float u_dust;

uniform sampler2D u_input;
uniform sampler2D u_grain_texture;
uniform sampler2D u_scratch_texture;
uniform sampler2D u_leak_texture;
uniform sampler2D u_dust_texture;

out vec4 frag_color;

vec3 screen_blend(vec3 base, vec4 overlay, float strength) {
  float alpha = overlay.a * strength * 0.5;
  return 1.0 - (1.0 - base) * (1.0 - overlay.rgb * alpha);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif

  vec4 source = texture(u_input, uv);
  vec3 color = source.rgb;

  float luminance = dot(color, vec3(0.299, 0.587, 0.114));
  float temperature = u_temperature * (25.0 / 255.0) *
      (1.0 - luminance * luminance);
  color += vec3(temperature, temperature * 0.2, -temperature);
  color = clamp(color, 0.0, 1.0);

  color = pow(color, vec3(u_red_gamma, u_green_gamma, u_blue_gamma));

  luminance = dot(color, vec3(0.299, 0.587, 0.114));
  color = vec3(luminance) + (color - vec3(luminance)) * u_saturation;

  float contrast_factor =
      u_contrast > 0.0 ? 1.0 + u_contrast * 2.0 : 1.0 + u_contrast;
  color = clamp(contrast_factor * (color - 0.5) + 0.5, 0.0, 1.0);

  if (u_brightness > 0.0) {
    color += u_brightness * (1.0 - color);
  } else {
    color += vec3(u_brightness);
  }
  color = clamp(color, 0.0, 1.0);

  if (u_tint_strength > 0.0) {
    luminance = dot(color, vec3(0.299, 0.587, 0.114));
    color += (u_highlight_tint * (240.0 / 255.0) - color) *
        luminance * u_tint_strength * 0.5;
    color += (u_shadow_tint - color) *
        (1.0 - luminance) * u_tint_strength * 0.35;
  }

  color = color * (1.0 - u_shadow_lift) + u_shadow_lift;

  vec3 over = max(color - (200.0 / 255.0), 0.0);
  vec3 shoulder = (200.0 + 55.0 *
      (1.0 - exp(-(over * 255.0 / 100.0) * 2.5))) / 255.0;
  color = mix(color, shoulder, step(200.0 / 255.0, color));

  vec4 grain = texture(u_grain_texture, uv);
  float grain_alpha = grain.a * u_grain;
  color = mix(color, color * grain.rgb, grain_alpha);

  vec2 centered = uv - vec2(0.5);
  float distance_from_center = length(centered) / 0.70710678;
  float vignette_amount =
      clamp(distance_from_center - 0.4, 0.0, 1.0) * u_vignette;
  color *= 1.0 - vignette_amount;

  color = screen_blend(
      color, texture(u_scratch_texture, uv), u_scratch);
  color = screen_blend(color, texture(u_leak_texture, uv), u_leak);
  color = screen_blend(color, texture(u_dust_texture, uv), u_dust);

  frag_color = vec4(clamp(color, 0.0, 1.0), source.a);
}
