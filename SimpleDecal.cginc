#if !defined(SIMPLE_DECAL_INCLUDED)
#define SIMPLE_DECAL_INCLUDED

// #include "Lighting.cginc"
#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"
// #include "UnityDeferredLibrary.cginc"

uniform half4 _Color;
uniform sampler2D _MainTex;
uniform sampler2D _BumpMap;
uniform sampler2D _CameraDepthTexture;
uniform sampler2D _CameraDepthNormalsTexture;
float4 _MainTex_ST;
float4 _BumpMap_ST;
float4x4 _viewToWorld;
float3 _up;
float _Metallic;
float _Smoothness;
float _BumpScale;

struct VSInput 
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float3 texcoord : TEXCOORD0;
};

struct VSOut 
{
    float4 position : SV_POSITION;
    float4 screenPos : TEXCOORD0;
    float3 ray : TEXCOORD2;
    float4 posWorld : TEXCOORD3;
    float3 normal : NORMAL;
    float3 normalWorld : TEXCOORD4;
    float3 binormalWorld : TEXCOORD5;
    float3 tangentWorld : TEXCOORD6;
};

VSOut vert (VSInput v)
{
    VSOut o ;
    o.position = UnityObjectToClipPos(v.vertex);
    o.screenPos = ComputeScreenPos(o.position);
    o.ray = UnityObjectToViewPos(v.vertex).xyz * float3(-1,-1,1);

    // v.texcoord is equal to 0 when we are drawing 3D light shapes and
    // contains a ray pointing from the camera to one of near plane's
    // corners in camera space when we are drawing a full screen quad.
    o.ray = lerp(o.ray, v.texcoord, v.texcoord.z != 0);
    o.normal = v.normal;
    return o;
}

float SampleDepthF(float2 pixelOffset, float4 screenPos)
{
    float depth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, (screenPos.xy / screenPos.w) + (pixelOffset)));
    return depth;
}

float SampleDepth(float x, float y, float4 screenPos)
{
    return SampleDepthF(float2(x, y), screenPos);
}

float3 DepthWorld(float x, float y, float4 screenPos, float3 ray)
{
    float depth = SampleDepth(x, y, screenPos);
    float4 prjPos = float4(ray * depth, 1);
    float3 worldPos = mul(unity_CameraToWorld, prjPos).xyz;
    float4 objPos = mul(unity_WorldToObject, float4(worldPos, 1));
    float3 viewPos = mul((float3x3)UNITY_MATRIX_V, worldPos.xyz);
    return viewPos.xyz;
}

float3 rayFromScreenUV(in float2 uv, in float4x4 InvMatrix)
{
    float x = uv.x * 2.0 - 1.0;
    float y = uv.y * 2.0 - 1.0;
    float4 position_s = float4(x, y, 1.0, 1.0);
    return mul(InvMatrix, position_s * _ProjectionParams.z);
}

float3 viewSpacePosAtPosition(float2 pos)
{
    float rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, pos);
    float2 uv = pos;
    float3 ray = rayFromScreenUV(uv, unity_CameraInvProjection);
    return ray * Linear01Depth(rawDepth);
}

float3 DepthNow(float x, float y, float4 screenPos, float3 na)
{
    return viewSpacePosAtPosition((screenPos.xy / screenPos.w) + float2(x, y));
}

