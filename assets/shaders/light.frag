#version 330

varying vec2 vertex;
varying vec2 texCoord;
varying vec4 color;

uniform sampler2D tex;
uniform float time;
uniform vec2 resolution;
uniform vec2 center; // player center on screen

void main(void) {
  float ratioX = 1.0;
  float ratioY = 1.0;

  if (resolution.x > resolution.y) {
    ratioX = resolution.x / resolution.y;
  } else {
    ratioY = resolution.y / resolution.x;
  }

  vec2 ratio = vec2(ratioX, ratioY);

  float dist = distance(center * ratio, texCoord * ratio);
  vec4 c = vec4(mix(0.0, 0.7, 1.0 - dist));
  gl_FragColor = texture2D(tex, texCoord) * c;
}

