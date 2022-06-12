using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[CreateAssetMenu(menuName = "Rendering/CustomRP")]
public class CustomRPAsset : RenderPipelineAsset
{
    [SerializeField]
    bool useDynamicBatching, useGPUInstancing, useSRPBatching;
    [SerializeField]
    ShadowSetting shadowSetting = default;
    protected override RenderPipeline CreatePipeline()
    {
        return new CustomRP(useDynamicBatching, useGPUInstancing, useSRPBatching, shadowSetting);
    }
}
