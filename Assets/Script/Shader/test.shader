Shader "CustomRP/Depth"
{
	Properties
	{
		_BaseMap("Texture", 2D) = "white" {}
		_BaseColor("Color",color) = (1.0,1.0,1.0,1.0)

		[Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Src Blend", Float) = 1
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Dst Blend", Float) = 0
		[Enum(Off, 0, On, 1)] _ZWrite ("Z Write", Float) = 0
		[Toggle(_PREMULTIPLY_ALPHA)] _PremulAlpha ("Premultiply Alpha", Float) = 0

	}
	SubShader
	{
		Pass
		{
			Tags {
				"LightMode"="CustomLit"
			}

			Blend [_SrcBlend] [_DstBlend]
			ZWrite [_ZWrite]
			HLSLPROGRAM
			#pragma target 3.5

			#pragma vertex vert
			#pragma fragment frag


			#include "../ShaderLibrary/Common.hlsl"
			#include "../ShaderLibrary/Surface.hlsl"
			#include "../ShaderLibrary/Shadow.hlsl"
			#include "../ShaderLibrary/Light.hlsl"
			#include "../ShaderLibrary/BRDF.hlsl"
			#include "../ShaderLibrary/Lighting.hlsl"


			TEXTURE2D(_BaseMap);
			SAMPLER(sampler_BaseMap);

			UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
				UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
				UNITY_DEFINE_INSTANCED_PROP(float4,_BaseColor)
			UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

			struct Attributes
			{
				float3 positionOS : POSITION;
				float3 normalOS : NORMAL;
				float2 baseUV : TEXCOORD0;
			};

			struct Varyings
			{
				float4 positionCS : SV_POSITION;
				float3 positionWS : VAR_POSITION;
				float3 normalWS : VAR_NORMAL;
				float2 baseUV : VAR_BASE_UV;
			};

			Varyings vert(Attributes input)
			{
				Varyings output;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				float3 positionWS = TransformObjectToWorld(input.positionOS);
				output.positionCS = TransformWorldToHClip(positionWS);
				float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseMap_ST);
				output.baseUV = input.baseUV * baseST.xy + baseST.zw;
				output.normalWS = TransformObjectToWorldNormal(input.normalOS);
				output.positionWS = positionWS;
				return output;
			}


			float4 frag(Varyings input) : SV_TARGET0
			{

				Surface surface;
				surface.position = input.positionWS;
				surface.normal = normalize(input.normalWS);
				surface.viewDirection = normalize(_WorldSpaceCameraPos - input.positionWS);
				surface.depth = -TransformWorldToView(input.positionWS).z;
				surface.dither = InterleavedGradientNoise(input.positionCS.xy, 0);

				ShadowData sd = GetShadowData(surface);

				float s = 0;
				for(int i = 0; i < GetDirectionalLightCount(); i++){
					ShadowData sd = GetShadowData(surface);
					DirectionalShadowData dirShadowData = GetDirectionalShadowData(i, sd);
					int matIdx  = sd.cascadeBlend < 1.0? dirShadowData.tileIndex + 1:dirShadowData.tileIndex;
					float3 positionSTS = mul(_DirectionalShadowMatrices[matIdx], float4(input.positionWS, 1.0)).xyz;
					float d = _DirectionalShadowAtlas.Sample(my_point_clamp_sampler, positionSTS.xy).r;
					s = d > positionSTS.z? 1:0;
					s =  positionSTS.z;
				}

				return float4(s,s,s,1);
			}
			ENDHLSL
		}
	}
}
