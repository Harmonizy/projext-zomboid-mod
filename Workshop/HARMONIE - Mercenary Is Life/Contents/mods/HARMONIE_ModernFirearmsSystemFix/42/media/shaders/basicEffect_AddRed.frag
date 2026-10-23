#version 110

varying vec3 vertColour; 
varying vec3 vertNormal;
varying vec2 texCoords;

uniform sampler2D Texture;
uniform float Alpha;
uniform float LightingAmount; // 注意：此变量在主函数中未被使用

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
    
    // --- 主要修改点在这里 ---
    // 将大于阈值的绿色转换为黄色
    float greenThreshold = 0.4; // 设置一个阈值，高于此阈值的绿色将被转换
    if(col.y > greenThreshold)
    {
        // 原始逻辑: col = vec3(1.0, 0.0, 0.0); // 红色
        col = vec3(1.0, 1.0, 0.0); // 黄色 (R=1, G=1, B=0)
        // 你也可以尝试更鲜艳或不同色调的黄色，例如:
        // col = vec3(1.0, 0.8, 0.0); // 偏橙的黄色
        // col = vec3(0.9, 1.0, 0.1); // 偏绿的黄色
    }
    // --- 修改结束 ---

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