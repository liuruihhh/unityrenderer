using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class CustomRP : RenderPipeline
{
    bool useDynamicBatching, useGPUInstancing;
    ShadowSetting shadowSetting;

    public CustomRP(bool useDynamicBatching, bool useGPUInstancing, bool useSRPBatching, ShadowSetting shadowSetting)
    {
        this.useDynamicBatching = useDynamicBatching;
        this.useGPUInstancing = useGPUInstancing;
        this.shadowSetting = shadowSetting;
        GraphicsSettings.useScriptableRenderPipelineBatching = useSRPBatching;
    }

    CameraRender cameraRender = new CameraRender();
    protected override void Render(ScriptableRenderContext context, Camera[] cameras)
    {
        foreach (var camera in cameras)
        {
            cameraRender.Render(context, camera, useDynamicBatching, useGPUInstancing, shadowSetting);
        }
    }
}
