#version 330

varying vec2 vertex;
varying vec2 texCoord;

uniform sampler2D tex;
uniform float time;
uniform vec2 resolution;

void main(void) {
  vec4 color = vec4(1.2);
  gl_FragColor = texture2D(tex, texCoord) * color;
}

