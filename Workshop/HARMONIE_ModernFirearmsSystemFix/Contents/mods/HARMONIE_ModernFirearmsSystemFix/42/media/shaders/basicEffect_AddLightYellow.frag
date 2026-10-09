#version 110

varying vec3 vertColour; 
varying vec3 vertNormal;
varying vec2 texCoords;

uniform sampler2D Texture;
uniform float Alpha;
uniform float LightingAmount;

uniform vec3 TintColour;

uniform vec3 AmbientColour;
uniform vec3 Light0Direction;
uniform vec3 Light0Colour;
uniform vec3 Light1Direction;
uniform vec3 Light1Colour;
uniform vec3 Light2Direction;
uniform vec3 Light2Colour;
uniform vec3 Light3Direction;
uniform vec3 Light3Colour;
uniform vec3 Light4Direction;
uniform vec3 Light4Colour;
uniform float HueChange;

#include "util/math"
#include "util/hueShift"

void main()
{
    vec3 normal = normalize(vertNormal);

    vec4 texSample = texture2D(Texture, texCoords);

    if(texSample.w < 0.01)
    {
        discard;
    }

    vec3 col = texSample.xyz;

    float dotprod;
    if(HueChange != 0.0)
    {
        col = hueShift(col, HueChange);
    }

    const float QuantiseLevels = 8.0;
    vec3 lighting = vec3(0.0);

    dotprod = max(dot(normal, normalize(Light0Direction)), 0.0);
    lighting += Light0Colour * dotprod;

    dotprod = max(dot(normal, normalize(Light1Direction)), 0.0);
    lighting += Light1Colour * dotprod;

    dotprod = max(dot(normal, normalize(Light2Direction)), 0.0);
    lighting += Light2Colour * dotprod;

    dotprod = max(dot(normal, normalize(Light3Direction)), 0.0);
    lighting += Light3Colour * dotprod;

    dotprod = max(dot(normal, normalize(Light4Direction)), 0.0);
    lighting += Light4Colour * dotprod;

    lighting += AmbientColour;
    lighting.x = min(lighting.x, 1.0);
    lighting.y = min(lighting.y, 1.0);
    lighting.z = min(lighting.z, 1.0);
    
    float greenThreshold = 0.4; // 设置一个阈值，高于此阈值的绿色将被转换为红色
    float greenThreshold = 0.4;
    if(col.y > greenThreshold)
    {
        // 绿色转淡黄色（保留高红+高绿，减少蓝色）
        col.x = 0.9;  // 高红色（增强黄色调）
        col.y = 0.9;  // 保持高绿色
        col.z = 0.2;  // 少量蓝色（降低纯度，实现"淡"效果）
    }

    vec3 tintColour = TintColour;
    if (col.x > 0.7)
    {
        col = vec3(col.x * tintColour.x , col.y * tintColour.y * lighting.y, col.z * tintColour.z * lighting.z);
    }
    else
    {
        col = vec3(col.x * tintColour.x * lighting.x, col.y * tintColour.y * lighting.y, col.z * tintColour.z * lighting.z);
    }



    // 限制颜色值在0.0到1.0之间
    col = clamp(col, 0.0, 1.0);

    vec4 fragCol = vec4(Alpha * col * vertColour, Alpha * texSample.w);
    gl_FragColor = fragCol;
}