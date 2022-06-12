using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;
using UnityEngine.Profiling;


public partial class CameraRender
{
    static ShaderTagId unlitShaderTagId = new ShaderTagId("SRPDefaultUnlit");
    static ShaderTagId litShaderTagId = new ShaderTagId("CustomLit");

    partial void PrepareBuffer();
    partial void PrepareForSceneWindow();
    partial void DrawGizmos();
    partial void DrawUnsupportedShaders();

#if UNITY_EDITOR
    static ShaderTagId[] legacyShaderTagIds =
    {
        new ShaderTagId("Always"),
        new ShaderTagId("ForwardBase"),
        new ShaderTagId("PrepassBase"),
        new ShaderTagId("Vertex"),
        new ShaderTagId("VertexLMRGBM"),
        new ShaderTagId("VertexLM"),
    };

    static Material errorMaterial;

    string sampleName { get; set; }

    partial void PrepareBuffer()
    {
        Profiler.BeginSample("editor only");
        buffer.name = sampleName = camera.name;
        Profiler.EndSample();
    }

    partial void PrepareForSceneWindow()
    {
        if (camera.cameraType == CameraType.SceneView)
        {
            ScriptableRenderContext.EmitWorldGeometryForSceneView(camera);
        }
    }

    partial void DrawGizmos()
    {
        if (Handles.ShouldRenderGizmos())
        {
            context.DrawGizmos(camera, GizmoSubset.PreImageEffects);
            context.DrawGizmos(camera, GizmoSubset.PostImageEffects);
        }
    }

    partial void DrawUnsupportedShaders()
    {
        if (errorMaterial == null)
            errorMaterial = new Material(Shader.Find("Hidden/InternalErrorShader"));
        var drawingSetting = new DrawingSettings(legacyShaderTagIds[0], new SortingSettings(camera));
        drawingSetting.overrideMaterial = errorMaterial;
        for (var i = 0; i < legacyShaderTagIds.Length; i++)
        {
            drawingSetting.SetShaderPassName(i, legacyShaderTagIds[i]);
        }
        var filteringSetting = FilteringSettings.defaultValue;
        context.DrawRenderers(cullingResults, ref drawingSetting, ref filteringSetting);
    }
#else
    const string sampleName = bufferName;
#endif
}
