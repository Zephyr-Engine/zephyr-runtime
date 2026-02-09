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
