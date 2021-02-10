using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class VolumetricFog : MonoBehaviour
{
    public Texture2D hello;
    public Vector3 fogPos = new Vector3(0.0f, 0.0f, 0.0f);
    [Range(0.0f, 20.0f)]
    public float fogDensity = 2.0f;
    public Transform Fog;
    public Transform Light;
    [SerializeField]
    private Shader shader;
    public Material material
    {
        get
        {
            if(!raymarchingMaterial && shader)
            {
                raymarchingMaterial = new Material(shader);
                raymarchingMaterial.hideFlags = HideFlags.HideAndDontSave;
            }
            return raymarchingMaterial;
        }
    }

    private Material raymarchingMaterial;

    public Camera cam
    {
        get
        {
            if(!raymarchingCamera)
            {
                raymarchingCamera = GetComponent<Camera>();
            }
            return raymarchingCamera;
        }
    }

    private Camera raymarchingCamera;

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if(!material)
        {
            Graphics.Blit(source, destination);
            return;
        }

        material.SetTexture("_MainTex", source);
        material.SetTexture("_helloTex", hello);
        material.SetMatrix("_CamFrustum", CamFrustum(cam));
        material.SetMatrix("_CamToWorldMatrix", cam.cameraToWorldMatrix);
        material.SetVector("_CamWorldSpace", cam.transform.position);
        material.SetVector("_FogWorldPosition", Fog.position);
        material.SetVector("_FogWorldScale", Fog.localScale);
        material.SetVector("_LightDir", Light.forward);
        material.SetFloat("_FogDensity", fogDensity);
        var time = Application.isEditor?(float)EditorApplication.timeSinceStartup:Time.time;
        Vector4 vTime = new Vector4( time / 20, time, time*2, time*3);
        material.SetVector("_Phase", vTime );

        RenderTexture.active = destination;
        GL.PushMatrix();
        GL.LoadOrtho();
        material.SetPass(0);
        GL.Begin(GL.QUADS);

        //BL
        GL.MultiTexCoord2(0, 0.0f, 0.0f);
        GL.Vertex3(0.0f, 0.0f, 3.0f);
        //BR
        GL.MultiTexCoord2(0, 1.0f, 0.0f);
        GL.Vertex3(1.0f, 0.0f, 2.0f);
        //TR
        GL.MultiTexCoord2(0, 1.0f, 1.0f);
        GL.Vertex3(1.0f, 1.0f, 1.0f);
        //TL
        GL.MultiTexCoord2(0, 0.0f, 1.0f);
        GL.Vertex3(0.0f, 1.0f, 0.0f);

        GL.End();
        GL.PopMatrix();
    }

    private Matrix4x4 CamFrustum(Camera cam)
    {
        Matrix4x4 frustum = Matrix4x4.identity;
        float fov = Mathf.Tan((cam.fieldOfView * 0.5f) * Mathf.Deg2Rad);

        Vector3 goUp = Vector3.up * fov;
        Vector3 goRight = Vector3.right * fov * cam.aspect;

        Vector3 TL = (-Vector3.forward - goRight + goUp);
        Vector3 TR = (-Vector3.forward + goRight + goUp);
        Vector3 BR = (-Vector3.forward + goRight - goUp);
        Vector3 BL = (-Vector3.forward - goRight - goUp);

        frustum.SetRow(0, TL);
        frustum.SetRow(1, TR);
        frustum.SetRow(2, BR);
        frustum.SetRow(3, BL);

        return frustum;
    }
}
