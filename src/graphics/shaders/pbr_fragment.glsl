#version 330 core

struct Material {
  vec3 ambient;
  vec3 diffuse;
  vec3 specular;
  float shininess;
};

in vec3 Normal;
in vec2 TexCoord;
in vec3 FragPos;

out vec4 FragColor;

uniform vec3 r_viewPos;
uniform Material material;
uniform int u_useTextures;
uniform sampler2D u_baseColorTex;
uniform sampler2D u_metalRoughTex;

#include "lighting"

void main() {
    vec3 normal = normalize(Normal);
    vec3 viewDir = normalize(r_viewPos - FragPos);

    if (u_useTextures != 0) {
        vec3 baseColor = texture(u_baseColorTex, TexCoord).rgb;

        vec2 metalRough = texture(u_metalRoughTex, TexCoord).bg;
        float metallic = metalRough.x;
        float roughness = metalRough.y;

        vec3 color = calcPBRLighting(normal, viewDir, FragPos, baseColor, metallic, roughness);

        // HDR tonemap (Reinhard) + gamma correction
        color = color / (color + vec3(1.0));
        color = pow(color, vec3(1.0/2.2));

        FragColor = vec4(color, 1.0);
    } else {
        vec3 color = calcLighting(normal, viewDir, FragPos, material.ambient, material.diffuse, material.specular, material.shininess);
        FragColor = vec4(color, 1.0);
    }
}
