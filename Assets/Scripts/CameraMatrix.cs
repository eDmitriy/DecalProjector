using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public class CameraMatrix : MonoBehaviour
{
    public Material mat;

    
    void OnWillRenderObject()
    {
        var camera = Camera.current;
        if(camera==null || mat==null) return;

        mat.SetMatrix("_InverseView", camera.cameraToWorldMatrix);
        //Shader.SetGlobalMatrix("_InverseView", camera.cameraToWorldMatrix);
    }
}
