#version 330 core

layout(location = 0) in vec3 aPos;
layout(location = 1) in vec3 aNormal;
layout(location = 2) in vec2 aTexCoord;

out vec3 Normal;
out vec2 TexCoord;
out vec3 FragPos;

uniform mat4 r_model;
uniform mat4 r_position;

void main() {
    Normal = mat3(transpose(inverse(r_model))) * aNormal;
    TexCoord = aTexCoord;
    FragPos = vec3(r_model * vec4(aPos, 1.0));

    gl_Position = r_position * vec4(aPos, 1.0);
}
