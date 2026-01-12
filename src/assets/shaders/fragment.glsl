#version 330 core

in vec3 vertexPos;

out vec4 FragColor;

void main() {
  FragColor = vec4(vertexPos.x + 0.5, vertexPos.y + 0.5, 0.5 - vertexPos.x, 1);
}
