using System;
using UnityEngine;
using UnityEngine.Rendering;

namespace Replay.AuroraShader
{
    /// <summary>
    /// Passes on material properties required for ray marching.
    /// </summary>
    [ExecuteInEditMode]
    [RequireComponent(typeof(Renderer))] 
    public class VolumeRendererProperties : MonoBehaviour
    {
        private static readonly int _propertyToWorldWithoutScale = Shader.PropertyToID("_ToWorldWithoutScale");
        private static readonly int _propertyBoundsSize = Shader.PropertyToID("_BoundsSize");

        private Renderer _renderer;
        
        private MaterialPropertyBlock _materialPropertyBlock;

        private Bounds _bounds;

        private void Awake()
        {
            _renderer = GetComponent<Renderer>();

            _materialPropertyBlock = new MaterialPropertyBlock();

            _bounds = new Bounds(transform.position, transform.lossyScale);
        }

        private void OnEnable()
        {
            RenderPipelineManager.beginCameraRendering -= ApplyPropertyBlocks;
            RenderPipelineManager.beginCameraRendering += ApplyPropertyBlocks;
        }

        private void OnDisable()
        {
            RenderPipelineManager.beginCameraRendering -= ApplyPropertyBlocks;
        }

        private void ApplyPropertyBlocks(ScriptableRenderContext context, Camera camera)
        {
            #if UNITY_EDITOR
            if (_renderer == null || _materialPropertyBlock == null || _bounds == null)
                Awake();
            #endif

            // Pass on the bounds.
            Matrix4x4 toWorldWithoutScale = Matrix4x4.TRS(transform.position, transform.rotation, Vector3.one);
            _materialPropertyBlock.SetMatrix(_propertyToWorldWithoutScale, toWorldWithoutScale);
            _materialPropertyBlock.SetVector(_propertyBoundsSize, _bounds.size);

            _renderer.SetPropertyBlock(_materialPropertyBlock);
        }
    }
}
