Shader "Replay/UnlitAuroraShader"
{
    Properties
    {
        _SpeedHack ("Step Size", Range(0.01, 3)) = 1

        _AuroraSize("Aurora Size", Range(0, 10)) = 1
        _Opacity ("Opacity", Range(0, 10)) = 0.1

        _Glow("Glow", Range(0, 0.1)) = 0.001

        _WiggleSpeed ("Wiggle Speed", Range(0, 1)) = 0.2
        _ScrollSpeed ("Scroll Speed", Range(0, 1)) = 0.002

        _PerlinTex("Texture", 2D) = "white" {}
        _PerlinSeed ("Perlin Seed", float) = 0.002
    }

    SubShader
    {
        Tags {"RenderType" = "Transparent" "Queue"="Transparent" "RenderPipeline" = "UniversalPipeline"}
        
        ZWrite Off
        Blend One One

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 vertex : SV_POSITION;
                float3 viewDir : TEXCOORD0;
            };

            sampler2D _PerlinTex;

            float _SpeedHack;

            float _Opacity;
            float _Glow;
            float _AuroraSize;

            float _ScrollSpeed;
            float _WiggleSpeed;

            float _PerlinSeed;

            float4x4 _ToWorldWithoutScale;
            float4 _BoundsSize;

            // https://stackoverflow.com/a/3115514
            // Worse AABB I've ever seen
            // TODO: Make it better
            inline void IntersectrdBox(float3 origin, float3 size, float3 rd, out float t0, out float t1)
            {
                float3 segmentBegin = _WorldSpaceCameraPos;
                float3 segmentEnd = _WorldSpaceCameraPos + rd * _ProjectionParams.z;
                
                float3 beginToEnd = segmentEnd - segmentBegin;
                float3 minToMax = float3(size.x, size.y, size.z);
                float3 minPoint = origin - minToMax / 2;
                float3 maxPoint = origin + minToMax / 2;
                float3 beginToMin = minPoint - segmentBegin;
                float3 beginToMax = maxPoint - segmentBegin;
                float tNear = -99999999;
                float tFar = 99999999;
                float dst = length(beginToEnd);
            
                t0 = t1 = 0;
                
                for (int axis = 0; axis < 3; axis++)
                {
                    if (beginToEnd[axis] == 0)
                    {
                        if (beginToMin[axis] > 0 || beginToMax[axis] < 0)
                            discard;
                    }
                    else
                    {
                        float d0 = beginToMin[axis] / beginToEnd[axis];
                        float d1 = beginToMax[axis] / beginToEnd[axis];
                        float tMin = min(d0, d1);
                        float tMax = max(d0, d1);
                        if (tMin > tNear) tNear = tMin;
                        if (tMax < tFar) tFar = tMax;
                        if (tNear > tFar || tFar < 0) discard;
                    }
                }
                if (tNear >= 0 && tNear <= 1) t0 = (dst * tNear);
                if (tFar >= 0 && tFar <= 1) t1 = (dst * tFar);
            
                t0 = max(t0, 0);
                t1 = max(t1, 0);
            
                t0 = min(t0, t1);
                t1 = max(t0, t1);
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                OUT.vertex = TransformObjectToHClip(IN.positionOS.xyz);
                
                OUT.viewDir = GetWorldSpaceViewDir(TransformObjectToWorld(IN.positionOS.xyz));
                OUT.viewDir *= -1;

                return OUT;
            }

            float GetNoise(float3 worldPos, out float height)
            {
                float2 offset1 = float2(_WiggleSpeed, _WiggleSpeed) * _Time.x;
                float2 offset2 = float2(_ScrollSpeed, _ScrollSpeed) * _Time.y;
                real4 perlin1 = tex2Dlod(_PerlinTex, float4((worldPos.xz + float2(_PerlinSeed, _PerlinSeed)) / _AuroraSize + offset1, 0, 0));
                real4 perlin2 = tex2Dlod(_PerlinTex, float4((worldPos.xz + float2(_PerlinSeed, _PerlinSeed)) / _AuroraSize + offset2, 0, 0));
                float threshold = _Glow;
                float push = 68.26;
                float noise = abs(perlin1.b - perlin2.g);
                noise = abs(perlin1.b - perlin2.g);
                noise = (noise - threshold) * push + threshold;
                
                height = perlin1.a;
                
                return 1 - saturate(noise);
            }

            float4 frag(Varyings IN) : SV_Target
            {
                float3 rd = normalize(IN.viewDir);
                float dst;
                float maxDst;
                
                float3 boundsOrigin = mul(_ToWorldWithoutScale, float4(0, 0, 0, 1));
                IntersectrdBox(boundsOrigin, _BoundsSize, rd, dst, maxDst);
                
                float4 color = float4(0,0,0,0);
                float opacityPerStep = _Opacity * _SpeedHack;

                while (dst < maxDst)
                {
                    float3 pt = _WorldSpaceCameraPos + rd * dst;
                    float3 localPt = mul(unity_WorldToObject, float4(pt, 1)).xyz;
                    
                    float height;
                    float noise = GetNoise(localPt, height);

                    float saturlocalPt = Remap(1, 10, 0, 1, localPt.y + height);
                    
                    float4 shape = noise * 0.05 * saturlocalPt;
                    float4 col2 = float4(0,0,0,shape.x);
                    col2.rgb = (sin(1.-float3(2.15,-.5, 1.2) + (saturlocalPt + 0.49) * 30)*0.5+0.5)*shape;

                    // Mask out the edges to get a smoother look.
                    float edgeMaskX = 1 - (abs(localPt.x) * 2);
                    float edgeMaskZ = 1 - (abs(localPt.z) * 2);
                    float edgeMask = min(edgeMaskX, edgeMaskZ);

                    color += col2 * exp2(-saturlocalPt * 20) * edgeMask * opacityPerStep;
                    dst += _SpeedHack;
                }

                return float4(color.rgb * color.a, 1);
            }
            ENDHLSL
        }
    }
}
