precision mediump float;

uniform sampler2D uTexSampler;
uniform sampler2D uScratchTexture;
uniform sampler2D uLeakTexture;
uniform sampler2D uDustTexture;
uniform vec2 uSize;
uniform float uTemperature;
uniform float uSaturation;
uniform float uContrast;
uniform float uBrightness;
uniform float uShadowLift;
uniform float uTintStrength;
uniform float uRedGamma;
uniform float uGreenGamma;
uniform float uBlueGamma;
uniform vec3 uHighlightTint;
uniform vec3 uShadowTint;
uniform float uGrain;
uniform float uGrainSize;
uniform float uGrainColored;
uniform float uVignette;
uniform float uScratch;
uniform float uLeak;
uniform float uDust;
uniform float uHalation;
varying vec2 vTexSamplingCoord;

float hashNoise(vec2 p) {
  float h = sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453;
  return fract(h);
}

float smoothTone(float edge0, float edge1, float x) {
  float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

float contrastCurve(float x, float contrast) {
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

vec3 screenBlend(vec3 base, vec4 overlay, float strength) {
  float alpha = overlay.a * strength * 0.5;
  return 1.0 - (1.0 - base) * (1.0 - overlay.rgb * alpha);
}

vec3 halationFromSample(vec3 sampleColor) {
  float luminance = dot(sampleColor, vec3(0.299, 0.587, 0.114));
  float redBias = max(0.0, sampleColor.r - max(sampleColor.g, sampleColor.b) * 0.5);
  float amount = smoothTone(0.78, 1.0, luminance) * (0.2 + redBias) * uHalation * (24.0 / 255.0);
  return vec3(amount, amount * 0.35, amount * 0.06);
}

vec3 addHalation(vec2 uv, vec3 color) {
  if (uHalation <= 0.0) {
    return color;
  }
  vec2 texel = 1.0 / uSize;
  vec3 halo = vec3(0.0);
  halo += halationFromSample(texture2D(uTexSampler, uv + vec2(-texel.x, 0.0)).rgb);
  halo += halationFromSample(texture2D(uTexSampler, uv + vec2(texel.x, 0.0)).rgb);
  halo += halationFromSample(texture2D(uTexSampler, uv + vec2(0.0, -texel.y)).rgb);
  halo += halationFromSample(texture2D(uTexSampler, uv + vec2(0.0, texel.y)).rgb);
  return color + halo;
}

void main() {
  vec2 uv = vTexSamplingCoord;
  vec4 source = texture2D(uTexSampler, uv);
  vec3 color = addHalation(uv, source.rgb);

  float luminance = dot(color, vec3(0.299, 0.587, 0.114));
  float temperature = uTemperature * (24.0 / 255.0) * (1.0 - luminance * luminance);
  color += vec3(temperature, temperature * 0.18, -temperature);
  color = clamp(color, 0.0, 1.0);

  color = pow(color, vec3(uRedGamma, uGreenGamma, uBlueGamma));
  luminance = dot(color, vec3(0.299, 0.587, 0.114));
  color = vec3(luminance) + (color - vec3(luminance)) * uSaturation;

  color.r = contrastCurve(color.r, uContrast);
  color.g = contrastCurve(color.g, uContrast);
  color.b = contrastCurve(color.b, uContrast);

  if (uBrightness > 0.0) {
    color += uBrightness * (1.0 - color);
  } else {
    color += vec3(uBrightness);
  }

  if (uTintStrength > 0.0) {
    luminance = dot(color, vec3(0.299, 0.587, 0.114));
    float highlightMix = smoothTone(0.55, 0.92, luminance) * uTintStrength;
    float shadowMix = (1.0 - smoothTone(0.08, 0.45, luminance)) * uTintStrength;
    color = mix(color, uHighlightTint * (240.0 / 255.0), highlightMix);
    color = mix(color, uShadowTint, shadowMix);
  }

  color += uShadowLift * pow(1.0 - color, vec3(2.0));
  color = vec3(shoulder(color.r), shoulder(color.g), shoulder(color.b));

  if (uGrain > 0.0) {
    float scale = 3.4 * clamp(uGrainSize, 0.5, 2.0);
    float visibility = 0.35 + (1.0 - dot(color, vec3(0.299, 0.587, 0.114))) * 0.65;
    float amount = uGrain * (38.0 / 255.0) * visibility;
    vec2 p = gl_FragCoord.xy / scale;
    float noiseR = hashNoise(p) - 0.5;
    float noiseG = hashNoise(p + vec2(11.0, 7.0)) - 0.5;
    float noiseB = hashNoise(p + vec2(23.0, 19.0)) - 0.5;
    vec3 mono = vec3(noiseR);
    vec3 chroma = vec3(noiseR, noiseG * 0.85, noiseB * 1.1);
    color += mix(mono, chroma, clamp(uGrainColored, 0.0, 1.0)) * amount;
  }

  vec2 centered = uv - vec2(0.5);
  float distanceFromCenter = length(centered) / 0.70710678;
  float vignetteAmount = clamp(distanceFromCenter - 0.4, 0.0, 1.0) * uVignette;
  color *= 1.0 - vignetteAmount;

  color = screenBlend(color, texture2D(uScratchTexture, uv), uScratch);
  color = screenBlend(color, texture2D(uLeakTexture, uv), uLeak);
  color = screenBlend(color, texture2D(uDustTexture, uv), uDust);

  gl_FragColor = vec4(clamp(color, 0.0, 1.0), source.a);
}
