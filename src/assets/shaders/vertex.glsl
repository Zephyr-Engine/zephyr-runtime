#version 330 core

layout(location = 0) in vec3 aPos;

uniform vec2 u_offset;

out vec3 vertexPos;

void main() {
  gl_Position = vec4(aPos.x + u_offset.x, aPos.y + u_offset.y, aPos.z, 1.0);
  vertexPos = aPos;
}
