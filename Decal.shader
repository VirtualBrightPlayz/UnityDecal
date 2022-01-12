Shader "VirtualBright/Decal"
{
    Properties {
        _MainTex ("Main Texture", 2D) = "white" {}
        [NoScaleOffset]_BumpMap ("Bump Texture", 2D) = "bump" {}
        _BumpScale ("Bump Scale", Float) = 1
        [HDR]_Color ("Color", Color) = (1, 1, 1, 1)
        [Gamma]_Metallic ("Metallic", Range(0, 1)) = 0
        _Smoothness ("Smoothness", Range(0, 1)) = 0.1
    }
    SubShader 
    {
        Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }
        Pass
        {
            Tags { "LightMode" = "ForwardBase" }
            ZWrite Off
            ZTest Off
            Cull Front
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #define FORWARD_BASE_PASS
            #pragma target 3.0
            #include "SimpleDecal.cginc"
            #pragma vertex vert
            #pragma fragment frag
            ENDCG
        }
        Pass
        {
            Tags { "LightMode" = "ForwardAdd" }
            ZWrite Off
            ZTest Off
            Cull Front
            Blend SrcAlpha One

            CGPROGRAM
            #pragma multi_compile_fwdadd_fullshadows
            #pragma target 3.0
            #include "SimpleDecal.cginc"
            #pragma vertex vert
            #pragma fragment frag
            ENDCG
        }
    } 
    FallBack "Unlit/Transparent"
}