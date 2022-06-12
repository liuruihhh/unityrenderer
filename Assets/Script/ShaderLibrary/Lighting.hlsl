
#ifndef CUSTOM_Lighting_INCLUDED
#define CUSTOM_Lighting_INCLUDED

float3 IncomingLight(Surface surface, Light light, BRDF brdf){
	return saturate(dot(surface.normal,light.direction)) * light.attenuation * light.color * brdf.diffuse;
}

float3 GetLighting(Surface surfaceWS, BRDF brdf){
	float3 color = 0.0;
	for(int i = 0; i < GetDirectionalLightCount(); i++){
		ShadowData shadowData = GetShadowData(surfaceWS);
		Light light = GetDirectionalLight(i, surfaceWS, shadowData);
		color += IncomingLight(surfaceWS, light, brdf) * DirectBRDF(surfaceWS, brdf, light);
	}
	return color;
}


#endif
