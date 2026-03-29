#version 330 core

in vec2 TexCoord;
out vec4 FragColor;

uniform sampler2D u_screenTexture;
uniform float u_exposure;
uniform float u_gamma;

void main() {
    vec3 hdrColor = texture(u_screenTexture, TexCoord).rgb;

    // Exposure tone mapping
    vec3 mapped = vec3(1.0) - exp(-hdrColor * u_exposure);

    // Gamma correction
    mapped = pow(mapped, vec3(1.0 / u_gamma));

    FragColor = vec4(mapped, 1.0);
}
