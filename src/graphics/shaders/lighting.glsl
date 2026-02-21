#define MAX_LIGHTS 16

#define LIGHT_DIRECTIONAL 0
#define LIGHT_POINT 1
#define LIGHT_SPOT 2

struct Light {
  int kind;
  vec3 position;
  vec3 direction;
  vec3 ambient;
  vec3 diffuse;
  vec3 specular;
  float constant;
  float linear;
  float quadratic;
  float cutOff;
  float outerCutOff;
};

uniform int numLights;
uniform Light lights[MAX_LIGHTS];

vec3 calcDirectional(Light light, vec3 normal, vec3 viewDir, vec3 fragPos, vec3 matAmbient, vec3 matDiffuse, vec3 matSpecular, float matShininess) {
    vec3 lightDir = normalize(-light.direction);

    float diff = max(dot(normal, lightDir), 0.0);

    vec3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), matShininess);

    vec3 ambient  = light.ambient  * matAmbient;
    vec3 diffuse  = light.diffuse  * (diff * matDiffuse);
    vec3 specular = light.specular * (spec * matSpecular);

    return ambient + diffuse + specular;
}

vec3 calcPoint(Light light, vec3 normal, vec3 viewDir, vec3 fragPos, vec3 matAmbient, vec3 matDiffuse, vec3 matSpecular, float matShininess) {
    vec3 lightDir = normalize(light.position - fragPos);

    float diff = max(dot(normal, lightDir), 0.0);

    vec3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), matShininess);

    float distance = length(light.position - fragPos);
    float attenuation = 1.0 / (light.constant + light.linear * distance + light.quadratic * distance * distance);

    vec3 ambient  = light.ambient  * matAmbient  * attenuation;
    vec3 diffuse  = light.diffuse  * (diff * matDiffuse)  * attenuation;
    vec3 specular = light.specular * (spec * matSpecular) * attenuation;

    return ambient + diffuse + specular;
}

vec3 calcSpot(Light light, vec3 normal, vec3 viewDir, vec3 fragPos, vec3 matAmbient, vec3 matDiffuse, vec3 matSpecular, float matShininess) {
    vec3 lightDir = normalize(light.position - fragPos);

    float diff = max(dot(normal, lightDir), 0.0);

    vec3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), matShininess);

    float distance = length(light.position - fragPos);
    float attenuation = 1.0 / (light.constant + light.linear * distance + light.quadratic * distance * distance);

    float theta = dot(lightDir, normalize(-light.direction));
    float epsilon = light.cutOff - light.outerCutOff;
    float intensity = clamp((theta - light.outerCutOff) / epsilon, 0.0, 1.0);

    vec3 ambient  = light.ambient  * matAmbient  * attenuation;
    vec3 diffuse  = light.diffuse  * (diff * matDiffuse)  * attenuation * intensity;
    vec3 specular = light.specular * (spec * matSpecular) * attenuation * intensity;

    return ambient + diffuse + specular;
}

// ── PBR (Cook-Torrance) helpers ──────────────────────────────────────

const float PI = 3.14159265359;

// Fresnel-Schlick approximation
vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

// GGX normal distribution function
float distributionGGX(vec3 N, vec3 H, float roughness) {
    float a  = roughness * roughness;
    float a2 = a * a;
    float NdotH  = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;
    float denom  = NdotH2 * (a2 - 1.0) + 1.0;
    return a2 / (PI * denom * denom);
}

// Schlick-GGX geometry (single direction)
float geometrySchlickGGX(float NdotV, float roughness) {
    float r = roughness + 1.0;
    float k = (r * r) / 8.0;
    return NdotV / (NdotV * (1.0 - k) + k);
}

// Smith's method (both view and light directions)
float geometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    return geometrySchlickGGX(NdotV, roughness) * geometrySchlickGGX(NdotL, roughness);
}

// Evaluate a single light using Cook-Torrance BRDF
vec3 calcPBRLight(Light light, vec3 N, vec3 V, vec3 fragPos, vec3 baseColor, float metallic, float roughness) {
    vec3 F0 = mix(vec3(0.04), baseColor, metallic);

    // Light direction & radiance
    vec3 L;
    float attenuation = 1.0;
    float spotIntensity = 1.0;

    if (light.kind == LIGHT_DIRECTIONAL) {
        L = normalize(-light.direction);
    } else {
        L = normalize(light.position - fragPos);
        float distance = length(light.position - fragPos);
        attenuation = 1.0 / (light.constant + light.linear * distance + light.quadratic * distance * distance);

        if (light.kind == LIGHT_SPOT) {
            float theta   = dot(L, normalize(-light.direction));
            float epsilon = light.cutOff - light.outerCutOff;
            spotIntensity = clamp((theta - light.outerCutOff) / epsilon, 0.0, 1.0);
        }
    }

    vec3 radiance = light.diffuse * attenuation * spotIntensity;

    vec3 H = normalize(V + L);
    float NdotL = max(dot(N, L), 0.0);

    // Cook-Torrance specular BRDF
    float D = distributionGGX(N, H, roughness);
    float G = geometrySmith(N, V, L, roughness);
    vec3  F = fresnelSchlick(max(dot(H, V), 0.0), F0);

    vec3 numerator   = D * G * F;
    float denominator = 4.0 * max(dot(N, V), 0.0) * NdotL + 0.0001;
    vec3 specular    = numerator / denominator;

    // Energy-conserving diffuse
    vec3 kD = (vec3(1.0) - F) * (1.0 - metallic);
    vec3 diffuse = kD * baseColor / PI;

    return (diffuse + specular) * radiance * NdotL;
}

// Full PBR lighting: iterate all lights + hemisphere ambient
vec3 calcPBRLighting(vec3 normal, vec3 viewDir, vec3 fragPos, vec3 baseColor, float metallic, float roughness) {
    vec3 color = vec3(0.0);

    for (int i = 0; i < numLights && i < MAX_LIGHTS; i++) {
        color += calcPBRLight(lights[i], normal, viewDir, fragPos, baseColor, metallic, roughness);
    }

    // Hemisphere ambient (approximates indirect lighting without IBL)
    color += baseColor * 0.15;

    return color;
}

// ── Phong aggregate ──────────────────────────────────────────────────

vec3 calcLighting(vec3 normal, vec3 viewDir, vec3 fragPos, vec3 matAmbient, vec3 matDiffuse, vec3 matSpecular, float matShininess) {
    vec3 color = vec3(0.0);

    for (int i = 0; i < numLights && i < MAX_LIGHTS; i++) {
        if (lights[i].kind == LIGHT_DIRECTIONAL) {
            color += calcDirectional(lights[i], normal, viewDir, fragPos, matAmbient, matDiffuse, matSpecular, matShininess);
        } else if (lights[i].kind == LIGHT_POINT) {
            color += calcPoint(lights[i], normal, viewDir, fragPos, matAmbient, matDiffuse, matSpecular, matShininess);
        } else if (lights[i].kind == LIGHT_SPOT) {
            color += calcSpot(lights[i], normal, viewDir, fragPos, matAmbient, matDiffuse, matSpecular, matShininess);
        }
    }

    return color;
}