fixed4 frag(VSOut i) : Color
{	    			
    // Get correct view direction
    i.ray = i.ray * (_ProjectionParams.z / i.ray.z);

    // Get depth in the current pixel
    float depth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.screenPos.xy / i.screenPos.w));

    // Get new projection coordinates. It is almost like original o.position, 
    // except that Z axis is using depth information. Such taht we are ignoring our projected object, Z values
    float4 prjPos = float4(i.ray * depth, 1);
    float3 worldPos = mul(unity_CameraToWorld, prjPos).xyz;
    float4 objPos = mul(unity_WorldToObject, float4(worldPos, 1));

    clip(float3(0.5, 0.5, 0.5) - abs(objPos.xyz));
    float2 uv = _MainTex_ST.xy * (objPos.xz + 0.5);

    float3 normal = float3(0, 0, 0);
    float2 stepSize = float2(1, 1) / _ScreenParams.xy;
    {
        float3 wrld0 = DepthNow(0, 0, i.screenPos, i.ray);
        // return float4(wrld0, 1);
        float3 wrld1 = DepthNow(stepSize.x, 0, i.screenPos, i.ray);
        float3 wrld2 = DepthNow(0, -stepSize.y, i.screenPos, i.ray);
        // normal = cross(worldPos, cross(wrld1, wrld2));
        // normal = cross(wrld1, wrld2);
        normal = -normalize(cross(wrld1 - wrld0, wrld2 - wrld0));
        // normal = normalize(cross(wrld1 - wrld0, wrld1 - wrld2));
    }

    // Normals
    float4 depthnormal = tex2D(_CameraDepthNormalsTexture, i.screenPos.xy / i.screenPos.w);
    // float3 normal;
    float depth2;
    // DecodeDepthNormal(depthnormal, depth2, normal);
    // return float4(normal, 1.0);
    // float3 worldNormal = mul((float3x3)_viewToWorld, normal);
    float3 worldNormal = mul((float3x3)UNITY_MATRIX_I_V, normal);
    // float3 worldNormal = mul((float3x3)unity_CameraToWorld, normal);
    // return float4(worldNormal, 1.0);
    // float up = dot(worldNormal, _up);
    float3 up2 = float3(0, 1, 0);
    up2 = normalize(mul((float3x3)unity_ObjectToWorld, up2));
    float up = dot(worldNormal, up2);
    float3 worldNormal2 = normalize(UnpackScaleNormal(tex2D(_BumpMap, uv.xy), _BumpScale).xyz);
    // worldNormal2 = normalize(worldNormal2);
    // float3 tangent = cross(_up, worldNormal);
    float3 tangent = cross(worldNormal2, up2);
    float3 binormal = cross(worldNormal, tangent);
    worldNormal2 = normalize(worldNormal2.x * tangent + worldNormal2.y * binormal + worldNormal2.z * worldNormal);
    // return float4(worldNormal2, 1);
    fixed4 c = tex2D(_MainTex, uv.xy);
    c = float4(c.rgb * _Color.rgb, (c.a * _Color.a * up));
    float a = c.a;

    // lighting
    #if defined(POINT) || defined(POINT_COOKIE) || defined(SPOT)
    float3 lightDir = normalize(_WorldSpaceLightPos0.xyz - worldPos);
    #else
    float3 lightDir = _WorldSpaceLightPos0.xyz;
    #endif
    float3 viewDir = normalize(_WorldSpaceCameraPos - worldPos);
    UNITY_LIGHT_ATTENUATION(attenuation, i, worldPos);
    float3 lightColor = _LightColor0.rgb * attenuation;
    float3 specularTint;
    float oneMinusReflectivity;
    float3 diffuse = DiffuseAndSpecularFromMetallic(c, _Metallic, specularTint, oneMinusReflectivity);
    c = float4(diffuse, c.a);

    UnityLight light;
    light.color = lightColor;
    light.dir = lightDir;
    light.ndotl = DotClamped(worldNormal2, lightDir);
    UnityIndirect indirectLight;
    indirectLight.diffuse = 0;
    indirectLight.specular = 0;
    #if defined(FORWARD_BASE_PASS)
    indirectLight.diffuse += max(0, ShadeSH9(float4(worldNormal2, 1)));
    #endif

    c = UNITY_BRDF_PBS(c, specularTint, oneMinusReflectivity, _Smoothness, worldNormal2, viewDir, light, indirectLight);
    c.a = a;
    return c;
}

#endif