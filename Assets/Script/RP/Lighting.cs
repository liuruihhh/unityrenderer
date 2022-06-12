using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;

public class Lighting
{
    const int MaxDirLightCount = 4;

    static int
    dirLightCountId = Shader.PropertyToID("_DirectionalLightCount"),
    dirLightColorsId = Shader.PropertyToID("_DirectionalLightColors"),
    dirLightDirectionsId = Shader.PropertyToID("_DirectionalLightDirections"),
    dirLightShadowDataId = Shader.PropertyToID("_DirectionalLightShadowData");

    Vector4[] dirLightColors = new Vector4[MaxDirLightCount],
    dirLightDirections = new Vector4[MaxDirLightCount],
    dirLightShadowData = new Vector4[MaxDirLightCount];

    const string bufferName = "Lighting";

    CommandBuffer buffer = new CommandBuffer
    {
        name = bufferName
    };

    private CullingResults cullingResults;

    private Shadow shadow = new Shadow();

    public void Setup(ScriptableRenderContext context, CullingResults cullingResults, ShadowSetting shadowSetting)
    {
        this.cullingResults = cullingResults;
        buffer.BeginSample(bufferName);
        shadow.Setup(context, cullingResults, shadowSetting);
        SetupLights();
        shadow.Render();
        buffer.EndSample(bufferName);
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }

    void SetupDirectionalLight(int idx, ref VisibleLight visibleLight)
    {
        dirLightColors[idx] = visibleLight.finalColor;
        dirLightDirections[idx] = -visibleLight.localToWorldMatrix.GetColumn(2);
        dirLightShadowData[idx] = shadow.ReserveDirectionalShadows(visibleLight.light, idx);
    }

    void SetupLights()
    {
        NativeArray<VisibleLight> visibleLights = cullingResults.visibleLights;
        var lightCount = 0;
        for (var i = 0; i < visibleLights.Length; i++)
        {
            var light = visibleLights[i];
            if (light.lightType == LightType.Directional)
            {
                SetupDirectionalLight(lightCount++, ref light);
                if (lightCount >= MaxDirLightCount)
                {
                    break;
                }
            }
        }

        buffer.SetGlobalInt(dirLightCountId, lightCount);
        buffer.SetGlobalVectorArray(dirLightColorsId, dirLightColors);
        buffer.SetGlobalVectorArray(dirLightDirectionsId, dirLightDirections);
        buffer.SetGlobalVectorArray(dirLightShadowDataId, dirLightShadowData);
    }

    public void Cleanup()
    {
        shadow.Cleanup();
    }


}