Shader "Unlit/ProjectorShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
		Tags {"Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "Transparent"}
        ZWrite Off
    	ZTest Off
    	Cull Off
		Blend SrcAlpha OneMinusSrcAlpha
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag


            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 screenPos : TEXCOORD1;
                half3 scale : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            uniform sampler2D _CameraDepthTexture; //Depth Texture
            float4x4 _InverseView;
            sampler2D _CameraGBufferTexture2;

            half3 ObjectScale() {
                return half3(
                    length(unity_ObjectToWorld._m00_m10_m20),
                    length(unity_ObjectToWorld._m01_m11_m21),
                    length(unity_ObjectToWorld._m02_m12_m22)
                    );
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.screenPos = ComputeScreenPos(o.vertex);
                o.scale = ObjectScale();
                return o;
            }


            float3 WorldPosFromDepth(float2 uv)
            {
                const float2 p11_22 = float2(unity_CameraProjection._11, unity_CameraProjection._22);
                const float2 p13_31 = float2(unity_CameraProjection._13, unity_CameraProjection._23);
                const float isOrtho = unity_OrthoParams.w;
                const float near = _ProjectionParams.y;
                const float far = _ProjectionParams.z;

                float d = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
#if defined(UNITY_REVERSED_Z)
                d = 1 - d;
#endif
                float zOrtho = lerp(near, far, d);
                float zPers = near * far / lerp(far, near, d);
                float vz = lerp(zPers, zOrtho, isOrtho);

                float3 vpos = float3((uv * 2 - 1 - p13_31) / p11_22 * lerp(vz, 1, isOrtho), -vz);
                float3 wpos = mul(_InverseView, float4(vpos, 1)).xyz;

                return wpos;
            }


            float3 CapsulePos(float3 pos)
            {
                return mul(unity_ObjectToWorld, float4(pos, 1));
            }

            bool IsInsideCapsule( float3 pos1, float3 pos2, float3 pointToCheck, float radius)
            {                
                pos1 = CapsulePos(pos1);
                pos2 = CapsulePos(pos2);

                float3 direction = pos2 - pos1;

                if (distance(pos1, pointToCheck)<radius || distance(pos2, pointToCheck) < radius) {
                    return true;
                }

                float3 pDir = pointToCheck - pos1;
                float dotVal = dot(direction, pDir);
                float lengthsq = pow(length(direction), 2);

                if (dotVal < 0 || dotVal > lengthsq) return false;

                float dsq = pDir.x * pDir.x + pDir.y * pDir.y + pDir.z * pDir.z - dotVal * dotVal / lengthsq;

                if (dsq > radius * radius) {
                    return false;
                }
                else {
                    return true;
                }
            }


            fixed4 frag (v2f i) : SV_Target
            {
                //get screenspace depth and wPOs from it
				float2 uvScreenSpace = (i.screenPos.xy / i.screenPos.w);
                float3 wpos = WorldPosFromDepth(uvScreenSpace);

                //check capsule volume
                const float size = 0.33;
                float radius = min(i.scale.x, i.scale.z) * size;
                bool contains = IsInsideCapsule(float3(0, -size, 0), float3(0, size, 0), wpos, radius);
                if (!contains) discard;

                //triplanar mapping
            	half4 gbuffer1 = tex2D(_CameraGBufferTexture2, uvScreenSpace); //get normal buffer

                float2 uvTr = wpos.xy;
                if(abs(dot(gbuffer1.xyz, float3(0, 1, 0))) > 0.99)
                {
                    uvTr = wpos.xz;
                }
                else
                {
                    if (abs(dot(gbuffer1.xyz, float3(1, 0, 0))) > 0.5)
                    {
                        uvTr = wpos.zy;
                    }
                }

                //sample texture
                fixed4 col = tex2D(_MainTex, uvTr*5) * float4(0,1,0,1);

                return col;
            }
            ENDCG
        }
    }
}
