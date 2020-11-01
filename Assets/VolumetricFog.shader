Shader "Custom/VolumetricFog"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            #include "UnityCG.cginc"
            #include "Fog.cginc"

            sampler2D _MainTex;
            sampler2D _NoiseTex;
            sampler2D _CameraDepthTexture;
            uniform float4 _CamWorldSpace;
            
            // uniform float _ExtinctionCoef;
            uniform float4x4 _CamFrustum, _CamToWorldMatrix;
            // uniform float4 _Phase;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 ray : TEXCOORD1;
                float4 scrPos : TEXCOORD2;
            };

            v2f vert (appdata v)
            {
                v2f o;
                half index = v.vertex.z;
                v.vertex.z = 0;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.scrPos = ComputeScreenPos(o.vertex);

                o.ray = _CamFrustum[(int)index];

                o.ray /= abs(o.ray.z);

                o.ray = mul(_CamToWorldMatrix, o.ray);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                half linearDepth = (SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv));
                // float linearDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
                linearDepth = LinearEyeDepth(linearDepth);
                // linearDepth = Linear01Depth(linearDepth);
                // linearDepth = linearDepth * _ProjectionParams.z;

                float4 tex = tex2D(_MainTex, i.uv);
                float2 noiseUV = i.uv;
                // noiseUV.y += frand(noiseUV.x * 10.0);
                float offset = tex2D(_NoiseTex, noiseUV * 3.0).r;
                // float2 interleavedPosition = (fmod(floor(i.vertex.xy), 8.0));
                // float offset = tex2D(_NoiseTex, interleavedPosition / 8.0 + float2(0.5/8.0, 0.5/8.0)).w;
                float3 rayDir = normalize(i.ray.xyz);
                float3 rayOrigin = _CamWorldSpace;
                float4 fog = getFog(rayDir, rayOrigin, linearDepth,offset);

                return float4(tex.rgb, 1.0 - fog.a) + fog;
                // return float4(frac(linearDepth),frac(linearDepth),frac(linearDepth) ,1.0);
                // return float4(linearDepth,linearDepth, linearDepth ,1.0);
            }
            ENDCG
        }
    }
}
