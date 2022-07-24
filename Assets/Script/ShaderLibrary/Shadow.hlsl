#ifndef CUSTOM_SHADOW_INCLUDED
#define CUSTOM_SHADOW_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"

#if defined(_DIRECTIONAL_PCF3)
	#define DIRECTIONAL_FILTER_SAMPLES 4
	#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_3x3
#elif defined(_DIRECTIONAL_PCF5)
	#define DIRECTIONAL_FILTER_SAMPLES 9
	#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_5x5
#elif defined(_DIRECTIONAL_PCF7)
	#define DIRECTIONAL_FILTER_SAMPLES 16
	#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_7x7
#endif

#define MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT 4
#define MAX_CASCADE_COUNT 4

#define LIGHT_WIDTH 1
#define NUM_SAMPLES 100
#define NUM_RINGS 10
#define PI2 6.283185307179586

TEXTURE2D_SHADOW(_DirectionalShadowAtlas);
#define SHADOW_SAMPLER sampler_linear_clamp_compare
SAMPLER_CMP(SHADOW_SAMPLER);

SamplerState my_point_clamp_sampler;

CBUFFER_START(_CustomShadows)
int _CascadeCount;
float4 _CascadeCullingSpheres[MAX_CASCADE_COUNT];
float4x4 _DirectionalShadowMatrices[MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT * MAX_CASCADE_COUNT];
float4 _ShadowAtlasSize;
float4 _ShadowDistanceFade;
float4 _CascadeData[MAX_CASCADE_COUNT];
CBUFFER_END

struct DirectionalShadowData
{
	float strength;
	int tileIndex;
	float normalBias;
};

struct ShadowData
{
	int cascadeIndex;
	float strength;
	float cascadeBlend;
};


float2 poissonDisk[NUM_SAMPLES];

float rand_2to1(float2 uv)
{
  // 0 - 1
	const float a = 12.9898, b = 78.233, c = 43758.5453;
	float dt = dot(uv.xy, float2(a, b)), sn = fmod(dt, PI);
	return frac(sin(sn) * c);
}

void poissonDiskSamples(const in float2 randomSeed)
{
	float ANGLE_STEP = PI2 * float(NUM_RINGS) / float(NUM_SAMPLES);
	float INV_NUM_SAMPLES = 1.0 / float(NUM_SAMPLES);

	float angle = rand_2to1(randomSeed) * PI2;
	float radius = INV_NUM_SAMPLES;
	float radiusStep = radius;

	for (int i = 0; i < NUM_SAMPLES; i++)
	{
		poissonDisk[i] = float2(cos(angle), sin(angle)) * pow(radius, 0.75);
		radius += radiusStep;
		angle += ANGLE_STEP;
	}
}

float GetDepth(float2 xy,float2 off){
	return _DirectionalShadowAtlas.Sample(my_point_clamp_sampler, xy + off).r;
}

float GetPCFSize(float3 positionSTS)
{
	poissonDiskSamples(positionSTS.xy);
	float ds = 0.;
	int num = 0;
	float avgD = 0;
	for (int i = 0; i < NUM_SAMPLES; i++)
	{
		float d = GetDepth(positionSTS.xy , poissonDisk[i]*0.05);

		if (d > positionSTS.z)
		{
			num++;
			ds += d;
		}
	}
	if (num > 0)
	{
		avgD = ds / float(num);
	}

	return LIGHT_WIDTH / (avgD / (avgD - positionSTS.z));
}

float PCF(float3 positionSTS, float filterSize){
	poissonDiskSamples(positionSTS.xy);
	float ds = 0.;
	for(int i = 0; i<NUM_SAMPLES; i++){
		float d = GetDepth(positionSTS.xy, poissonDisk[i] * filterSize * 0.1);
		ds = ds + 1.-step(0.01,d > positionSTS.z);
	}
	return ds/float(NUM_SAMPLES);
}

float FadedShadowStrength(float distance, float scale, float fade)
{
	return saturate((1.0 - distance * scale) * fade);
}

ShadowData GetShadowData(Surface surfaceWS)
{
	ShadowData data;
	data.cascadeBlend = 1.0;
	data.strength = FadedShadowStrength(surfaceWS.depth, _ShadowDistanceFade.x, _ShadowDistanceFade.y);
	int i;
	for (i = 0; i < _CascadeCount; i++)
	{
		float4 sphere = _CascadeCullingSpheres[i];
		float distanceSqr = DistanceSquared(surfaceWS.position, sphere.xyz);
		if (distanceSqr < sphere.w)
		{
			float fade = FadedShadowStrength(
				distanceSqr, _CascadeData[i].x, _ShadowDistanceFade.z
			);
			if (i == _CascadeCount - 1)
			{
				data.strength *= fade;
			}
			else
			{
				data.cascadeBlend = fade;
			}
			break;
		}
	}
	if (i == _CascadeCount)
	{
		data.strength = 0.0;
	}
#if defined(_CASCADE_BLEND_DITHER)
		else if (data.cascadeBlend < surfaceWS.dither) {
			i += 1;
		}
#endif
#if !defined(_CASCADE_BLEND_SOFT)
	data.cascadeBlend = 1.0;
#endif
	data.cascadeIndex = i;

	return data;
}

float SampleDirectionalShadowAtlas(float3 positionSTS)
{
	return SAMPLE_TEXTURE2D_SHADOW(_DirectionalShadowAtlas, SHADOW_SAMPLER, positionSTS);
}

float FilterDirectionalShadow(float3 positionSTS)
{
#if defined(DIRECTIONAL_FILTER_SETUP)
		float weights[DIRECTIONAL_FILTER_SAMPLES];
		float2 positions[DIRECTIONAL_FILTER_SAMPLES];
		float4 size = _ShadowAtlasSize.yyxx;
		DIRECTIONAL_FILTER_SETUP(size, positionSTS.xy, weights, positions);
		float shadow = 0;
		for (int i = 0; i < DIRECTIONAL_FILTER_SAMPLES; i++) {
			shadow += weights[i] * SampleDirectionalShadowAtlas(float3(positions[i].xy, positionSTS.z));
		}
		return shadow;
#else
	return SampleDirectionalShadowAtlas(positionSTS);
#endif
}

float GetDirectionalShadowAttenuation(DirectionalShadowData directionalData, ShadowData global, Surface surfaceWS)
{
	if (directionalData.strength <= 0.0)
	{
		return 1.0;
	}

	float3 normalBias = surfaceWS.normal * (directionalData.normalBias * _CascadeData[global.cascadeIndex].y);
	float3 positionSTS = mul(_DirectionalShadowMatrices[directionalData.tileIndex], float4(surfaceWS.position + normalBias, 1.0)).xyz;
	float shadow = FilterDirectionalShadow(positionSTS);

	if (global.cascadeBlend < 1.0)
	{
		normalBias = surfaceWS.normal *(directionalData.normalBias * _CascadeData[global.cascadeIndex + 1].y);
		positionSTS = mul(_DirectionalShadowMatrices[directionalData.tileIndex + 1],float4(surfaceWS.position + normalBias, 1.0)).xyz;
		shadow = lerp(FilterDirectionalShadow(positionSTS), shadow, global.cascadeBlend);
	}

	float pcfSize =	GetPCFSize(positionSTS);
	float pcssShadow = PCF(positionSTS,pcfSize);
	
	// return lerp(1.0,shadow, directionalData.strength);

	// if(shadow>pcssShadow)
	// 	pcssShadow =shadow;

	return lerp(1.0,pcssShadow, directionalData.strength);

}

#endif